local function recipe(mats, min, max)
  return { id = 1, name = "Linen Bag", out = 4238, min = min or 1, max = max or min or 1, mats = mats }
end

local function prices(t)
  return function(id) local p = t[id] if p then return p[1], p[2] end end
end

test("profit = sale x yield - 5% cut - materials", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({ { id = 2996, n = 3 }, { id = 2320, n = 3 } }),
    prices({ [4238] = { 10000 } }), prices({ [2996] = { 1000, "ah" }, [2320] = { 10, "vendor" } }), 0.05)
  eq(r.complete, true)
  eq(r.cost, 3030)
  eq(r.gross, 10000)
  eq(r.cut, 500)
  eq(r.revenue, 9500)
  eq(r.profit, 6470)
  ok(math.abs(r.margin - 6470 / 3030) < 1e-9)
end)

test("yield uses the average of min and max", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({ { id = 2996, n = 1 } }, 1, 2),
    prices({ [4238] = { 100 } }), prices({ [2996] = { 10 } }), 0.05)
  eq(r.yield, 1.5)
  eq(r.gross, 150)
  eq(r.cut, 8)
  eq(r.revenue, 142)
end)

test("missing material price makes the row incomplete", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({ { id = 2996, n = 1 }, { id = 9999, n = 1 } }),
    prices({ [4238] = { 100 } }), prices({ [2996] = { 10 } }), 0.05)
  eq(r.complete, false)
  eq(r.profit, nil)
  eq(#r.missing, 1)
  eq(r.missing[1], 9999)
end)

test("missing sale price makes the row incomplete, product listed first", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({ { id = 9999, n = 1 } }), prices({}), prices({}), 0.05)
  eq(r.complete, false)
  eq(r.missing[1], 4238)
  eq(r.missing[2], 9999)
end)

test("no materials at all: margin is left out", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({}), prices({ [4238] = { 100 } }), prices({}), 0.05)
  eq(r.complete, true)
  eq(r.margin, nil)
end)

test("tooltip lines", function()
  local ns = Boot()
  local C = ns.Costing
  local r = C.Evaluate(recipe({ { id = 2996, n = 3 } }, 1, 2),
    prices({ [4238] = { 10000 } }), prices({ [2996] = { 1000 } }), 0.05)
  local lines = C.TooltipLines(r, 0.05, function() return "?" end, "today")
  local got = {}
  for _, l in ipairs(lines) do table.insert(got, l[1] .. " | " .. (Strip(l[2]) or "") .. " | " .. (l[3] or "")) end
  eq(table.concat(got, "\n"), table.concat({
    "Sells for | 1g (today) | ",
    "Yield | ×1.5 | ",
    "AH cut (5%) | -7s 50c | ",
    "Revenue | 1g 42s | ",
    "Materials | -30s | ",
    "Profit | +1g 12s (375%) | good",
  }, "\n"))
end)

test("tooltip names what has no price", function()
  local C = Boot().Costing
  local r = C.Evaluate(recipe({ { id = 9999, n = 1 } }), prices({}), prices({}), 0.05)
  local names = { [4238] = "Linen Bag", [9999] = "Mystery Dust" }
  local lines = C.TooltipLines(r, 0.05, function(id) return names[id] end, nil)
  eq(lines[1][2], "no price")
  eq(lines[#lines - 1][1], "No price: Linen Bag")
  eq(lines[#lines][1], "No price: Mystery Dust")
  eq(lines[#lines][3], "bad")
end)
