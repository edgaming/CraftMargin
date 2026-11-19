-- Adds AH prices to herb and mining nodes when you hover them on the minimap:
--   Stranglekelp (AH 1g 25s)
--   Chance for:
--       Shadowgem 1% (AH 25s)
local _, ns = ...
local NodeTooltip = {}
ns.UI.NodeTooltip = NodeTooltip

local Util = ns.Util

local L = {
  PRICED = "%s (AH %s)",
  CHANCE_FOR = "Chance for:",
  RARE = "    %s %s%%",
  NO_PRICE = "no AH price",
}

local function chance(pct)
  if pct >= 10 or pct == math.floor(pct) then return string.format("%d", pct) end
  return string.format("%.1f", pct)
end

local function fromMinimap(owner)
  if not owner then return false end
  if owner == Minimap then return true end
  local name = owner.GetName and owner:GetName()
  return type(name) == "string" and name:find("Minimap", 1, true) ~= nil
end

local function priced(name, price)
  return string.format(L.PRICED, name, Util.Money(price))
end

local busy = false
function NodeTooltip.OnSetText(tooltip, text)
  if busy or Util.IsSecret(text) or not fromMinimap(tooltip:GetOwner()) then return end
  local nodes = ns.Nodes.Parse(text)
  if #nodes == 0 then return end
  busy = true
  local changed = false
  local muted = Util.RGB.muted

  if #nodes == 1 then
    -- One node: price on its own line, then every rare drop it can give.
    local id = ns.Nodes.Item(nodes[1])
    local price = id and ns.Prices.Sell(id)
    local first = _G[(tooltip:GetName() or "") .. "TextLeft1"]
    if price and first then
      first:SetText(priced(text, price))
      changed = true
    end
    local rares = ns.Nodes.Rares(nodes[1])
    if #rares > 0 then
      tooltip:AddLine(L.CHANCE_FOR, muted[1], muted[2], muted[3])
      for _, r in ipairs(rares) do
        local line = string.format(L.RARE, r.name, chance(r.chance))
        tooltip:AddLine(r.price and string.format(L.PRICED, line, Util.Money(r.price)) or (line .. " (" .. L.NO_PRICE .. ")"), 1, 1, 1)
      end
      changed = true
    end
  else
    -- Several nodes under the cursor: one price line per item, no rares, to stay short.
    for _, p in ipairs(ns.Nodes.Prices(text)) do
      tooltip:AddDoubleLine(p.name, Util.Money(p.price), muted[1], muted[2], muted[3], 1, 1, 1)
      changed = true
    end
  end

  if changed then tooltip:Show() end
  busy = false
end

ns.Listen("READY", function()
  if GameTooltip and hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetText", function(...) ns.Safe("node tooltip", NodeTooltip.OnSetText, ...) end)
  end
end)
