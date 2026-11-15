-- Small UI helpers shared by the windows.
local _, ns = ...
local UI = {}
ns.UI = UI

function UI.Text(parent, font, justify)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  if justify then fs:SetJustifyH(justify) end
  return fs
end

function UI.SetColor(fs, kind)
  local c = ns.Util.RGB[kind] or ns.Util.RGB.text
  fs:SetTextColor(c[1], c[2], c[3])
end

-- lines: { { left, right?, colourKind? } }
function UI.Tooltip(owner, title, lines)
  local RGB = ns.Util.RGB
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(title, 1, 1, 1)
  for _, line in ipairs(lines) do
    local c = RGB[line[3] or "text"]
    if line[2] then
      GameTooltip:AddDoubleLine(line[1], line[2], 0.8, 0.8, 0.8, c[1], c[2], c[3])
    else
      GameTooltip:AddLine(line[1], c[1], c[2], c[3])
    end
  end
  GameTooltip:Show()
end
