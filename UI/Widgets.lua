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
-- "total" = gold label, white amount; any other kind colours the right side (or a lone left).
function UI.Tooltip(owner, title, lines)
  local RGB = ns.Util.RGB
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  GameTooltip:AddLine(title, 1, 1, 1)
  for _, line in ipairs(lines) do
    local kind = line[3] or "text"
    if kind == "total" then
      local h, t = RGB.head, RGB.text
      GameTooltip:AddDoubleLine(line[1], line[2], h[1], h[2], h[3], t[1], t[2], t[3])
    elseif line[2] then
      local c = RGB[kind]
      GameTooltip:AddDoubleLine(line[1], line[2], 0.8, 0.8, 0.8, c[1], c[2], c[3])
    else
      local c = RGB[kind]
      GameTooltip:AddLine(line[1], c[1], c[2], c[3])
    end
  end
  GameTooltip:Show()
end
