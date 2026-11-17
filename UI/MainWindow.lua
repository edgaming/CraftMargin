-- The main window: one tab per crafting profession, recipes sorted by profit.
local _, ns = ...
local Main = {}
ns.UI.Main = Main

local UI, Util, Api = ns.UI, ns.Util, ns.Api

local L = {
  TITLE = "Craft Margin",
  RECIPE = "Recipe",
  COST = "Cost",
  SELLS = "Sells",
  PROFIT = "Profit",
  OPEN_ONCE = "Open your %s window once to read your recipes.",
  NO_PROFS = "You have no crafting professions.",
  NOTHING = "None of these recipes make something you can sell.",
  FOOTER = "%d recipes · read %s",
  VENDOR_TAG = "vendor",
  CANT_OPEN = "Craft Margin: this client can't open a recipe from here. Open the profession window yourself.",
}

local W, H = 560, 440
local ROW_H = 18
local CONTENT_W = 516
-- Right edges of the money columns, in row coordinates.
local COL_COST, COL_SELLS, COL_PROFIT = 290, 375, 462

Main.rows, Main.tabs = {}, {}

---------------------------------------------------------------------------
-- Data

function Main.Professions()
  local out = {}
  for _, p in ipairs(Api.Professions()) do
    if not ns.GATHERING[p.skillLine] then out[#out + 1] = p end
  end
  return out
end

local function evaluate(recipe)
  local _, bind, value = Api.Item(recipe.out)
  if bind == nil then Api.RequestItem(recipe.out) end
  local bound = ns.Ranking.SellableBind(bind) == false
  if bound and value == 0 then return nil end -- can't be sold anywhere
  return ns.Costing.Evaluate(recipe, {
    sell = ns.Prices.Sell, mat = ns.Prices.Material, vendor = ns.Prices.Vendor, bound = bound,
  }, ns.AH_CUT)
end

local function nameOf(itemID)
  return (Api.Item(itemID)) or ("item " .. itemID)
end

-- Everything the window shows for one profession.
function Main.Compute(prof)
  local view = { entry = ns.Recipes.For(prof), rows = {}, skipped = 0 }
  if view.entry then
    view.rows, view.skipped = ns.Ranking.Build(view.entry.recipes, evaluate)
  end
  local hasAny, newest = false, nil
  for _, r in ipairs(view.rows) do
    if r.sell then
      hasAny = true
      local age = Api.AucAge(r.recipe.out)
      if age and (newest == nil or age < newest) then newest = age end
    end
  end
  view.status, view.statusKind = ns.Prices.Status(hasAny, newest)
  return view
end

---------------------------------------------------------------------------
-- Widgets

local function SetColumn(fs, parent, right)
  fs:SetPoint("RIGHT", parent, "LEFT", right, 0)
end

local function Tab(i)
  local tab = Main.tabs[i]
  if tab then return tab end
  tab = CreateFrame("Button", nil, Main.frame)
  tab:SetHeight(20)
  tab.text = UI.Text(tab, "GameFontNormal", "CENTER")
  tab.text:SetPoint("CENTER", 0, 1)
  tab.line = tab:CreateTexture(nil, "ARTWORK")
  tab.line:SetColorTexture(1, 0.82, 0, 0.9)
  tab.line:SetHeight(2)
  tab.line:SetPoint("BOTTOMLEFT", 4, 0)
  tab.line:SetPoint("BOTTOMRIGHT", -4, 0)
  tab:SetScript("OnClick", function(self)
    ns.db.window.tab = self.skillLine
    Main.Refresh()
  end)
  Main.tabs[i] = tab
  return tab
end

local function Row(i)
  local row = Main.rows[i]
  if row then return row end
  row = CreateFrame("Button", nil, Main.content)
  row:SetSize(CONTENT_W, ROW_H)
  row:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  row.name = UI.Text(row, "GameFontHighlightSmall", "LEFT")
  row.name:SetPoint("LEFT", 4, 0)
  row.name:SetWidth(COL_COST - 90)
  row.name:SetWordWrap(false)

  -- Hovering the name shows what the recipe makes; clicking opens it in the profession window.
  row.nameHit = CreateFrame("Button", nil, row)
  row.nameHit:SetPoint("TOPLEFT", 0, 0)
  row.nameHit:SetSize(COL_COST - 86, ROW_H)
  row.nameHit:RegisterForClicks("LeftButtonUp")
  row.nameHit:SetScript("OnEnter", function(self)
    row:LockHighlight()
    if row.data then Api.RecipeTooltip(self, row.data.recipe.id, row.data.recipe.out) end
  end)
  row.nameHit:SetScript("OnLeave", function()
    row:UnlockHighlight()
    GameTooltip:Hide()
  end)
  row.nameHit:SetScript("OnClick", function()
    if row.data and not Api.OpenRecipe(row.data.recipe.id) then print(L.CANT_OPEN) end
  end)
  row.cost = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
  SetColumn(row.cost, row, COL_COST)
  row.sells = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
  SetColumn(row.sells, row, COL_SELLS)
  row.profit = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
  SetColumn(row.profit, row, COL_PROFIT)
  row.tag = UI.Text(row, "GameFontDisableSmall", "LEFT")
  row.tag:SetPoint("LEFT", row, "LEFT", COL_PROFIT + 5, 0)
  row.tag:SetText(L.VENDOR_TAG)
  UI.SetColor(row.tag, "muted")

  -- Hovering the profit shows the money math.
  row.hit = CreateFrame("Frame", nil, row)
  row.hit:SetSize(CONTENT_W - COL_SELLS - 4, ROW_H)
  row.hit:SetPoint("RIGHT", row, "LEFT", CONTENT_W, 0)
  row.hit:EnableMouse(true)
  row.hit:SetScript("OnEnter", function(self)
    row:LockHighlight()
    Main.ShowTooltip(self, row.data)
  end)
  row.hit:SetScript("OnLeave", function()
    row:UnlockHighlight()
    GameTooltip:Hide()
  end)

  Main.rows[i] = row
  return row
end

function Main.ShowTooltip(owner, r)
  if not r then return end
  local age = Util.DaysOld(Api.AucAge(r.recipe.out))
  UI.Tooltip(owner, r.recipe.name, ns.Costing.TooltipLines(r, ns.AH_CUT, nameOf, age))
end

function Main.Create()
  if Main.frame then return Main.frame end
  local f = CreateFrame("Frame", "CraftMarginFrame", UIParent, "BasicFrameTemplateWithInset")
  Main.frame = f
  f:SetSize(W, H)
  f:SetFrameStrata("HIGH")
  f:SetClampedToScreen(true)
  f:SetMovable(true)
  f:EnableMouse(true)
  f:RegisterForDrag("LeftButton")
  f:SetScript("OnDragStart", function(self) self:StartMoving() end)
  f:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relPoint, x, y = self:GetPoint()
    ns.db.window.point = { point, relPoint, x, y }
  end)
  local p = ns.db.window.point
  f:ClearAllPoints()
  if p then f:SetPoint(p[1], UIParent, p[2], p[3], p[4]) else f:SetPoint("CENTER") end
  f:Hide()
  table.insert(UISpecialFrames, "CraftMarginFrame") -- Esc closes it

  local title = f.TitleText or UI.Text(f, "GameFontHighlight", "CENTER")
  if not f.TitleText then title:SetPoint("TOP", 0, -5) end
  title:SetText(L.TITLE)

  Main.status = UI.Text(f, "GameFontNormalSmall", "RIGHT")
  Main.status:SetPoint("TOPRIGHT", -14, -34)

  local function header(text, right)
    local fs = UI.Text(f, "GameFontNormalSmall", right and "RIGHT" or "LEFT")
    fs:SetText(text)
    if right then fs:SetPoint("RIGHT", f, "TOPLEFT", 10 + right, -64) else fs:SetPoint("LEFT", f, "TOPLEFT", 14, -64) end
    return fs
  end
  Main.headers = {
    header(L.RECIPE), header(L.COST, COL_COST), header(L.SELLS, COL_SELLS), header(L.PROFIT, COL_PROFIT),
  }
  local rule = f:CreateTexture(nil, "ARTWORK")
  rule:SetColorTexture(1, 1, 1, 0.12)
  rule:SetHeight(1)
  rule:SetPoint("TOPLEFT", 12, -74)
  rule:SetPoint("TOPRIGHT", -12, -74)

  local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -78)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  Main.content = CreateFrame("Frame", nil, scroll)
  Main.content:SetSize(CONTENT_W, 1)
  scroll:SetScrollChild(Main.content)
  Main.scroll = scroll

  Main.empty = UI.Text(f, "GameFontNormal", "CENTER")
  Main.empty:SetPoint("CENTER", 0, -10)
  Main.empty:SetWidth(W - 80)
  UI.SetColor(Main.empty, "muted")

  Main.footer = UI.Text(f, "GameFontDisableSmall", "LEFT")
  Main.footer:SetPoint("BOTTOMLEFT", 14, 12)

  f:SetScript("OnShow", function() ns.Safe("window", Main.Refresh) end)
  return f
