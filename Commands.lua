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
  say("Auctionator: " .. (Api.HasAuctionator() and table.concat(Api.AucFunctions(), ", ") or "not found"))
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
  local builtin, recorded = ns.Vendor.Count()
  say(string.format("Vendor prices: %d built in, %d seen", builtin, recorded))
  say(string.format("Errors: %d", #ns.errors))
  for _, e in ipairs(ns.errors) do say("  " .. e) end
end

function Commands.Run(msg)
  msg = strtrim(string.lower(msg or ""))
  if msg == "debug" then
    Commands.Debug()
  else
    ns.UI.Main.Toggle()
  end
end

SLASH_CRAFTMARGIN1 = "/margin"
SlashCmdList.CRAFTMARGIN = function(msg) ns.Safe("command", Commands.Run, msg) end
