-- A red border on the cheapest thing in your bags, whatever bag window you use.
--
-- Bag windows draw item buttons with the game's container item template (so right-click still
-- uses the item), and those buttons report their bag and slot. When bags open or change, find the
-- button for the cheapest slot and put a border over it. The border is our own frame laid on top:
-- nothing in the bag window is changed, and it's safe in combat.
local _, ns = ...
local BagHighlight = {}
ns.UI.BagHighlight = BagHighlight

local L = {
  TOOLTIP = "Cheapest thing in your bags",
}

local border, target, cheapest
local THICK = 2

local function MakeBorder()
  if border then return border end
  border = CreateFrame("Frame", nil, UIParent)
  border:EnableMouse(false)
  border.edges = {}
  for i, spec in ipairs({
    { "TOPLEFT", "TOPRIGHT", nil, THICK }, { "BOTTOMLEFT", "BOTTOMRIGHT", nil, THICK },
    { "TOPLEFT", "BOTTOMLEFT", THICK, nil }, { "TOPRIGHT", "BOTTOMRIGHT", THICK, nil },
  }) do
    local t = border:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(1, 0.2, 0.2, 1)
    t:SetPoint(spec[1])
    t:SetPoint(spec[2])
    if spec[3] then t:SetWidth(spec[3]) else t:SetHeight(spec[4]) end
    border.edges[i] = t
  end
  border:Hide()
  border:SetScript("OnUpdate", function(self)
    -- Follow the button: gone when the bag window closes or the slot is redrawn.
    if not target or not target:IsVisible() then
      self:Hide()
      target = nil
    end
  end)
  return border
end

local function slotOf(f)
  local bag, slot
  if f.GetBagID then
    local ok, b = pcall(f.GetBagID, f)
    if ok then bag = b end
  end
  bag = bag or rawget(f, "bagID") or rawget(f, "bag")
  if f.GetID then slot = f:GetID() end
  slot = (slot and slot > 0) and slot or rawget(f, "slotID") or rawget(f, "slot")
  return bag, slot
end

-- The visible item button showing bag/slot, from any bag addon.
function BagHighlight.FindButton(bag, slot)
  local f = EnumerateFrames()
  while f do
    if f:IsVisible() and (f.GetBagID or rawget(f, "bagID")) then
      local b, s = slotOf(f)
      if b == bag and s == slot then return f end
    end
    f = EnumerateFrames(f)
  end
end

function BagHighlight.Refresh()
  cheapest = ns.Cheapest.Find()
  local button = cheapest and BagHighlight.FindButton(cheapest.bag, cheapest.slot)
  local b = MakeBorder()
  target = button
  if not button then
    b:Hide()
    return
  end
  b:ClearAllPoints()
  b:SetAllPoints(button)
  b:SetFrameStrata(button:GetFrameStrata() or "MEDIUM")
  b:SetFrameLevel((button:GetFrameLevel() or 1) + 10)
  b:Show()
end

function BagHighlight.Target() return target, cheapest end

local function soon()
  ns.Debounce("bag highlight", 0.2, BagHighlight.Refresh)
end

-- The tooltip for the highlighted item says why it's highlighted.
local function onItemTooltip(tooltip)
  if target and tooltip.GetOwner and tooltip:GetOwner() == target then
    local c = ns.Util.RGB.bad
    tooltip:AddLine(L.TOOLTIP, c[1], c[2], c[3])
  end
end

ns.Listen("READY", function()
  ns.On("BAG_UPDATE_DELAYED", soon)
  ns.On("BAG_OPEN", soon)
  ns.Listen("UPDATE", soon) -- prices changed
  for _, name in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
    if _G[name] and hooksecurefunc then hooksecurefunc(name, soon) end
  end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
      ns.Safe("bag tooltip", onItemTooltip, tooltip)
    end)
  end
end)
