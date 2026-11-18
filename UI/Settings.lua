-- The cogwheel in the main window's title bar and its price source popup.
local _, ns = ...
local Settings = {}
ns.UI.Settings = Settings

local UI = ns.UI

local L = {
  TITLE = "Price source",
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
  pop:SetSize(250, 24 + #ns.Prices.SOURCES * ROW_H + 8)

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
