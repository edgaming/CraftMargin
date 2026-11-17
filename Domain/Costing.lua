-- Pure: profit for one recipe, both ways of selling, and the lines of its profit tooltip.
local _, ns = ...
local Costing = {}
ns.Costing = Costing

local L = {
  AH = "Auction house",
  VENDOR = "Vendor",
  SELLS = "  Sells for",
  CUT = "  AH cut (%d%%)",
  PROFIT = "  Profit",
  NO_PRICE = "no price",
  BOUND = "binds when picked up",
  NO_VENDOR = "vendors won't buy it",
  MATS = "Materials",
  YIELD = "Yield",
  MISSING = "No price: %s",
  BEST = " |TInterface\\RaidFrame\\ReadyCheck-Ready:0|t",
}

-- src = {
--   sell(itemID)   -> AH price | nil
--   vendor(itemID) -> vendor sell value | nil (0 = vendors won't buy it)
--   mat(itemID)    -> copper, source | nil
--   bound          -> true if the product can't go on the AH
-- }
function Costing.Evaluate(recipe, src, cut)
  local r = { recipe = recipe, mats = {}, missing = {}, cost = 0, bound = src.bound }
  for _, m in ipairs(recipe.mats) do
    local unit, from = src.mat(m.id)
    r.mats[#r.mats + 1] = { id = m.id, n = m.n, unit = unit, src = from }
    if unit then
      r.cost = r.cost + unit * m.n
    else
      r.missing[#r.missing + 1] = m.id
    end
  end
  local matsKnown = #r.missing == 0
  r.matsKnown = matsKnown
  r.yield = (recipe.min + recipe.max) / 2

  local sell = not src.bound and src.sell(recipe.out) or nil
  if sell then
    local gross = math.floor(sell * r.yield + 0.5)
    local fee = math.floor(gross * cut + 0.5)
    r.ah = { unit = sell, gross = gross, cut = fee, revenue = gross - fee }
    if matsKnown then r.ah.profit = r.ah.revenue - r.cost end
  end
  r.vendorValue = src.vendor(recipe.out)
  if r.vendorValue and r.vendorValue > 0 then
    local gross = math.floor(r.vendorValue * r.yield + 0.5)
    r.vendor = { unit = r.vendorValue, gross = gross, revenue = gross }
    if matsKnown then r.vendor.profit = gross - r.cost end
  end
  if not r.ah and not r.vendor then table.insert(r.missing, 1, recipe.out) end

  -- The better way of selling; the AH wins a tie.
  local best
  if r.ah and r.vendor then
    best = (r.vendor.revenue > r.ah.revenue) and "vendor" or "ah"
  else
    best = (r.ah and "ah") or (r.vendor and "vendor") or nil
  end
  r.best = best
  r.sell = r.ah and r.ah.unit -- AH unit price, for the header's age
  if best then r.gross = r[best].gross end
  r.complete = matsKnown and best ~= nil
  if r.complete then
    r.profit = r[best].profit
    if r.cost > 0 then r.margin = r.profit / r.cost end
  end
  return r
end

-- { { left, right?, colourKind? }, ... }. nameOf(itemID) -> display name.
function Costing.TooltipLines(r, cut, nameOf, ageText)
  local U = ns.Util
  local lines = {}
  local function add(left, right, kind) lines[#lines + 1] = { left, right, kind } end
  local function profitLine(side)
    if side.profit == nil then return end
    local text = U.SignedMoney(side.profit)
    if r.best and r[r.best] == side then
      if r.cost > 0 then text = text .. " (" .. U.Percent(side.profit / r.cost) .. ")" end
      text = text .. L.BEST
    end
    add(L.PROFIT, text, side.profit >= 0 and "good" or "bad")
  end

  if r.bound then
    add(L.AH, L.BOUND, "muted")
  elseif r.ah then
    add(L.AH, nil, "head")
    add(L.SELLS, U.Money(r.ah.gross) .. (ageText and (" (" .. ageText .. ")") or ""))
    add(string.format(L.CUT, math.floor(cut * 100 + 0.5)), "-" .. U.Money(r.ah.cut))
    profitLine(r.ah)
  else
    add(L.AH, L.NO_PRICE, "bad")
  end

  if r.vendor then
    add(L.VENDOR, nil, "head")
    add(L.SELLS, U.Money(r.vendor.gross))
    profitLine(r.vendor)
  elseif r.vendorValue == 0 then
    add(L.VENDOR, L.NO_VENDOR, "muted")
  end

  add(L.MATS, "-" .. U.Money(r.cost))
  if r.yield ~= 1 then add(L.YIELD, U.Yield(r.yield)) end
  for _, id in ipairs(r.missing) do
    add(string.format(L.MISSING, nameOf(id)), nil, "bad")
  end
  return lines
end
