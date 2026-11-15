-- Pure: profit for one recipe, and the lines of its profit tooltip.
local _, ns = ...
local Costing = {}
ns.Costing = Costing

local L = {
  SELLS = "Sells for",
  YIELD = "Yield",
  CUT = "AH cut (%d%%)",
  REVENUE = "Revenue",
  MATS = "Materials",
  PROFIT = "Profit",
  NO_PRICE = "no price",
  MISSING = "No price: %s",
}

-- sellFn(itemID) -> copper | nil; matFn(itemID) -> copper, source | nil
function Costing.Evaluate(recipe, sellFn, matFn, cut)
  local r = { recipe = recipe, mats = {}, missing = {}, cost = 0 }
  for _, m in ipairs(recipe.mats) do
    local unit, src = matFn(m.id)
    r.mats[#r.mats + 1] = { id = m.id, n = m.n, unit = unit, src = src }
    if unit then
      r.cost = r.cost + unit * m.n
    else
      r.missing[#r.missing + 1] = m.id
    end
  end
  r.yield = (recipe.min + recipe.max) / 2
  r.sell = sellFn(recipe.out)
  if r.sell then
    r.gross = math.floor(r.sell * r.yield + 0.5)
    r.cut = math.floor(r.gross * cut + 0.5)
    r.revenue = r.gross - r.cut
  else
    table.insert(r.missing, 1, recipe.out)
  end
  r.complete = #r.missing == 0
  if r.complete then
    r.profit = r.revenue - r.cost
    if r.cost > 0 then r.margin = r.profit / r.cost end
  end
  return r
end

-- { { left, right?, colourKind? }, ... }. nameOf(itemID) -> display name.
function Costing.TooltipLines(r, cut, nameOf, ageText)
  local U = ns.Util
  local lines = {}
  local function add(left, right, kind) lines[#lines + 1] = { left, right, kind } end

  if r.sell then
    add(L.SELLS, U.Money(r.sell) .. (ageText and (" (" .. ageText .. ")") or ""))
    if r.yield ~= 1 then add(L.YIELD, U.Yield(r.yield)) end
    add(string.format(L.CUT, math.floor(cut * 100 + 0.5)), "-" .. U.Money(r.cut))
    add(L.REVENUE, U.Money(r.revenue))
  else
    add(L.SELLS, L.NO_PRICE, "bad")
  end
  add(L.MATS, "-" .. U.Money(r.cost))
  if r.complete then
    local text = U.SignedMoney(r.profit)
    if r.margin then text = text .. " (" .. U.Percent(r.margin) .. ")" end
    add(L.PROFIT, text, r.profit >= 0 and "good" or "bad")
  end
  for _, id in ipairs(r.missing) do
    add(string.format(L.MISSING, nameOf(id)), nil, "bad")
  end
  return lines
end
