local function fake(name, profit)
  return { recipe = { name = name, out = name }, complete = profit ~= nil, profit = profit }
end

test("best profit first, unpriced rows last by name", function()
  local R = Boot().Ranking
  local data = { A = fake("A", 100), B = fake("B", -50), C = fake("C"), D = fake("D", 900), E = fake("Bz") }
  local recipes = {}
  for _, k in ipairs({ "A", "B", "C", "D", "E" }) do table.insert(recipes, { out = k }) end
  local rows = R.Build(recipes, function(rec) return data[rec.out] end)
  local names = {}
  for _, r in ipairs(rows) do table.insert(names, r.recipe.name) end
  eq(table.concat(names, ","), "D,A,B,Bz,C")
end)

test("recipes the evaluator rejects are skipped and counted", function()
  local R = Boot().Ranking
  local recipes = { { out = 1 }, { out = 2 }, { out = 3 } }
  local rows, skipped = R.Build(recipes, function(rec)
    if rec.out == 2 then return nil end
    return fake(tostring(rec.out), 1)
  end)
  eq(#rows, 2)
  eq(skipped, 1)
end)

test("bind types", function()
  local R = Boot().Ranking
  eq(R.SellableBind(0), true)
  eq(R.SellableBind(2), true)
  eq(R.SellableBind(1), false)
  eq(R.SellableBind(4), false)
  eq(R.SellableBind(nil), nil)
end)
