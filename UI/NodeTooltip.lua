-- Adds the AH price under herb and mining nodes when you hover them on the minimap.
local _, ns = ...
local NodeTooltip = {}
ns.UI.NodeTooltip = NodeTooltip

local UI, Util = ns.UI, ns.Util

local L = {
  PRICE = "AH price",
  RARE = "Rare: %s (%s%%)",
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

local busy = false
function NodeTooltip.OnSetText(tooltip, text)
  if busy or Util.IsSecret(text) or not fromMinimap(tooltip:GetOwner()) then return end
  local prices = ns.Nodes.Prices(text)
  local nodes = ns.Nodes.Parse(text)
  -- One node under the cursor: also its most valuable rare drop.
  local rare = #nodes == 1 and ns.Nodes.Rare(nodes[1]) or nil
  if #prices == 0 and not rare then return end
  busy = true
  local muted = Util.RGB.muted
  for _, p in ipairs(prices) do
    local left = #prices == 1 and L.PRICE or p.name
    tooltip:AddDoubleLine(left, Util.Money(p.price), muted[1], muted[2], muted[3], 1, 1, 1)
  end
  if rare then
    tooltip:AddDoubleLine(string.format(L.RARE, rare.name, chance(rare.chance)), Util.Money(rare.price),
      muted[1], muted[2], muted[3], 1, 1, 1)
  end
  tooltip:Show()
  busy = false
end

ns.Listen("READY", function()
  if GameTooltip and hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetText", function(...) ns.Safe("node tooltip", NodeTooltip.OnSetText, ...) end)
  end
end)