end

---------------------------------------------------------------------------
-- Drawing

local function DrawTabs(profs, selected)
  local x = 0
  for i, p in ipairs(profs) do
    local tab = Tab(i)
    tab.skillLine = p.skillLine
    tab.text:SetText(p.name)
    local width = tab.text:GetStringWidth() + 20
    tab:SetWidth(width)
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", Main.frame, "TOPLEFT", 12 + x, -28)
    x = x + width + 4
    local on = (p == selected)
    UI.SetColor(tab.text, on and "text" or "muted")
    tab.line:SetShown(on)
    tab:Show()
  end
  for i = #profs + 1, #Main.tabs do Main.tabs[i]:Hide() end
end

local function DrawRow(row, r)
  row.data = r
  row.name:SetText(r.recipe.name or "?")
  if r.complete then
    UI.SetColor(row.name, "text")
    row.cost:SetText(Util.Money(r.cost))
    row.sells:SetText(Util.Money(r.gross))
    row.profit:SetText(Util.SignedMoney(r.profit))
    UI.SetColor(row.cost, "text")
    UI.SetColor(row.sells, "text")
    UI.SetColor(row.profit, r.profit >= 0 and "good" or "bad")
    row.tag:SetShown(r.best == "vendor")
  else
    UI.SetColor(row.name, "muted")
    row.cost:SetText(r.matsKnown and Util.Money(r.cost) or "—")
    row.sells:SetText(r.gross and Util.Money(r.gross) or "—")
    row.profit:SetText("—")
    row.tag:Hide()
    UI.SetColor(row.cost, "muted")
    UI.SetColor(row.sells, "muted")
    UI.SetColor(row.profit, "muted")
  end
  row:Show()
