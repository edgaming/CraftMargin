local function recipe(mats, min, max)
  return { id = 1, name = "Linen Bag", out = 4238, min = min or 1, max = max or min or 1, mats = mats }
end

local function lookup(t)
  return function(id) local p = t[id] if type(p) == "table" then return p[1], p[2] end return p end
end

local function src(sell, mat, vendor, bound)
  return { sell = lookup(sell or {}), mat = lookup(mat or {}), vendor = lookup(vendor or {}), bound = bound }
end

local function eval(rec, s) return Boot().Costing.Evaluate(rec, s, 0.05) end

test("AH profit = sale x yield - 5% cut - materials", function()
  local r = eval(recipe({ { id = 2996, n = 3 }, { id = 2320, n = 3 } }),
    src({ [4238] = 10000 }, { [2996] = { 1000, "ah" }, [2320] = { 10, "vendor" } }))
  eq(r.complete, true)
  eq(r.best, "ah")
  eq(r.cost, 3030)
  eq(r.ah.gross, 10000)
  eq(r.ah.cut, 500)
  eq(r.ah.revenue, 9500)
  eq(r.profit, 6470)
  eq(r.gross, 10000)
  ok(math.abs(r.margin - 6470 / 3030) < 1e-9)
end)

test("yield uses the average of min and max, for both sides", function()
  local r = eval(recipe({ { id = 2996, n = 1 } }, 1, 2), src({ [4238] = 100 }, { [2996] = 10 }, { [4238] = 40 }))
  eq(r.yield, 1.5)
  eq(r.ah.gross, 150)
  eq(r.ah.cut, 8)
  eq(r.ah.revenue, 142)
  eq(r.vendor.gross, 60)
  eq(r.vendor.profit, 50)
end)

test("vendor wins when it pays more than the AH after the cut", function()
  local r = eval(recipe({ { id = 2996, n = 1 } }), src({ [4238] = 100 }, { [2996] = 10 }, { [4238] = 96 }))
  eq(r.best, "vendor")
  eq(r.profit, 86)
  eq(r.gross, 96)
  eq(r.ah.profit, 85)
end)

test("a tie goes to the AH", function()
  local r = eval(recipe({}), src({ [4238] = 100 }, {}, { [4238] = 95 }))
  eq(r.best, "ah")
end)

test("vendor value 0 means no vendor option", function()
  local r = eval(recipe({}), src({ [4238] = 100 }, {}, { [4238] = 0 }))
  eq(r.vendor, nil)
  eq(r.best, "ah")
end)

test("only a vendor value: priced by vendor", function()
  local r = eval(recipe({ { id = 2996, n = 1 } }), src({}, { [2996] = 10 }, { [4238] = 25 }))
  eq(r.complete, true)
  eq(r.best, "vendor")
  eq(r.profit, 15)
  eq(#r.missing, 0)
end)

test("bound products ignore the AH price", function()
  local r = eval(recipe({}), src({ [4238] = 1000 }, {}, { [4238] = 25 }, true))
  eq(r.ah, nil)
  eq(r.best, "vendor")
end)

test("neither price: incomplete, product listed first", function()
  local r = eval(recipe({ { id = 9999, n = 1 } }), src())
  eq(r.complete, false)
  eq(r.best, nil)
  eq(r.missing[1], 4238)
  eq(r.missing[2], 9999)
end)

test("missing material price makes the row incomplete either way", function()
  local r = eval(recipe({ { id = 2996, n = 1 }, { id = 9999, n = 1 } }),
    src({ [4238] = 100 }, { [2996] = 10 }, { [4238] = 50 }))
  eq(r.complete, false)
  eq(r.profit, nil)
  eq(r.matsKnown, false)
  eq(#r.missing, 1)
end)

test("no materials at all: margin is left out", function()
  local r = eval(recipe({}), src({ [4238] = 100 }))
  eq(r.complete, true)
  eq(r.margin, nil)
end)

local function render(lines)
  local got = {}
  for _, l in ipairs(lines) do table.insert(got, l[1] .. " | " .. (Strip(l[2]) or "") .. " | " .. (l[3] or "")) end
  return table.concat(got, "\n")
end

test("tooltip shows both sides and marks the better one", function()
  local ns = Boot()
  local r = ns.Costing.Evaluate(recipe({ { id = 2996, n = 3 } }, 1, 2),
    src({ [4238] = 10000 }, { [2996] = 1000 }, { [4238] = 1500 }), 0.05)
  eq(render(ns.Costing.TooltipLines(r, 0.05, function() return "?" end, "today")), table.concat({
    "Auction house |  | head",
    "  Sells for | 1g 50s (today) | ",
    "  AH cut (5%) | -7s 50c | ",
    "  Profit | +1g 12s (375%) ✓ | good",
    "Vendor |  | head",
    "  Sells for | 22s 50c | ",
    "  Profit | -7s 50c | bad",
    "Materials | -30s | ",
    "Yield | ×1.5 | ",
  }, "\n"))
end)

test("tooltip for a bound product and missing prices", function()
  local ns = Boot()
  local r = ns.Costing.Evaluate(recipe({ { id = 9999, n = 1 } }), src({}, {}, { [4238] = 0 }, true), 0.05)
  local names = { [4238] = "Linen Bag", [9999] = "Mystery Dust" }
  eq(render(ns.Costing.TooltipLines(r, 0.05, function(id) return names[id] end)), table.concat({
    "Auction house | binds when picked up | muted",
    "Vendor | vendors won't buy it | muted",
    "Materials | -0c | ",
    "No price: Linen Bag |  | bad",
    "No price: Mystery Dust |  | bad",
  }, "\n"))
end)

test("cost tooltip lists each material with its source, then the total", function()
  local ns = Boot()
  local r = ns.Costing.Evaluate(recipe({ { id = 2996, n = 3 }, { id = 2320, n = 3 }, { id = 9999, n = 1 } }),
    src({ [4238] = 1000 }, { [2996] = { 150, "ah" }, [2320] = { 10, "vendor" } }), 0.05)
  local names = { [2996] = "Bolt of Linen Cloth", [2320] = "Coarse Thread", [9999] = "Mystery Dust" }
  eq(render(ns.Costing.CostLines(r, function(id) return names[id] end)), table.concat({
    "3 × Bolt of Linen Cloth | 4s 50c AH | ",
    "3 × Coarse Thread | 30c vendor | ",
    "1 × Mystery Dust | no price | bad",
    "Total so far | 4s 80c | head",
  }, "\n"))
  r = ns.Costing.Evaluate(recipe({}), src({ [4238] = 1000 }), 0.05)
  eq(render(ns.Costing.CostLines(r, function() end)), "No materials |  | muted")
end)
