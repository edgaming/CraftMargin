local function fake(name, profit)
  return { recipe = { name = name, out = name }, complete = profit ~= nil, profit = profit }
end

test("best profit first, unpriced rows last by name", function()
  local R = Boot().Ranking
  local data = { A = fake("A", 100), B = fake("B", -50), C = fake("C"), D = fake("D", 900), E = fake("Bz") }
  local recipes = {}
  for _, k in ipairs({ "A", "B", "C", "D", "E" }) do table.insert(recipes, { out = k }) end
  local rows = R.Build(recipes, function(rec) return data[rec.out] end, function() return true end)
  local names = {}
  for _, r in ipairs(rows) do table.insert(names, r.recipe.name) end
  eq(table.concat(names, ","), "D,A,B,Bz,C")
end)

test("bind-on-pickup products are skipped and counted; unknown bind is kept", function()
  local R = Boot().Ranking
  local recipes = { { out = 1 }, { out = 2 }, { out = 3 } }
  local sell = { [1] = true, [2] = false, [3] = nil }
  local rows, bound = R.Build(recipes, function(rec) return fake(tostring(rec.out), 1) end,
    function(id) return sell[id] end)
  eq(#rows, 2)
  eq(bound, 1)
end)

test("bind types", function()
  local R = Boot().Ranking
  eq(R.SellableBind(0), true)
  eq(R.SellableBind(2), true)
  eq(R.SellableBind(1), false)
  eq(R.SellableBind(4), false)
  eq(R.SellableBind(nil), nil)
end)
