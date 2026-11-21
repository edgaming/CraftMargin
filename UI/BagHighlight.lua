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
  KEEP_HINT = "Ctrl+Shift-click to keep it",
  KEPT = "Kept: never suggested to throw away",
  KEEP = "Craft Margin: won't suggest %s for throwing away any more.",
  UNKEEP = "Craft Margin: %s can be suggested for throwing away again.",
}

local border, target, cheapest
local THICK = 2

-- Midnight hides some frames' state from addons ("secret" values); testing one is an error,
-- so every answer from a frame is checked before it's used.
local IsSecret = ns.Util.IsSecret
local function ask(f, method)
  local fn = f[method]
  if type(fn) ~= "function" then return nil end
  local ok, v = pcall(fn, f)
  if not ok or IsSecret(v) then return nil end
  return v
end

local function field(f, key)
  local v = rawget(f, key)
  if IsSecret(v) then return nil end
  return v
end

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
  if border.SetIgnoreParentAlpha then border:SetIgnoreParentAlpha(true) end
  border:SetScript("OnUpdate", function(self)
    -- Follow the button: gone when the bag window closes or the slot is redrawn.
    if not target or ask(target, "IsVisible") ~= true then
      self:Hide()
      target = nil
    end
  end)
  return border
end

local function slotOf(f)
  local bag = ask(f, "GetBagID") or field(f, "bagID") or field(f, "bag")
  local slot = ask(f, "GetID")
  if type(slot) ~= "number" or slot <= 0 then slot = field(f, "slotID") or field(f, "slot") end
  return bag, slot
end

-- Only frames that look like bag item buttons get asked anything else.
local function looksLikeBagButton(f)
  return type(f) == "table" and (type(f.GetBagID) == "function" or rawget(f, "bagID") ~= nil)
end

-- Bag windows found so far. When one opens again we look again, because bag addons don't always
-- open through the game's bag functions (so our hooks on those never fire).
local windows = {}
local function windowOf(f)
  local w, p = f, ask(f, "GetParent")
  for _ = 1, 20 do
    if not p or p == UIParent then return w end
    w, p = p, ask(p, "GetParent")
  end
  return w
end

local function watchWindow(f, onShow)
  local w = windowOf(f)
  if not w or windows[w] or type(w.HookScript) ~= "function" then return end
  windows[w] = true
  pcall(w.HookScript, w, "OnShow", onShow)
end

-- The visible item button showing bag/slot, from any bag addon. Also returns how many visible
-- bag buttons there were, for /margin debug.
function BagHighlight.FindButton(bag, slot, onShow)
  local f, found, seen = EnumerateFrames(), nil, 0
  BagHighlight.sample = nil
  while f do
    if looksLikeBagButton(f) and ask(f, "IsVisible") == true then
      seen = seen + 1
      if onShow then watchWindow(f, onShow) end
      local b, s = slotOf(f)
      if seen == 1 then BagHighlight.sample = string.format("%s/%s", tostring(b), tostring(s)) end
      if not found and b == bag and s == slot then found = f end
    end
    f = EnumerateFrames(f)
  end
  return found, seen
end

local retries = 0
local soon

-- The border sits inside the slot button (so it draws with the slot, above its icon and the bag
-- window's art). Slot buttons are protected, so the border only moves outside combat.
function BagHighlight.Refresh()
  if InCombatLockdown and InCombatLockdown() then
    BagHighlight.afterCombat = true
    return
  end
  cheapest = ns.Cheapest.Find()
  local button, seen
  if cheapest then button, seen = BagHighlight.FindButton(cheapest.bag, cheapest.slot, soon) end
  BagHighlight.seen = seen or 0
  local b = MakeBorder()
  target = button
  if not button then
    b:Hide()
    -- Bag addons often lay out their buttons a moment after the window opens: look again a
    -- couple of times while bag buttons are showing.
    if cheapest and (seen or 0) > 0 and retries < 3 then
      retries = retries + 1
      ns.After(0.5, BagHighlight.Refresh)
    end
    return
  end
  retries = 0
  b:SetParent(button)
  b:ClearAllPoints()
  b:SetAllPoints(button)
  b:SetFrameLevel((ask(button, "GetFrameLevel") or 1) + 15)
  b:Show()
end

-- Ctrl+Shift-click an item in your bags to keep it (or stop keeping it).
function BagHighlight.ToggleKeep(itemID)
  if not itemID then return end
  local name = (ns.Api.Item(itemID)) or ("item " .. itemID)
  if ns.db.keep[itemID] then
    ns.db.keep[itemID] = nil
    print(string.format(L.UNKEEP, name))
  else
    ns.db.keep[itemID] = true
    print(string.format(L.KEEP, name))
  end
  BagHighlight.Refresh()
end

local function itemIDFromLink(link)
  return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

function BagHighlight.OnModifiedClick(link)
  if not (IsControlKeyDown and IsShiftKeyDown and IsControlKeyDown() and IsShiftKeyDown()) then return end
  if IsSecret(link) then return end
  BagHighlight.ToggleKeep(itemIDFromLink(link))
end

BagHighlight.ItemIDFromLink = itemIDFromLink

function BagHighlight.Target() return target, cheapest end

soon = function()
  retries = 0
  ns.Debounce("bag highlight", 0.2, BagHighlight.Refresh)
end

-- The tooltip for the highlighted item says why it's highlighted.
local function onItemTooltip(tooltip, data)
  local id = data and not IsSecret(data.id) and data.id
  if id and ns.db.keep[id] then
    local m = ns.Util.RGB.muted
    tooltip:AddLine(L.KEPT, m[1], m[2], m[3])
  elseif target and tooltip.GetOwner and tooltip:GetOwner() == target then
    local c, m = ns.Util.RGB.bad, ns.Util.RGB.muted
    tooltip:AddLine(L.TOOLTIP, c[1], c[2], c[3])
    tooltip:AddLine(L.KEEP_HINT, m[1], m[2], m[3])
  end
end

ns.Listen("READY", function()
  ns.On("BAG_UPDATE_DELAYED", soon)
  ns.On("BAG_OPEN", soon)
  ns.On("PLAYER_REGEN_ENABLED", function()
    if BagHighlight.afterCombat then
      BagHighlight.afterCombat = nil
      soon()
    end
  end)
  if hooksecurefunc and HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link) ns.Safe("keep item", BagHighlight.OnModifiedClick, link) end)
  end
  ns.Listen("UPDATE", soon) -- prices changed
  for _, name in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
    if _G[name] and hooksecurefunc then hooksecurefunc(name, soon) end
  end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      ns.Safe("bag tooltip", onItemTooltip, tooltip, data)
    end)
  end
end)
