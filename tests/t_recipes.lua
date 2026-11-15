local function slot(item, n, kind, required)
  return { reagents = { { itemID = item } }, quantityRequired = n, reagentType = kind or 1, required = required ~= false }
end

test("build keeps basic reagents and yield", function()
  local R = Boot().Recipes
  local e = R.Build({ recipeID = 5, name = "Bolt of Linen Cloth", learned = true },
    { outputItemID = 2996, quantityMin = 1, quantityMax = 2, reagentSlotSchematics = { slot(2589, 2) } }, 1)
  eq(e.out, 2996)
  eq(e.min, 1)
  eq(e.max, 2)
  eq(#e.mats, 1)
  eq(e.mats[1].id, 2589)
  eq(e.mats[1].n, 2)
end)

test("optional and non-basic slots are ignored", function()
  local R = Boot().Recipes
  local e = R.Build({ recipeID = 5, name = "X", learned = true }, {
    outputItemID = 1, reagentSlotSchematics = { slot(10, 1), slot(11, 1, 0), slot(12, 1, 1, false) },
  }, 1)
  eq(#e.mats, 1)
  eq(e.mats[1].id, 10)
end)

test("unlearned, enchants and recrafts are skipped with a reason", function()
  local R = Boot().Recipes
  local _, why = R.Build({ learned = false }, { outputItemID = 1 }, 1)
  eq(why, "unlearned")
  _, why = R.Build({ learned = true }, { outputItemID = 0 }, 1)
  eq(why, "noItem")
  _, why = R.Build({ learned = true }, { reagentSlotSchematics = {} }, 1)
  eq(why, "noItem")
  _, why = R.Build({ learned = true, isRecraft = true }, { outputItemID = 1 }, 1)
  eq(why, "other")
end)

test("quantity of zero or missing becomes 1", function()
  local R = Boot().Recipes
  local e = R.Build({ learned = true, name = "X" }, { outputItemID = 1, quantityMin = 0, quantityMax = 0 }, 1)
  eq(e.min, 1)
  eq(e.max, 1)
end)
