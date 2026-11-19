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
  local info = { unpriced = 0, noThresholds = 0, untrained = 0, notTrainer = 0, mismatches = {} }
  local function add(recipe, known, req, fee)
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
      points = recipe.points or 1, net = r.cost - resale(r), source = recipe.source,
    }
  end
  for _, recipe in ipairs(entry.recipes) do add(recipe, true, 0, 0) end
  for _, recipe in ipairs(entry.unlearned or {}) do
    local req, fee = Leveling.TrainerTerms(prof, recipe)
    if req then
      add(recipe, false, req, fee)
    elseif req == false then
      info.notTrainer = info.notTrainer + 1
    else
      info.untrained = info.untrained + 1
    end
  end
  return cands, info
end

-- Skill and fee to learn an unlearned recipe from a trainer. A trainer you've visited wins (its
-- fee includes your reputation discount); otherwise the bundled What's Training data.
-- Returns skill, fee; false if no trainer teaches it; nil if nothing is known.
function Leveling.TrainerTerms(prof, recipe)
  local seen = ns.Trainer.For(prof.name, recipe.name)
  if seen then return seen.skill, seen.cost or 0 end
  local data = ns.RecipeSources and ns.RecipeSources[recipe.id]
  if not data then return nil end
  if not data[3]:find("t", 1, true) then return false end
  return data[1], data[2]
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
  TRAINER = "trainer · %s (skill %d)",
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
  add(L.CHANCE, U.Percent(ns.Planner.Chance(c, from)) .. " → " .. U.Percent(ns.Planner.Chance(c, to - 1)))
  add(L.CRAFTS, "about " .. Leveling.Crafts(crafts))
  if not c.known then add(L.LEARN, string.format(L.TRAINER, U.Money(c.fee), c.req)) end
  return lines
end

Leveling.PINNED_TEXT = L.PINNED
