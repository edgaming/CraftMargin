-- Adds the AH price under herb and mining nodes when you hover them on the minimap.
local _, ns = ...
local NodeTooltip = {}
ns.UI.NodeTooltip = NodeTooltip

local UI, Util = ns.UI, ns.Util

local L = {
  PRICE = "AH price",
}

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
  if #prices == 0 then return end
  busy = true
  local muted = Util.RGB.muted
  for _, p in ipairs(prices) do
    local left = #prices == 1 and L.PRICE or p.name
    tooltip:AddDoubleLine(left, Util.Money(p.price), muted[1], muted[2], muted[3], 1, 1, 1)
  end
  tooltip:Show()
  busy = false
end

ns.Listen("READY", function()
  if GameTooltip and hooksecurefunc then
    hooksecurefunc(GameTooltip, "SetText", function(...) ns.Safe("node tooltip", NodeTooltip.OnSetText, ...) end)
  end
end)
