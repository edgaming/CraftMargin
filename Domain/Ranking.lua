-- Pure: the rows of one profession tab, best profit first.
local _, ns = ...
local Ranking = {}
ns.Ranking = Ranking

-- evaluate(recipe) -> row, or nil when the product can't be sold anywhere.
-- Returns rows, number of recipes skipped.
function Ranking.Build(recipes, evaluate)
  local rows, skipped = {}, 0
  for _, rec in ipairs(recipes) do
    local row = evaluate(rec)
    if row then rows[#rows + 1] = row else skipped = skipped + 1 end
  end
  table.sort(rows, function(a, b)
    if a.complete ~= b.complete then return a.complete end
    if a.complete and a.profit ~= b.profit then return a.profit > b.profit end
    return (a.recipe.name or "") < (b.recipe.name or "")
  end)
  return rows, skipped
end

-- Bind types that can't go on the auction house: on pickup (1), quest (4).
function Ranking.SellableBind(bindType)
  if bindType == nil then return nil end
  return bindType ~= 1 and bindType ~= 4
end
