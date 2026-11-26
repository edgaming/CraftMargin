-- The cogwheel in the main window's title bar: price source, and which recipe colours show.
local _, ns = ...
local Settings = {}
ns.UI.Settings = Settings

local UI = ns.UI

local L = {
  TITLE = "Price source",
  SHOW = "Show recipes",
  NOT_INSTALLED = "not installed",
}

local ROW_H = 22

function Settings.Create(parent)
  if Settings.button then return end

  local gear = CreateFrame("Button", nil, parent)
  gear:SetSize(16, 16)
  gear:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -28, -4)
  gear:SetNormalTexture("Interface\\Buttons\\UI-OptionsButton")
  gear:SetAlpha(0.6)
  gear:SetScript("OnEnter", function(self) self:SetAlpha(1) end)
  gear:SetScript("OnLeave", function(self) self:SetAlpha(0.6) end)
  gear:SetScript("OnClick", function() Settings.Toggle() end)
  Settings.button = gear

  local pop = CreateFrame("Frame", nil, parent, "BackdropTemplate")
  pop:SetPoint("TOPRIGHT", gear, "BOTTOMRIGHT", 6, -4)
  pop:SetFrameStrata("DIALOG")
  if pop.SetBackdrop then
    pop:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    pop:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  end
  pop:EnableMouse(true)
  pop:Hide()
  Settings.popup = pop

  local title = UI.Text(pop, "GameFontNormal", "LEFT")
  title:SetPoint("TOPLEFT", 12, -10)
  title:SetText(L.TITLE)

  Settings.rows = {}
  for i, source in ipairs(ns.Prices.SOURCES) do
    local radio = CreateFrame("CheckButton", nil, pop, "UIRadioButtonTemplate")
    radio:SetSize(16, 16)
    radio:SetPoint("TOPLEFT", 10, -10 - i * ROW_H)
    radio.key = source.key
    radio.label = UI.Text(pop, "GameFontHighlight", "LEFT")
    radio.label:SetPoint("LEFT", radio, "RIGHT", 6, 0)
    radio.label:SetText(source.name)
    radio.note = UI.Text(pop, "GameFontDisableSmall", "LEFT")
    radio.note:SetPoint("LEFT", radio.label, "RIGHT", 8, 0)
    radio.note:SetText(L.NOT_INSTALLED)
    UI.SetColor(radio.note, "muted")
    radio:SetScript("OnClick", function(self)
      ns.Prices.Choose(self.key)
      Settings.Refresh()
    end)
    Settings.rows[i] = radio
  end

  -- Which difficulty colours the list shows. All by default.
  local top = -10 - (#ns.Prices.SOURCES + 1) * ROW_H - 8
  local show = UI.Text(pop, "GameFontNormal", "LEFT")
  show:SetPoint("TOPLEFT", 12, top)
  show:SetText(L.SHOW)
  Settings.boxes = {}
  for i, d in ipairs(ns.Difficulty.ORDER) do
    local box = CreateFrame("CheckButton", nil, pop, "UICheckButtonTemplate")
    box:SetSize(22, 22)
    box:SetPoint("TOPLEFT", 7, top - i * ROW_H + 3)
    box.key = d
    box.label = UI.Text(pop, "GameFontHighlight", "LEFT")
    box.label:SetPoint("LEFT", box, "RIGHT", 3, 0)
    box.label:SetText(ns.Difficulty.NAMES[d])
    UI.SetColor(box.label, d)
    box:SetScript("OnClick", function(self)
      ns.db.hide[self.key] = (not self:GetChecked()) or nil
      ns.Update()
    end)
    Settings.boxes[i] = box
  end
  -- Room down to the bottom of the last checkbox (22 tall, 3 above its row), plus padding.
  pop:SetSize(250, -top + #ns.Difficulty.ORDER * ROW_H + 19 + 12)

  parent:HookScript("OnHide", function() pop:Hide() end)
end

function Settings.Refresh()
  local active = ns.Prices.Source()
  for i, radio in ipairs(Settings.rows) do
    local source = ns.Prices.SOURCES[i]
    local installed = source.available()
    radio:SetChecked(active ~= nil and active.key == source.key)
    if installed then radio:Enable() else radio:Disable() end
    UI.SetColor(radio.label, installed and "text" or "muted")
    radio.note:SetShown(not installed)
  end
  for _, box in ipairs(Settings.boxes) do box:SetChecked(not ns.db.hide[box.key]) end
end

function Settings.Toggle()
  local pop = Settings.popup
  if pop:IsShown() then
    pop:Hide()
  else
    Settings.Refresh()
    pop:Show()
  end
end
