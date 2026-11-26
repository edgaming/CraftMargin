-- Slash commands: /margin toggles the window, /margin debug dumps state.
local _, ns = ...
local Commands = {}
ns.Commands = Commands

local Api = ns.Api

local L = {
  PREFIX = "|cffffd700Craft Margin|r ",
}

local function say(text) print(L.PREFIX .. text) end

function Commands.Debug()
  local _, build, _, iface = GetBuildInfo()
  say(string.format("v%s · interface %s · build %s · %s", ns.version, tostring(iface), tostring(build), Api.Faction()))
  local source = ns.Prices.Source()
  say("Price source: " .. (source and source.name or "none") .. " (saved: " .. tostring(ns.db.source or "auto") .. ")")
  say("Auctionator: " .. (Api.HasAuctionator() and table.concat(Api.AucFunctions(), ", ") or "not found"))
  say("TSM: " .. (Api.HasTSM() and ("found, Linen Cloth = " .. tostring(Api.TSMPrice(2589))) or "not found"))
  say("Prices updated: " .. (ns.db.priceUpdatedAt and ns.Util.Ago(Api.Now() - ns.db.priceUpdatedAt) or "never seen"))
  for _, p in ipairs(Api.Professions()) do
    local entry = ns.Recipes.For(p)
    local text = string.format("%s (%d)%s: ", p.name, p.skillLine, ns.GATHERING[p.skillLine] and " gathering" or "")
    if entry then
      text = text .. string.format("%d recipes, %d make no item, read %s",
        #entry.recipes, entry.noItem or 0, ns.Util.Ago(Api.Now() - entry.readAt))
    else
      text = text .. "not read yet"
    end
    say(text)
  end
  local stored = {}
  for skillLine, entry in pairs(ns.char.profs) do stored[#stored + 1] = entry.name .. "=" .. skillLine end
  say("Stored: " .. (#stored > 0 and table.concat(stored, ", ") or "none"))
  say("Open recipe: " .. ((C_TradeSkillUI and C_TradeSkillUI.OpenRecipe) and "yes" or "no")
    .. " · recipe tooltip: " .. (GameTooltip.SetRecipeResultItem and "yes" or "no"))
  local open = Api.OpenProfession()
  say("Open profession: " .. (open and (open.name .. " (" .. open.skillLine .. ")") or "none"))
  local hidden = ns.Difficulty.Filter()
  say("Showing: " .. (hidden and (#hidden > 0 and table.concat(hidden, ", ") or "nothing") or "all colours"))
  local builtin, recorded = ns.Vendor.Count()
  say(string.format("Vendor prices: %d built in, %d seen", builtin, recorded))
  if not (InCombatLockdown and InCombatLockdown()) then ns.Safe("bag highlight", ns.UI.BagHighlight.Refresh, true) end
  local target, cheapest = ns.UI.BagHighlight.Target()
  say("Cheapest in bags: " .. (cheapest and string.format("%s (bag %d slot %d, %s)%s",
    (Api.Item(cheapest.itemID)) or cheapest.itemID, cheapest.bag, cheapest.slot, ns.Util.Money(cheapest.worth),
    target and ", highlighted" or string.format(", bag button not found among %d visible bag buttons (first is bag/slot %s)",
      ns.UI.BagHighlight.seen or 0, ns.UI.BagHighlight.sample or "none")) or "nothing to suggest"))
  if target then
    local function v(fn) local ok, x = pcall(target[fn], target) return ok and tostring(x) or "?" end
    say(string.format("  Button: %s, %sx%s, %s level %s, alpha %s", v("GetName"), v("GetWidth"), v("GetHeight"),
      v("GetFrameStrata"), v("GetFrameLevel"), v("GetEffectiveAlpha")))
  end
  local BH = ns.UI.BagHighlight
  say(string.format("  Bag check: %.1f ms (walked %d frames)", BH.ms or 0, BH.scanned or 0))
  local kept = 0
  for _ in pairs(ns.db.keep) do kept = kept + 1 end
  say(string.format("Kept items: %d", kept))
  local queued = ns.Shopping.Pending()
  say("Queued AH search: " .. (queued and (queued.recipe .. ", " .. #queued.terms .. " items") or "none"))
  say(string.format("Errors: %d", #ns.errors))
  for _, e in ipairs(ns.errors) do say("  " .. e) end
end

-- /margin debug <recipe>: every number behind one recipe, to check against Auctionator.
function Commands.DebugRecipe(query)
  local U = ns.Util
  local found
  for skillLine, entry in pairs(ns.char.profs) do
    for _, recipe in ipairs(entry.recipes) do
      if not found and (recipe.name or ""):lower():find(query, 1, true) then
        found = { recipe = recipe, entry = entry, skillLine = skillLine }
      end
    end
  end
  if not found then return say("No recipe matching \"" .. query .. "\".") end
  local recipe = found.recipe
  local r = ns.Prices.Evaluate(recipe)
  say(string.format("%s (%d)", recipe.name, recipe.id))
  for _, m in ipairs(r.mats) do
    local name = (Api.Item(m.id)) or ("item " .. m.id)
    if m.unit then
      say(string.format("  %d x %s at %s (%s) = %s", m.n, name, U.Money(m.unit), m.src, U.Money(m.unit * m.n)))
    else
      say(string.format("  %d x %s: no price", m.n, name))
    end
  end
  say("  Materials: " .. U.Money(r.cost) .. (r.matsKnown and "" or " (incomplete)"))
  local age = ns.Prices.Age(recipe.out)
  say(string.format("  Makes %s x%s · AH %s%s · vendor pays %s",
    (Api.Item(recipe.out)) or ("item " .. recipe.out), U.Yield(r.yield):gsub("^.", ""),
    r.ah and U.Money(r.ah.unit) or "no price", age and (" (" .. U.DaysOld(age) .. ")") or "",
    r.vendor and U.Money(r.vendor.unit) or "nothing"))
  if r.ah then
    say(string.format("  AH: %s - %s cut = %s", U.Money(r.ah.gross), U.Money(r.ah.cut), U.Money(r.ah.revenue)))
  end
  if r.vendor then say("  Vendor: " .. U.Money(r.vendor.revenue)) end
  say("  Best: " .. tostring(r.best or "none") .. (r.profit and (" · profit per craft " .. U.SignedMoney(r.profit)) or ""))
  local D = ns.Difficulty
  local yellow, grey = D.Thresholds(recipe)
  local rank
  for _, p in ipairs(Api.Professions()) do
    if p.skillLine == found.skillLine or p.name == found.entry.name then rank = p.rank end
  end
  say(string.format("  Thresholds: yellow %s, green %s, grey %s · game said %s at skill %s · now %s at skill %s",
    tostring(yellow), yellow and tostring(math.floor((yellow + grey) / 2)) or "?", tostring(grey),
    tostring(recipe.difficulty), tostring(found.entry.rank), tostring(D.Of(recipe, rank, found.entry.rank)), tostring(rank)))
end

function Commands.Run(msg)
  local raw = strtrim(msg or "")
  msg = string.lower(raw)
  local keepLink = raw:match("^[Kk][Ee][Ee][Pp]%s+(.+)$")
  local query = msg:match("^debug%s+(.+)$")
  if keepLink then
    local id = ns.UI.BagHighlight.ItemIDFromLink(keepLink)
    if id then ns.UI.BagHighlight.ToggleKeep(id) else say("Shift-click an item into the chat box after /margin keep.") end
  elseif query then
    Commands.DebugRecipe(query)
  elseif msg == "debug" then
    Commands.Debug()
  else
    ns.UI.Main.Toggle()
  end
end

SLASH_CRAFTMARGIN1 = "/margin"
SlashCmdList.CRAFTMARGIN = function(msg) ns.Safe("command", Commands.Run, msg) end
