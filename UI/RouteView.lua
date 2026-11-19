-- The Level up view: the cheapest route from your skill to 300, as boxes top to bottom.
local _, ns = ...
local Route = {}
ns.UI.Route = Route

local UI, Util, Api = ns.UI, ns.Util, ns.Api

local L = {
  TITLE = "%s %d → %d",
  TOTAL = "About %s after selling",
  TOTAL_PROFIT = "Makes about %s",
  RESET = "Reset route",
  MAXED = "%s is maxed.",
  SKILL = "Skill %d → %d · about %d crafts",
  HERE = "You are here",
  KNOWN = "Known",
  LEARN = "Learn: trainer · %s",
  PINNED = "pinned",
  ALTS = "%d alternatives",
  ALT = "%d alternative",
  HIDE = "Hide alternatives",
  ALT_ROW = "×%d",
  MORE = "+%s",
  LESS = "-%s",
  SAME = "same",
  GAP = "No priced recipe for %d–%d",
  USE_THIS = "Click to use this recipe here",
}

local BOX_W, BOX_H, GAP_H, LINK_H, ALT_H, HEADER_H = 568, 62, 32, 10, 22, 46
local COLORS = { { 1, 0.5, 0.25 }, { 1, 0.9, 0.1 }, { 0.3, 0.8, 0.3 } }

Route.boxes, Route.links = {}, {}
Route.expanded = {} -- [step.from] = true

local function backdrop(f)
  if not f.SetBackdrop then return end
  f:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
  })
  f:SetBackdropColor(0, 0, 0, 0.35)
end

function Route.Create(parent)
  if Route.scroll then return end
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 10, -84)
  scroll:SetPoint("BOTTOMRIGHT", -30, 30)
  local content = CreateFrame("Frame", nil, scroll)
  content:SetSize(BOX_W + 8, 1)
  scroll:SetScrollChild(content)
  Route.scroll, Route.content = scroll, content

  Route.title = UI.Text(content, "GameFontNormalLarge", "LEFT")
  Route.title:SetPoint("TOPLEFT", 4, -4)
  Route.total = UI.Text(content, "GameFontHighlight", "RIGHT")
  Route.total:SetPoint("TOPRIGHT", -4, -6)
  Route.note = UI.Text(content, "GameFontDisableSmall", "LEFT")
  Route.note:SetPoint("TOPLEFT", 4, -26)
  UI.SetColor(Route.note, "muted")

  local reset = CreateFrame("Button", nil, content)
  reset:SetSize(90, 16)
  reset:SetPoint("TOPRIGHT", -4, -24)
  reset.text = UI.Text(reset, "GameFontNormalSmall", "RIGHT")
  reset.text:SetPoint("RIGHT")
  reset.text:SetText(L.RESET)
  reset:SetScript("OnClick", function() if Route.prof then ns.Leveling.ResetPins(Route.prof) end end)
  Route.reset = reset
  scroll:Hide()
end

