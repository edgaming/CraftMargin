-- A small box holding a TSM search string, selected and ready for Ctrl+C.
local _, ns = ...
local CopyBox = {}
ns.UI.CopyBox = CopyBox

local UI = ns.UI

local L = {
  TITLE = "TSM search for %s",
  HELP = "Press Ctrl+C, then paste into TSM's Shopping search.",
}

function CopyBox.Create()
  if CopyBox.frame then return CopyBox.frame end
  local f = CreateFrame("Frame", "CraftMarginCopyBox", UIParent, "BackdropTemplate")
  CopyBox.frame = f
  f:SetSize(380, 96)
  f:SetPoint("CENTER", 0, 120)
  f:SetFrameStrata("DIALOG")
  if f.SetBackdrop then
    f:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      tile = true, tileSize = 16, edgeSize = 14,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.05, 0.05, 0.95)
  end
  f:EnableMouse(true)
  f:Hide()
  table.insert(UISpecialFrames, "CraftMarginCopyBox") -- Esc closes it

  f.title = UI.Text(f, "GameFontNormal", "LEFT")
  f.title:SetPoint("TOPLEFT", 14, -12)

  local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", 0, 0)

  local box = CreateFrame("EditBox", nil, f, "InputBoxTemplate")
  box:SetSize(340, 22)
  box:SetPoint("TOPLEFT", 20, -36)
  box:SetAutoFocus(false)
  -- Read-only: any typing puts the string back.
  box:SetScript("OnTextChanged", function(self, userInput)
    if userInput then
      self:SetText(f.value or "")
      self:HighlightText()
    end
  end)
  box:SetScript("OnEscapePressed", function() f:Hide() end)
  box:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
  f.box = box

  f.help = UI.Text(f, "GameFontDisableSmall", "LEFT")
  f.help:SetPoint("TOPLEFT", 14, -68)
  f.help:SetText(L.HELP)
  UI.SetColor(f.help, "muted")
  return f
end

function CopyBox.Show(recipeName, value)
  local f = CopyBox.Create()
  f.value = value
  f.title:SetText(string.format(L.TITLE, recipeName))
  f.box:SetText(value)
  f:Show()
  f.box:SetFocus()
  f.box:HighlightText()
end

ns.Listen("TSM_SEARCH", function(name, value) CopyBox.Show(name, value) end)
