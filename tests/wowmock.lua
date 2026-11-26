-- A fake WoW environment, just enough to load Craft Margin and see what the player would see.
-- Globals set by run.py before this file runs: ADDON_DIR, TOC_FILES.

Mock = {
  clock = 1700000000,
  timers = {},
  printed = {},
  events = {},
  professions = {},             -- { name, skillLine, index }
  ts = { open = nil, linked = false, recipes = {} }, -- recipes[skillLine] = { [id] = { info, schematic } }
  items = {},                   -- [itemID] = { name, bind }
  faction = "Alliance",
  merchant = {},                -- { { id, price, stack, available } }
  meta = { Version = "0.1.0" },
  secret = {},
  bags = {},                    -- [itemID] = count
}

local noop = function() end

---------------------------------------------------------------------------
-- Lua/WoW globals

format = string.format
strlower = string.lower
strtrim = function(s) return (s:match("^%s*(.-)%s*$")) end
tinsert, tremove = table.insert, table.remove
floor, ceil, max, min, abs = math.floor, math.ceil, math.max, math.min, math.abs
wipe = function(t) for k in pairs(t) do t[k] = nil end return t end
time = function(t) if t then return os.time(t) end return Mock.clock end
GetTime = function() return Mock.clock end
GetServerTime = function() return Mock.clock end
print = function(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
  table.insert(Mock.printed, table.concat(parts, " "))
end
GetBuildInfo = function() return "1.60.1", "70888", "Nov 2026", 16001 end
InCombatLockdown = function() return false end
IsShiftKeyDown = function() return Mock.shift == true end
IsControlKeyDown = function() return Mock.ctrl == true end
HandleModifiedItemClick = function(link) Mock.modifiedClick = link end
issecretvalue = function(v) return v ~= nil and Mock.secret[v] == true end
UnitFactionGroup = function() return Mock.faction, Mock.faction end
SlashCmdList = {}
UISpecialFrames = {}
Enum = { CraftingReagentType = { Modifying = 0, Basic = 1, Finishing = 2 } }
C_AddOns = { GetAddOnMetadata = function(_, field) return Mock.meta[field] end }

---------------------------------------------------------------------------
-- Frames

local NOOP_PREFIX = { "Set", "Enable", "Disable", "Register", "Unregister", "Clear", "Raise", "Lower",
  "Start", "Stop", "Lock", "Unlock" }

local Frame = {}
local FrameMT = {
  __index = function(_, k)
    local v = Frame[k]
    if v ~= nil then return v end
    if type(k) == "string" then
      for _, p in ipairs(NOOP_PREFIX) do
        if k:sub(1, #p) == p then return noop end
      end
    end
    return nil
  end,
}

function CreateFrame(kind, name, parent, template)
  local f = setmetatable({ _kind = kind, _name = name, _parent = parent, _template = template,
    _shown = true, _scripts = {}, _children = {}, _text = nil, _color = nil, _points = {} }, FrameMT)
  if name then _G[name] = f end
  if parent then table.insert(rawget(parent, "_children"), f) end
  Mock.allFrames = Mock.allFrames or {}
  table.insert(Mock.allFrames, f)
  if template and template:find("BasicFrameTemplate") then
    f.TitleText = f:CreateFontString()
  end
  return f
end

function Frame:CreateFontString() return CreateFrame("FontString", nil, self) end
function Frame:CreateTexture() return CreateFrame("Texture", nil, self) end
function Frame:GetName() return rawget(self, "_name") end
function Frame:GetParent() return rawget(self, "_parent") end
function Frame:SetParent(p) self._parent = p end
function Frame:SetScript(name, fn)
  self._scripts[name] = fn
  if name == "OnUpdate" and fn then
    Mock.updaters = Mock.updaters or {}
    table.insert(Mock.updaters, self)
  end
end
function Frame:GetScript(name) return self._scripts[name] end
function Frame:HookScript(name, fn)
  local old = self._scripts[name]
  self._scripts[name] = function(...) if old then old(...) end fn(...) end
end
function Frame:RegisterEvent(e)
  Mock.events[e] = Mock.events[e] or {}
  table.insert(Mock.events[e], self)
end
function Frame:Show()
  if self._shown then return end
  self._shown = true
  if self._scripts.OnShow then self._scripts.OnShow(self) end
end
function Frame:Hide()
  if not self._shown then return end
  self._shown = false
  if self._scripts.OnHide then self._scripts.OnHide(self) end
end
function Frame:SetShown(v) if v then self:Show() else self:Hide() end end
function Frame:IsShown() return self._shown end
function Frame:IsVisible()
  local f = self
  while f do
    if not rawget(f, "_shown") then return false end
    f = rawget(f, "_parent")
  end
  return true
end
-- Buttons light up while the mouse is over them; child hover areas lock it on.
function Frame:LockHighlight() self._lit = true end
function Frame:UnlockHighlight() self._lit = false end
function Frame:IsLit() return self._lit == true end
function Frame:SetTexture(t) self._texture = t end
function Frame:GetTexture() return self._texture end
function Frame:HighlightText() self._highlighted = true end
function Frame:ClearFocus() self._focus = false end
function Frame:SetFocus() self._focus = true end
function Frame:SetChecked(v) self._checked = v and true or false end
function Frame:GetChecked() return self._checked == true end
function Frame:Enable() self._disabled = false end
function Frame:Disable() self._disabled = true end
function Frame:IsEnabled() return not self._disabled end
function Frame:SetSize(w, h) self._w, self._h = w, h end
function Frame:GetHeight() return rawget(self, "_h") or 0 end
function Frame:SetText(t) self._text = t end
function Frame:GetText() return self._text end
function Frame:GetStringWidth() return #(self._text or "") * 6 end
function Frame:SetTextColor(r, g, b) self._color = { r, g, b } end
function Frame:GetTextColor() local c = self._color or { 1, 1, 1 } return c[1], c[2], c[3] end
function Frame:SetPoint(...) table.insert(self._points, { ... }) end
function Frame:ClearAllPoints() self._points = {} end
function Frame:GetPoint() local p = self._points[1] or {} return p[1], p[2], p[3], p[4], p[5] end

function EnumerateFrames(prev)
  local list = Mock.allFrames or {}
  if not prev then return list[1] end
  for i, f in ipairs(list) do if f == prev then return list[i + 1] end end
end
function Frame:GetID() return rawget(self, "_id") or 0 end
function Frame:SetID(id) self._id = id end
function Frame:GetFrameLevel() return rawget(self, "_level") or 1 end
function Frame:GetFrameStrata() return "MEDIUM" end
function Frame:SetAllPoints(other) self._allPoints = other end

-- Bags: Mock.bags is item counts by ID (for GetItemCount); Mock.slots[bag][slot] = { id, count, bound, noValue }
Mock.slots = {}
C_Container = {
  GetContainerNumSlots = function(bag) return Mock.slots[bag] and 16 or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local s = Mock.slots[bag] and Mock.slots[bag][slot]
    if not s then return nil end
    return { itemID = s.id, stackCount = s.count or 1, isBound = s.bound, hasNoValue = s.noValue }
  end,
}
NUM_BAG_SLOTS = 4

-- A bag window's item button, the way bag addons make them.
function BagButton(bag, slot)
  local b = CreateFrame("ItemButton", nil, UIParent, "ContainerFrameItemButtonTemplate")
  b:SetID(slot)
  b._bag = bag
  function b:GetBagID() return self._bag end
  -- Bag addons reuse buttons: switching views points the same button at another slot.
  function b:Assign(newBag, newSlot) self._bag = newBag; self:SetID(newSlot) end
  return b
end

UIParent = CreateFrame("Frame", "UIParent")
Minimap = CreateFrame("Frame", "Minimap", UIParent)

function hooksecurefunc(t, name, fn)
  if type(t) == "string" then t, name, fn = _G, t, name end
  local orig = t[name]
  t[name] = function(...) local r = { orig(...) } fn(...) return unpack(r) end
end

GameTooltip = CreateFrame("GameTooltip", "GameTooltip", UIParent)
GameTooltip._shown = false
GameTooltip.lines = {}
function GameTooltip:SetOwner(owner)
  self.owner = owner; self.lines = {}; self.recipe = nil; self.item = nil
  local s = self._scripts.OnTooltipCleared
  if s then s(self) end
end
function GameTooltip:GetOwner() return self.owner end
function GameTooltip:SetText(text) self.lines = { { text } } end
function GameTooltip:ClearLines()
  self.lines = {}
  local s = self._scripts.OnTooltipCleared
  if s then s(self) end
end
GameTooltipTextLeft1 = CreateFrame("FontString", nil, GameTooltip)
function GameTooltipTextLeft1:SetText(t) GameTooltip.lines[1] = { t } end
function GameTooltipTextLeft1:GetText() return GameTooltip.lines[1] and GameTooltip.lines[1][1] end
function GameTooltip:NumLines() return #self.lines end

-- Run every frame's OnUpdate scripts for `seconds` (in 0.05s frames).
function Frames(seconds)
  for _ = 1, math.floor(seconds / 0.05 + 0.5) do
    for _, f in ipairs(Mock.updaters or {}) do f._scripts.OnUpdate(f, 0.05) end
  end
end
function GameTooltip:ClearLines() self.lines = {} end
function GameTooltip:SetRecipeResultItem(recipeID) self.recipe = recipeID end
function GameTooltip:SetItemByID(itemID) self.item = itemID end
function GameTooltip:AddLine(text) table.insert(self.lines, { text }) end
function GameTooltip:AddDoubleLine(l, r, lr, lg, lb, rr, rg, rb)
  table.insert(self.lines, { l, r, { rr, rg, rb }, left = { lr, lg, lb } })
end

---------------------------------------------------------------------------
-- Timers and events

C_Timer = {
  After = function(sec, fn) table.insert(Mock.timers, { at = Mock.clock + sec, fn = fn }) end,
  NewTicker = function(sec, fn)
    local t = { at = Mock.clock + sec, fn = fn, every = sec }
    table.insert(Mock.timers, t)
    return { Cancel = function() t.cancelled = true end }
  end,
}

function Advance(seconds)
  local target = Mock.clock + (seconds or 0)
  while true do
    local best, bi
    for i, t in ipairs(Mock.timers) do
      if not t.cancelled and t.at <= target and (not best or t.at < best.at) then best, bi = t, i end
    end
    if not best then break end
    Mock.clock = best.at
    if best.every then best.at = best.at + best.every else table.remove(Mock.timers, bi) end
    best.fn()
  end
  Mock.clock = target
end

function FireEvent(event, ...)
  for _, f in ipairs(Mock.events[event] or {}) do
    local s = f._scripts.OnEvent
    if s then s(f, event, ...) end
  end
end

function Click(f, ...) local s = f._scripts.OnClick; assert(s, "no OnClick"); s(f, ...) end
function Enter(f) local s = f._scripts.OnEnter; assert(s, "no OnEnter"); s(f) end
function Leave(f) local s = f._scripts.OnLeave; assert(s, "no OnLeave"); s(f) end

---------------------------------------------------------------------------
-- Professions and trade skills

function GetProfessions()
  local s = {}
  for _, p in ipairs(Mock.professions) do s[p.index] = p.index end
  return s[1], s[2], s[3], s[4], s[5]
end

function GetProfessionInfo(index)
  for _, p in ipairs(Mock.professions) do
    if p.index == index then return p.name, 1, p.rank or 1, 300, 0, 0, p.skillLine end
  end
end

-- slot: 1/2 primary, 4 fishing, 5 cooking
function AddProfession(name, skillLine, slot, rank)
  table.insert(Mock.professions, { name = name, skillLine = skillLine, index = slot, rank = rank })
end

function SetSkill(skillLine, rank)
  for _, p in ipairs(Mock.professions) do if p.skillLine == skillLine then p.rank = rank end end
  FireEvent("SKILL_LINES_CHANGED")
  Advance(1)
end

-- AddRecipe(197, { id=, name=, out=, mats={{id,n}}, min=, max=, learned= })
function AddRecipe(skillLine, r)
  Mock.ts.recipes[skillLine] = Mock.ts.recipes[skillLine] or {}
  local slots = {}
  for _, m in ipairs(r.mats or {}) do
    table.insert(slots, { reagents = { { itemID = m[1] } }, quantityRequired = m[2],
      reagentType = m.type or 1, required = m.required ~= false })
  end
  Mock.ts.recipes[skillLine][r.id] = {
    info = { recipeID = r.id, name = r.name, learned = r.learned ~= false, numSkillUps = r.points or 1,
      maxTrivialLevel = r.grey or 0, relativeDifficulty = r.difficulty },
    schematic = { recipeID = r.id, outputItemID = r.out, quantityMin = r.min or 1, quantityMax = r.max or r.min or 1,
      reagentSlotSchematics = slots },
  }
end

local function openRecipes()
  local p = Mock.ts.open
  return p and Mock.ts.recipes[p.skillLine] or {}
end

C_TradeSkillUI = {
  GetBaseProfessionInfo = function()
    local p = Mock.ts.open
    if not p then return nil end
    return { professionID = p.skillLine, professionName = p.name }
  end,
  IsTradeSkillLinked = function() return Mock.ts.linked end,
  IsTradeSkillGuild = function() return false end,
  IsNPCCrafting = function() return false end,
  GetAllRecipeIDs = function()
    local ids = {}
    for id in pairs(openRecipes()) do table.insert(ids, id) end
    table.sort(ids)
    return ids
  end,
  OpenRecipe = function(id) Mock.openedRecipe = id end,
  GetRecipeSourceText = function(id) return Mock.sources and Mock.sources[id] end,
  GetRecipeInfo = function(id) local r = openRecipes()[id] return r and r.info end,
  GetRecipeSchematic = function(id) local r = openRecipes()[id] return r and r.schematic end,
}

-- Open a profession window and let the addon's debounce run.
function OpenProfession(name, skillLine, linked)
  Mock.ts.open = { name = name, skillLine = skillLine }
  Mock.ts.linked = linked or false
  FireEvent("TRADE_SKILL_SHOW")
  FireEvent("TRADE_SKILL_LIST_UPDATE")
  Advance(1)
end

function CloseProfession()
  Mock.ts.open = nil
  FireEvent("TRADE_SKILL_CLOSE")
end

---------------------------------------------------------------------------
-- Items

C_Map = { GetAreaInfo = function(id) return Mock.areas and Mock.areas[id] end }
C_Reputation = {
  GetFactionDataByID = function(id) local r = Mock.reps and Mock.reps[id] return r and { reaction = r } end,
}

C_Item = {
  GetItemInfo = function(id)
    if type(id) == "string" then
      for itemID, it in pairs(Mock.items) do
        if it.name == id then id = itemID break end
      end
    end
    local it = Mock.items[id]
    if not it then return nil end
    local link = "|cffffffff|Hitem:" .. id .. "::::::::|h[" .. it.name .. "]|h|r"
    return it.name, link, 1, 1, 1, "Trade Goods", "", 20, "", 134400, it.vendor or 0, it.class or 7, 0, it.bind or 0
  end,
  GetItemCount = function(id) return Mock.bags[id] or 0 end,
  GetItemIconByID = function(id) local it = Mock.items[id] return it and it.icon end,
  RequestLoadItemDataByID = noop,
}

function Item(id, name, bind, vendor, icon) Mock.items[id] = { name = name, bind = bind, vendor = vendor, icon = icon } end

---------------------------------------------------------------------------
-- Merchant

GetMerchantNumItems = function() return #Mock.merchant end
GetMerchantItemID = function(i) return Mock.merchant[i] and Mock.merchant[i].id end
C_MerchantFrame = {
  GetItemInfo = function(i)
    local m = Mock.merchant[i]
    if not m then return nil end
    return { price = m.price, stackCount = m.stack or 1, numAvailable = m.available or -1, hasExtendedCost = false }
  end,
}

function VisitVendor(items)
  Mock.merchant = items
  FireEvent("MERCHANT_SHOW")
  Advance(1)
end

---------------------------------------------------------------------------
-- Auctionator

function InstallAuctionator(opts)
  opts = opts or {}
  Mock.auc = { prices = {}, ages = {}, callbacks = {}, searches = {} }
  local v1 = {
    GetAuctionPriceByItemID = function(caller, id)
      assert(type(caller) == "string", "callerID")
      return Mock.auc.prices[id]
    end,
    MultiSearchAdvanced = not opts.noAdvanced and function(caller, terms)
      assert(type(caller) == "string", "callerID")
      table.insert(Mock.auc.searches, { kind = "advanced", terms = terms })
    end or nil,
    MultiSearchExact = function(caller, names)
      assert(type(caller) == "string", "callerID")
      table.insert(Mock.auc.searches, { kind = "exact", terms = names })
    end,
    RegisterForDBUpdate = function(caller, cb)
      assert(type(caller) == "string", "callerID")
      table.insert(Mock.auc.callbacks, cb)
    end,
  }
  if not opts.noAge then
    v1.GetAuctionAgeByItemID = function(_, id) return Mock.auc.ages[id] end
  end
  Auctionator = { API = { v1 = v1 } }
end

function InstallTSM()
  Mock.tsm = { prices = {}, strings = {} }
  TSM_API = {
    GetCustomPriceValue = function(str, itemString)
      table.insert(Mock.tsm.strings, str)
      return Mock.tsm.prices[tonumber(itemString:match("^i:(%d+)$"))]
    end,
  }
end

function SetTSMPrice(id, copper) Mock.tsm.prices[id] = copper end

function SetPrice(id, copper, ageDays)
  Mock.auc.prices[id] = copper
  Mock.auc.ages[id] = ageDays or 0
end

function OpenAuctionHouse() FireEvent("AUCTION_HOUSE_SHOW"); Advance(1) end
function CloseAuctionHouse() FireEvent("AUCTION_HOUSE_CLOSED") end
function ShiftClick(f) Mock.shift = true; Click(f); Mock.shift = false; Advance(1) end

-- Last Auctionator search as "Name xN, Name xN".
function LastSearch()
  local s = Mock.auc.searches[#Mock.auc.searches]
  if not s then return nil end
  local out = {}
  for _, t in ipairs(s.terms) do
    if type(t) == "table" then
      table.insert(out, t.searchString .. " x" .. t.quantity .. (t.isExact and "" or " (not exact)"))
    else
      table.insert(out, t)
    end
  end
  return s.kind .. ": " .. table.concat(out, ", ")
end

function AucScanFinished()
  for _, cb in ipairs(Mock.auc.callbacks) do cb() end
  Advance(1)
end

---------------------------------------------------------------------------
-- Loading the addon

function Boot()
  NS = {}
  for _, path in ipairs(TOC_FILES) do
    local chunk = assert(loadfile(ADDON_DIR .. "/" .. path))
    chunk("CraftMargin", NS)
  end
  FireEvent("ADDON_LOADED", "CraftMargin")
  FireEvent("PLAYER_LOGIN")
  return NS
end

function Slash(msg)
  SlashCmdList.CRAFTMARGIN(msg or "")
  Advance(1)
end

---------------------------------------------------------------------------
-- Test helpers

TESTS = {}
function test(name, fn) table.insert(TESTS, { name = name, fn = fn }) end

function Strip(s)
  if s == nil then return nil end
  s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  return (s:gsub("|T(.-)|t", function(t)
    if t:find("ReadyCheck", 1, true) then return "✓" end
    local coin = t:match("UI%-(%a+)Icon")
    if coin then return ({ Gold = "g", Silver = "s", Copper = "c" })[coin] end
    return "[" .. (t:match("^([^:]+)") or "?") .. "]"
  end))
end

local function show(v)
  if type(v) == "string" then return string.format("%q", v) end
  return tostring(v)
end

function eq(actual, expected, msg)
  if actual ~= expected then
    error((msg and (msg .. ": ") or "") .. "expected " .. show(expected) .. ", got " .. show(actual), 2)
  end
end

function ok(cond, msg)
  if not cond then error(msg or "assertion failed", 2) end
end

function Printed(pattern)
  for _, line in ipairs(Mock.printed) do
    if Strip(line):find(pattern, 1, true) then return true end
  end
  return false
end

-- Colour of a font string as a status word.
function ColorOf(fs)
  local r, g, b = fs:GetTextColor()
  for kind, c in pairs(NS.Util.RGB) do
    if math.abs(c[1] - r) < 0.01 and math.abs(c[2] - g) < 0.01 and math.abs(c[3] - b) < 0.01 then return kind end
  end
  return "?"
end

-- What the main window shows, as plain data.
function Window()
  local M = NS.UI.Main
  local w = { shown = M.frame and M.frame:IsShown(), tabs = {}, rows = {} }
  if not M.frame then return w end
  for _, t in ipairs(M.tabs) do
    if t:IsShown() then table.insert(w.tabs, { name = t.text:GetText(), on = t.line:IsShown() }) end
  end
  for _, row in ipairs(M.rows) do
    if row:IsShown() then
      table.insert(w.rows, {
        name = row.name:GetText(), cost = Strip(row.cost:GetText()), sells = Strip(row.sells:GetText()),
        profit = Strip(row.profit:GetText()), color = ColorOf(row.profit), nameColor = ColorOf(row.name), row = row,
      })
    end
  end
  w.status, w.statusColor = M.status:GetText(), ColorOf(M.status)
  w.empty = M.empty:IsShown() and M.empty:GetText() or nil
  w.footer = M.footer:GetText()
  return w
end