local function AltRow(box, i)
  local row = box.alts[i]
  if row then return row end
  row = CreateFrame("Button", nil, box)
  row:SetSize(BOX_W - 60, ALT_H)
  row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetSize(16, 16)
  row.icon:SetPoint("LEFT", 0, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.name = UI.Text(row, "GameFontHighlightSmall", "LEFT")
  row.name:SetPoint("LEFT", 22, 0)
  row.crafts = UI.Text(row, "GameFontDisableSmall", "RIGHT")
  row.crafts:SetPoint("RIGHT", -90, 0)
  row.delta = UI.Text(row, "GameFontHighlightSmall", "RIGHT")
  row.delta:SetPoint("RIGHT", -4, 0)
  row:SetScript("OnEnter", function(self)
    local a, step = self.alt, self.step
    if not a then return end
    local lines = ns.Leveling.StepLines(a.cand, step.from, step.to, a.crafts)
    lines[#lines + 1] = { L.USE_THIS, nil, "muted" }
    UI.Tooltip(self, a.cand.name, lines)
  end)
  row:SetScript("OnLeave", function() GameTooltip:Hide() end)
  row:SetScript("OnClick", function(self)
    if self.alt and Route.prof then
      ns.Leveling.Pin(Route.prof, self.step.from, self.step.to, self.alt.cand.id)
    end
  end)
  box.alts[i] = row
  return row
end

local function Box(i)
  local box = Route.boxes[i]
  if box then return box end
  box = CreateFrame("Button", nil, Route.content, "BackdropTemplate")
  backdrop(box)
  box:SetWidth(BOX_W)
  box:RegisterForClicks("LeftButtonUp")
  box:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  box.icon = box:CreateTexture(nil, "ARTWORK")
  box.icon:SetSize(32, 32)
  box.icon:SetPoint("TOPLEFT", 10, -10)
  box.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  box.name = UI.Text(box, "GameFontHighlight", "LEFT")
  box.name:SetPoint("TOPLEFT", 50, -10)
  box.cost = UI.Text(box, "GameFontHighlight", "RIGHT")
  box.cost:SetPoint("TOPRIGHT", -12, -10)
  box.skill = UI.Text(box, "GameFontDisableSmall", "LEFT")
  box.skill:SetPoint("TOPLEFT", 50, -28)
  box.side = UI.Text(box, "GameFontDisableSmall", "RIGHT")
  box.side:SetPoint("TOPRIGHT", -12, -28)
  box.gapText = UI.Text(box, "GameFontNormal", "CENTER")
  box.gapText:SetPoint("CENTER")
  UI.SetColor(box.gapText, "bad")

  box.strip = {}
  for k = 1, 3 do
    local t = box:CreateTexture(nil, "ARTWORK")
    t:SetHeight(4)
    t:SetColorTexture(COLORS[k][1], COLORS[k][2], COLORS[k][3], 0.9)
    box.strip[k] = t
  end

  box.more = CreateFrame("Button", nil, box)
  box.more:SetSize(140, 14)
  box.more:SetPoint("TOPRIGHT", -12, -42)
  box.more.text = UI.Text(box.more, "GameFontNormalSmall", "RIGHT")
  box.more.text:SetPoint("RIGHT")
  box.more:SetScript("OnClick", function()
    local step = box.step
    if not step then return end
    Route.expanded[step.from] = not Route.expanded[step.from] or nil
    Route.Refresh(Route.prof)
  end)
  box.alts = {}

  box:SetScript("OnClick", function(self)
    local step = self.step
    if not step or step.gap then return end
    if Api.ShiftDown() then
      Api.OpenRecipe(step.cand.id)
    else
      ns.Shopping.Request(step.cand.eval, ns.Leveling.Crafts(step.crafts))
    end
  end)
  box:SetScript("OnEnter", function(self)
    local step = self.step
    if not step or step.gap then return end
    local lines = ns.Leveling.StepLines(step.cand, step.from, step.to, step.crafts)
    if step.pinned then lines[#lines + 1] = { ns.Leveling.PINNED_TEXT, nil, "muted" } end
    UI.Tooltip(self, step.cand.name, lines)
  end)
  box:SetScript("OnLeave", function() GameTooltip:Hide() end)

  Route.boxes[i] = box
  return box
end

local function Link(i)
  local t = Route.links[i]
  if t then return t end
  t = Route.content:CreateTexture(nil, "ARTWORK")
  t:SetColorTexture(1, 1, 1, 0.25)
  t:SetSize(2, LINK_H)
  Route.links[i] = t
  return t
end

local function DrawStrip(box, step)
  local o, y, g = ns.Leveling.Colors(step.cand, step.from, step.to)
  local width = BOX_W - 50 - 160
  local total = math.max(1, o + y + g)
  local x = 50
  for k, n in ipairs({ o, y, g }) do
    local t = box.strip[k]
    local w = width * n / total
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", box, "TOPLEFT", x, -46)
    t:SetWidth(math.max(1, w))
    t:SetShown(n > 0)
    x = x + w
  end
end

local function DrawBox(box, step, first)
  box.step = step
  for _, row in ipairs(box.alts) do row:Hide() end
  if step.gap then
    for _, fs in ipairs({ box.name, box.cost, box.skill, box.side }) do fs:SetText("") end
    box.icon:Hide()
    for _, t in ipairs(box.strip) do t:Hide() end
    box.more:Hide()
    box.gapText:SetText(string.format(L.GAP, step.from, step.to))
    box.gapText:Show()
    box:SetHeight(GAP_H)
    if box.SetBackdropBorderColor then box:SetBackdropBorderColor(1, 0.3, 0.3, 0.8) end
    return GAP_H
  end
  local c = step.cand
  box.gapText:Hide()
  box.icon:SetTexture(Api.ItemIcon(c.out))
  box.icon:Show()
  box.name:SetText(c.name)
  box.cost:SetText(step.cost < 0 and ("+" .. Util.Money(-step.cost)) or Util.Money(step.cost))
  UI.SetColor(box.cost, step.cost < 0 and "good" or "text")
  box.skill:SetText(string.format(L.SKILL, step.from, step.to, ns.Leveling.Crafts(step.crafts))
    .. (step.pinned and (" · " .. L.PINNED) or ""))
  local side = first and L.HERE or (c.known and L.KNOWN or string.format(L.LEARN, Util.Money(c.fee)))
  box.side:SetText(side)
  UI.SetColor(box.side, first and "head" or "muted")
  DrawStrip(box, step)

  local n = #step.alternatives
  local open = Route.expanded[step.from] and n > 0
  box.more:SetShown(n > 0)
  box.more.text:SetText(open and L.HIDE or string.format(n == 1 and L.ALT or L.ALTS, n))
  local h = BOX_H
  if open then
    for k, a in ipairs(step.alternatives) do
      local row = AltRow(box, k)
      row.alt, row.step = a, step
      row.icon:SetTexture(Api.ItemIcon(a.cand.out))
      row.name:SetText(a.cand.name)
      row.crafts:SetText(string.format(L.ALT_ROW, ns.Leveling.Crafts(a.crafts)))
      local d = math.floor(a.delta + 0.5)
      if d > 0 then
        row.delta:SetText(string.format(L.MORE, Util.Money(d)))
        UI.SetColor(row.delta, "muted")
      elseif d < 0 then
        row.delta:SetText(string.format(L.LESS, Util.Money(-d)))
        UI.SetColor(row.delta, "good")
      else
        row.delta:SetText(L.SAME)
        UI.SetColor(row.delta, "muted")
      end
      row:ClearAllPoints()
      row:SetPoint("TOPLEFT", box, "TOPLEFT", 50, -(BOX_H - 4) - (k - 1) * ALT_H)
      row:Show()
    end
    h = BOX_H + n * ALT_H + 2
  end
  box:SetHeight(h)
  if box.SetBackdropBorderColor then
    if first then box:SetBackdropBorderColor(1, 0.82, 0, 1) else box:SetBackdropBorderColor(0.5, 0.5, 0.5, 0.8) end
  end
  return h
end

-- Draws the route for one profession. Returns a message for the window's centre text when there's
-- no route to show (not read yet is handled by the window).
function Route.Refresh(prof)
  Route.prof = prof
  local route = ns.Leveling.Route(prof)
  local boxes = 0
  if route and route.maxed then
    Route.title:SetText(string.format(L.MAXED, prof.name))
    Route.total:SetText("")
    Route.note:SetText("")
    Route.reset:Hide()
  elseif route then
    Route.title:SetText(string.format(L.TITLE, prof.name, route.from, route.to))
    if route.total < 0 then
      Route.total:SetText(string.format(L.TOTAL_PROFIT, Util.Money(-route.total)))
      UI.SetColor(Route.total, "good")
    else
      Route.total:SetText(string.format(L.TOTAL, Util.Money(route.total)))
      UI.SetColor(Route.total, "text")
    end
    Route.note:SetText("")
    Route.reset:SetShown(#ns.Leveling.Pins(prof) > 0)
    local y = -HEADER_H
    for i, step in ipairs(route.steps) do
      local box = Box(i)
      box:ClearAllPoints()
      box:SetPoint("TOPLEFT", Route.content, "TOPLEFT", 0, y)
      local h = DrawBox(box, step, i == 1)
      box:Show()
      y = y - h
      local link = Link(i)
      if i < #route.steps then
        link:ClearAllPoints()
        link:SetPoint("TOPLEFT", Route.content, "TOPLEFT", 25, y)
        link:Show()
        y = y - LINK_H
      else
        link:Hide()
      end
    end
    boxes = #route.steps
    Route.content:SetHeight(-y + 8)
  end
  for i = boxes + 1, #Route.boxes do
    Route.boxes[i]:Hide()
    Route.boxes[i].step = nil
    if Route.links[i] then Route.links[i]:Hide() end
  end
  return route
end

function Route.SetShown(on)
  Route.scroll:SetShown(on)
end
