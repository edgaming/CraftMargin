-- Pure: the rows of one profession tab, best profit first.
local _, ns = ...
local Ranking = {}
ns.Ranking = Ranking

-- isSellable(itemID) -> true, false (binds on pickup) or nil (not known yet; kept).
-- Returns rows, number of recipes skipped because their product can't be sold.
function Ranking.Build(recipes, evaluate, isSellable)
  local rows, bound = {}, 0
  for _, rec in ipairs(recipes) do
    if isSellable(rec.out) == false then
      bound = bound + 1
    else
      rows[#rows + 1] = evaluate(rec)
    end
  end
  table.sort(rows, function(a, b)
    if a.complete ~= b.complete then return a.complete end
    if a.complete and a.profit ~= b.profit then return a.profit > b.profit end
    return (a.recipe.name or "") < (b.recipe.name or "")
  end)
  return rows, bound
end

-- Bind types that can't go on the auction house: on pickup (1), quest (4).
function Ranking.SellableBind(bindType)
  if bindType == nil then return nil end
  return bindType ~= 1 and bindType ~= 4
end