end

function Main.Refresh()
  local f = Main.frame
  if not f then return end
  local profs = Main.Professions()
  local selected
  for _, p in ipairs(profs) do
    if p.skillLine == ns.db.window.tab then selected = p end
  end
  selected = selected or profs[1]
  DrawTabs(profs, selected)

  local rows, message, footer = {}, nil, ""
  local statusText, statusKind = ns.Prices.Status(false, nil)
  if not selected then
    message = L.NO_PROFS
  else
    local view = Main.Compute(selected)
    statusText, statusKind = view.status, view.statusKind
    if not view.entry then
      message = string.format(L.OPEN_ONCE, selected.name)
    else
      rows = view.rows
      if #rows == 0 then message = L.NOTHING end
      footer = string.format(L.FOOTER, #rows, Util.Ago(Api.Now() - view.entry.readAt))
    end
  end

  Main.status:SetText(statusText)
  UI.SetColor(Main.status, statusKind)
  for _, h in ipairs(Main.headers) do h:SetShown(message == nil) end
  Main.empty:SetText(message or "")
  Main.empty:SetShown(message ~= nil)
  Main.footer:SetText(footer)

  for i, r in ipairs(rows) do DrawRow(Row(i), r) end
  for i = #rows + 1, #Main.rows do
    Main.rows[i]:Hide()
    Main.rows[i].data = nil
  end
  Main.content:SetHeight(math.max(1, #rows * ROW_H))
end

function Main.Toggle()
  local f = Main.Create()
  if f:IsShown() then f:Hide() else f:Show() end
end

ns.Listen("UPDATE", function()
  if Main.frame and Main.frame:IsShown() then Main.Refresh() end
end)

ns.Listen("READY", function()
  ns.On("GET_ITEM_INFO_RECEIVED", ns.Update)
end)
