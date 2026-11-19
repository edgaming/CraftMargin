-- The levelling route for one of the character's professions: candidates from the recipe index,
-- thresholds from the client data, trainer requirements, current prices; then the planner.
local _, ns = ...
local Leveling = {}
ns.Leveling = Leveling

local Api = ns.Api

Leveling.MAX_SKILL = 300

-- What the result of one craft is worth when sold: the better of AH (after cut) and vendor.
local function resale(r)
  if r.best then return r[r.best].revenue end
  return 0
end

-- Thresholds for a recipe: the bundled yellow and grey, with the game's own grey winning.
-- Returns yellow, grey, mismatch (true when they disagreed).
function Leveling.Thresholds(recipe)
  local t = ns.ThresholdData and ns.ThresholdData[recipe.id]
  if not t then return nil end
  local yellow, grey = t[1], t[2]
  local mismatch = false
  if recipe.grey and recipe.grey ~= grey then
    grey, mismatch = recipe.grey, true
    yellow = math.min(yellow, grey - 1)
  end
  return yellow, grey, mismatch
end

-- Candidate recipes for the planner, plus counts of what was left out and why.
function Leveling.Candidates(prof, entry)
  local cands = {}
  local info = { unpriced = 0, noThresholds = 0, unknown = 0, unobtainable = 0, mismatches = {} }
  local function add(recipe, known, req, fee, how)
    local yellow, grey, mismatch = Leveling.Thresholds(recipe)
    if not yellow then
      info.noThresholds = info.noThresholds + 1
      return
    end
    if mismatch then info.mismatches[#info.mismatches + 1] = recipe end
    local r = ns.Prices.Evaluate(recipe)
    if not r.matsKnown then
      info.unpriced = info.unpriced + 1
      return
    end
    cands[#cands + 1] = {
      id = recipe.id, name = recipe.name, out = recipe.out, recipe = recipe, eval = r,
      yellow = yellow, grey = grey, req = req, fee = fee, known = known,
      points = recipe.points or 1, net = r.cost - resale(r), how = how,
    }
  end
  for _, recipe in ipairs(entry.recipes) do add(recipe, true, 0, 0) end
  for _, recipe in ipairs(entry.unlearned or {}) do
    local how, why = Leveling.Acquire(prof, recipe)
    if how then
      add(recipe, false, how.skill, how.fee, how)
    elseif why == "unknown" then
      info.unknown = info.unknown + 1
    else
      info.unobtainable = info.unobtainable + 1
    end
  end
  return cands, info
end

local function forFaction(places, faction)
  for _, p in ipairs(places or {}) do
    if p[2] == "" or p[2] == faction then return true end
  end
  return false
end

local function zones(places, faction, field)
  local out, seen = {}, {}
  for _, p in ipairs(places or {}) do
    local mine = (field == 3 and (p[3] == "" or p[3] == faction)) or (field == 2 and (p[2] == "" or p[2] == faction))
    local name = mine and Api.AreaName(field == 3 and p[2] or p[1])
    if name and not seen[name] then
      seen[name] = true
      out[#out + 1] = name
    end
  end
  return out
end

-- Reputation a recipe needs: met when any listed faction is at the standing (pairs cover the
-- Alliance and Horde versions of the same faction).
local function repMet(rep)
  if not rep then return true end
  for _, need in ipairs(rep) do
    local standing = Api.Standing(need[1])
    if standing and standing >= need[2] then return true end
  end
  return false
end

-- How to get an unlearned recipe, cheapest reliable way first: trainer, vendor, the AH (for a
-- pattern that drops but can be traded), then a quest. Returns
--   { kind, skill, fee, priceKnown, zones, favor, level }
-- or nil plus "unknown" (no data) or "unobtainable" (nothing your character can use).
function Leveling.Acquire(prof, recipe)
  local seen = ns.Trainer.For(prof.name, recipe.name)
  if seen then return { kind = "trainer", skill = seen.skill, fee = seen.cost or 0, priceKnown = true } end
  local data = ns.RecipeSources and ns.RecipeSources[recipe.id]
  if not data then return nil, "unknown" end
  local skill, src, faction = data[1], data[3], Api.Faction()
  if not repMet(data.rep) then return nil, "unobtainable" end

  if src:find("t", 1, true) then
    return { kind = "trainer", skill = skill, fee = data[2], priceKnown = true }
  end
  if src:find("v", 1, true) and (not data.vendors or forFaction(data.vendors, faction)) then
    local seenPrice = data.teach and ns.Vendor.Recorded(data.teach)
    local price = seenPrice or data.price
    return {
      kind = "vendor", skill = skill, fee = price or 0, priceKnown = price ~= nil,
      zones = zones(data.vendors, faction, 2), favor = data.favor,
    }
  end
  if data.teach and not data.bound then
    local ah = ns.Prices.Sell(data.teach)
    if ah then return { kind = "ah", skill = skill, fee = ah, priceKnown = true } end
  end
  if src:find("q", 1, true) and data.quests then
    local level
    for _, q in ipairs(data.quests) do
      if q[3] == "" or q[3] == faction then level = math.min(level or q[4], q[4]) end
    end
    if level then
      return { kind = "quest", skill = skill, fee = 0, priceKnown = true, zones = zones(data.quests, faction, 3), level = level }
    end
  end
  return nil, "unobtainable"
end

function Leveling.Pins(prof)
  return ns.char.pins[prof.skillLine] or {}
end

-- Pin a recipe over a range; replaces any pin overlapping it.
function Leveling.Pin(prof, from, to, id)
  local keep = {}
  for _, p in ipairs(Leveling.Pins(prof)) do
    if p.to <= from or p.from >= to then keep[#keep + 1] = p end
  end
  keep[#keep + 1] = { from = from, to = to, id = id }
  ns.char.pins[prof.skillLine] = keep
  ns.Update()
end

function Leveling.ResetPins(prof)
  ns.char.pins[prof.skillLine] = nil
  ns.Update()
end

-- The route from the character's current skill to 300.
-- Returns { from, to, steps, total, info, maxed } or nil if the profession isn't read yet.
function Leveling.Route(prof)
  local entry = ns.Recipes.For(prof)
  if not entry then return nil end
  local from = math.max(1, prof.rank or 1)
  local route = { from = from, to = Leveling.MAX_SKILL }
  if from >= Leveling.MAX_SKILL then
    route.maxed = true
    return route
  end
  local cands, info = Leveling.Candidates(prof, entry)
  route.info = info
  local plan = ns.Planner.Plan(from, Leveling.MAX_SKILL, cands, Leveling.Pins(prof))
  route.steps, route.total = plan.steps, plan.total
  Leveling.last = route -- for /margin debug
  return route
end

local L = {
  PER_CRAFT = "Per craft",
  MATS = "  Materials",
  SELLS = "  Sells for",
  NET = "  Net cost",
  CHANCE = "Skill-up chance",
  CRAFTS = "Crafts",
  LEARN = "Learn",
  TRAINER = "Trainer · %s",
  VENDOR = "Vendor · %s",
  VENDOR_UNKNOWN = "Vendor · price unknown",
  AH = "Auction house · %s",
  QUEST = "Quest reward",
  SKILL_NEEDED = "  Needs skill",
  WHERE = "  Where",
  FAVOR = "  Also costs",
  FAVOR_TEXT = "%d Merchant's Favor",
  QUEST_LEVEL = "  Quest level",
  GREEN = "Green: only because nothing yellow or orange fits here",
  PINNED = "Pinned here — reset the route to undo",
}

-- Whole crafts for a step, for display and shopping.
function Leveling.Crafts(n)
  return math.max(1, math.floor(n + 0.5))
end

-- Colour mix over a step: points spent while orange (below yellow), yellow, green.
-- Green starts halfway between yellow and grey.
function Leveling.Colors(c, from, to)
  local green = math.floor((c.yellow + c.grey) / 2)
  local o, y, g = 0, 0, 0
  for s = from, to - 1 do
    if s < c.yellow then o = o + 1 elseif s < green then y = y + 1 else g = g + 1 end
  end
  return o, y, g
end

-- Tooltip for a step or an alternative: { { left, right?, kind? } }.
function Leveling.StepLines(c, from, to, crafts)
  local U = ns.Util
  local r = c.eval
  local lines = {}
  local function add(left, right, kind) lines[#lines + 1] = { left, right, kind } end
  add(L.PER_CRAFT, nil, "head")
  add(L.MATS, "-" .. U.Money(r.cost))
  local value = r.best and r[r.best].revenue or 0
  add(L.SELLS, "+" .. U.Money(value) .. (r.best and (" " .. U.Color("muted", r.best == "ah" and "AH" or "vendor")) or ""))
  add(L.NET, U.Money(math.abs(c.net)) .. (c.net < 0 and " profit" or ""), c.net < 0 and "good" or nil)
  add(L.CHANCE, U.Percent(ns.Planner.Chance(c, from)) .. " to " .. U.Percent(ns.Planner.Chance(c, to - 1)))
  add(L.CRAFTS, "about " .. Leveling.Crafts(crafts))
  if not c.known then
    local how = c.how or { kind = "trainer", fee = c.fee }
    add(L.LEARN, Leveling.SourceText(how), "warn")
    add(L.SKILL_NEEDED, tostring(c.req))
    if how.zones and #how.zones > 0 then add(L.WHERE, table.concat(how.zones, ", ")) end
    if how.level then add(L.QUEST_LEVEL, tostring(how.level)) end
    if how.favor then add(L.FAVOR, string.format(L.FAVOR_TEXT, how.favor)) end
  end
  return lines
end

-- Short wording for how a recipe is learned: "Trainer · 10s", "Vendor · 90s", "Quest reward".
function Leveling.SourceText(how)
  local U = ns.Util
  if how.kind == "vendor" then
    return how.priceKnown and string.format(L.VENDOR, U.Money(how.fee)) or L.VENDOR_UNKNOWN
  elseif how.kind == "ah" then
    return string.format(L.AH, U.Money(how.fee))
  elseif how.kind == "quest" then
    return L.QUEST
  end
  return string.format(L.TRAINER, U.Money(how.fee))
end

Leveling.GREEN_TEXT = L.GREEN

Leveling.PINNED_TEXT = L.PINNED
