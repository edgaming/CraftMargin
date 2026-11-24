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
  local wait = 0
  border:SetScript("OnUpdate", function(self, elapsed)
    -- Follow the button: gone when the bag window closes. Bag addons reuse buttons when you
    -- switch views or sort, so also check now and then that it still shows the same thing.
    if not target or ask(target, "IsVisible") ~= true then
      self:Hide()
      target = nil
      return
    end
    wait = wait - (elapsed or 0)
    if wait > 0 then return end
    wait = 0.25
    if not BagHighlight.StillShows(target) then
      self:Hide()
      target = nil
      BagHighlight.Soon()
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

-- How well a button matches the cheapest slot: 2 = that exact slot, 1 = another slot holding
-- the same item. Views that merge stacks (EllesmereUI's All Items) show one button per item, which
-- reports just one of its slots, so the same item is the best there is.
local function matchOf(f, c)
  local b, s = slotOf(f)
  if b == c.bag and s == c.slot then return 2, b, s end
  if ns.Api.SlotItem(b, s) == c.itemID then return 1, b, s end
  return 0, b, s
end

-- Bag buttons seen so far (weak: bag addons may throw theirs away). Walking every frame in the
-- UI is slow with a big UI, so it only happens when a bag window opens or a known button can't be
-- found; bag changes while looting just look through these.
local buttons = setmetatable({}, { __mode = "k" })
local lastScan = -math.huge
local SCAN_GAP = 1 -- seconds between full walks caused by bag changes

local function now() return GetTime and GetTime() or 0 end
local function clock() return debugprofilestop and debugprofilestop() or 0 end

local function scanAll(onShow)
  local f, n = EnumerateFrames(), 0
  while f do
    n = n + 1
    if looksLikeBagButton(f) and not buttons[f] then
      buttons[f] = true
      watchWindow(f, onShow)
    end
    f = EnumerateFrames(f)
  end
  lastScan = now()
  BagHighlight.scanned = n
end

local function anyWindowShown()
  for w in pairs(windows) do
    if ask(w, "IsVisible") == true then return true end
  end
  return false
end

-- The visible item button for the cheapest slot among the known buttons. Also returns how many
-- visible bag buttons there were, for /margin debug.
local function search(c)
  local found, best, seen = nil, 0, 0
  BagHighlight.sample = nil
  for f in pairs(buttons) do
    if ask(f, "IsVisible") == true then
      seen = seen + 1
      local m, b, s = matchOf(f, c)
      if seen == 1 then BagHighlight.sample = string.format("%s/%s", tostring(b), tostring(s)) end
      if m > best then found, best = f, m end
    end
  end
  return found, seen
end

-- scan: walk every frame first (a bag window just opened). Otherwise only the known buttons,
-- with a walk now and then if the slot's button isn't among them.
function BagHighlight.FindButton(c, scan, onShow)
  if scan then scanAll(onShow) end
  local found, seen = search(c)
  if not found and not scan and seen > 0 and now() - lastScan >= SCAN_GAP then
    scanAll(onShow)
    found, seen = search(c)
  end
  return found, seen
end

-- Whether the highlighted button still shows what it showed when we picked it.
local shownBag, shownSlot
function BagHighlight.StillShows(f)
  if not cheapest then return false end
  local b, s = slotOf(f)
  return b == shownBag and s == shownSlot and ns.Api.SlotItem(b, s) == cheapest.itemID
end

local retries = 0
local soon

-- The border sits inside the slot button (so it draws with the slot, above its icon and the bag
-- window's art). Slot buttons are protected, so the border only moves outside combat.
-- scan: a bag window may just have opened, so walk all frames for new buttons.
function BagHighlight.Refresh(scan)
  if InCombatLockdown and InCombatLockdown() then
    BagHighlight.afterCombat = true
    return
  end
  local started = clock()
  local b = MakeBorder()
  if scan then scanAll(BagHighlight.Opened) end
  -- Bags closed: nothing to draw, so don't work anything out.
  if not anyWindowShown() then
    b:Hide()
    target, cheapest = nil, nil
    BagHighlight.seen, BagHighlight.ms = 0, clock() - started
    return
  end
  cheapest = ns.Cheapest.Find()
  local button, seen
  if cheapest then button, seen = BagHighlight.FindButton(cheapest, false, BagHighlight.Opened) end
  BagHighlight.seen = seen or 0
  BagHighlight.ms = clock() - started
  target = button
  if not button then
    b:Hide()
    -- Bag addons often lay out their buttons a moment after the window opens: look again a
    -- couple of times while bag buttons are showing.
    if cheapest and (seen or 0) > 0 and retries < 3 then
      retries = retries + 1
      ns.After(0.5, function() BagHighlight.Refresh(true) end)
    end
    return
  end
  retries = 0
  shownBag, shownSlot = slotOf(button)
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

-- Bag changes come in bursts while looting: wait for them to settle, then do one check.
local pendingScan = false
local function refreshPending()
  local scan = pendingScan
  pendingScan = false
  BagHighlight.Refresh(scan)
end
soon = function(scan)
  retries = 0
  if scan == true then pendingScan = true end
  ns.Debounce("bag highlight", 0.3, refreshPending)
end
local function opened() soon(true) end
BagHighlight.Soon = function() soon() end
BagHighlight.Opened = opened

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
  ns.On("BAG_UPDATE_DELAYED", BagHighlight.Soon)
  ns.On("BAG_OPEN", opened)
  ns.On("PLAYER_REGEN_ENABLED", function()
    if BagHighlight.afterCombat then
      BagHighlight.afterCombat = nil
      soon()
    end
  end)
  if hooksecurefunc and HandleModifiedItemClick then
    hooksecurefunc("HandleModifiedItemClick", function(link) ns.Safe("keep item", BagHighlight.OnModifiedClick, link) end)
  end
  ns.Listen("UPDATE", BagHighlight.Soon) -- prices changed
  for _, name in ipairs({ "ToggleAllBags", "OpenAllBags", "ToggleBackpack", "OpenBackpack", "ToggleBag", "OpenBag" }) do
    if _G[name] and hooksecurefunc then hooksecurefunc(name, function() opened() end) end
  end
  if TooltipDataProcessor and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
      ns.Safe("bag tooltip", onItemTooltip, tooltip, data)
    end)
  end
end)
