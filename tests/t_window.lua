-- Scenarios: drive the addon through the game's events and check what the player sees.

local function world(opts)
  opts = opts or {}
  if not opts.noAuc then InstallAuctionator(opts) end
  AddProfession("Tailoring", 197, 1)
  AddProfession("Herbalism", 182, 2)
  AddProfession("Cooking", 185, 5)
  Item(2589, "Linen Cloth")
  Item(2996, "Bolt of Linen Cloth")
  Item(2320, "Coarse Thread")
  Item(4238, "Linen Bag", opts.bagBind)
  AddRecipe(197, { id = 2963, name = "Bolt of Linen Cloth", out = 2996, mats = { { 2589, 2 } } })
  AddRecipe(197, { id = 3755, name = "Linen Bag", out = 4238, mats = { { 2996, 3 }, { 2320, 3 } } })
  AddRecipe(197, { id = 3914, name = "Brown Linen Pants", out = 4343, mats = { { 2996, 2 } }, learned = false })
  return Boot()
end

local function prices(age)
  SetPrice(2589, 50, age)   -- Linen Cloth
  SetPrice(2996, 150, age)  -- Bolt
  SetPrice(2320, 30, age)   -- Coarse Thread on the AH; vendors sell it for 10c
  SetPrice(4238, 1200, age) -- Linen Bag
end

local function names(w)
  local out = {}
  for _, r in ipairs(w.rows) do table.insert(out, r.name) end
  return table.concat(out, ",")
end

test("without Auctionator the header says so in red", function()
  world({ noAuc = true })
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(w.status, "Auctionator not installed")
  eq(w.statusColor, "bad")
  eq(#w.rows, 2, "recipes still listed")
  eq(w.rows[1].profit, "—")
end)

test("a profession not read yet says how to read it; gathering has no tab", function()
  world()
  Slash()
  local w = Window()
  eq(w.shown, true)
  eq(#w.tabs, 2)
  eq(w.tabs[1].name, "Tailoring")
  eq(w.tabs[1].on, true)
  eq(w.tabs[2].name, "Cooking")
  eq(w.empty, "Open your Tailoring window once to read your recipes.")
  eq(#w.rows, 0)
end)

test("opening a profession reads learned recipes and lists them by profit", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  ok(Printed("Craft Margin: read 2 Tailoring recipes."))
  Slash()
  local w = Window()
  eq(w.empty, nil)
  eq(names(w), "Linen Bag,Bolt of Linen Cloth")
  local bag, bolt = w.rows[1], w.rows[2]
  eq(bag.cost, "4s 80c", "3 bolts from the AH + 3 thread from a vendor")
  eq(bag.sells, "12s")
  eq(bag.profit, "+6s 60c")
  eq(bag.color, "good")
  eq(bolt.profit, "+42c")
  eq(w.status, "Prices: today")
  eq(w.statusColor, "muted")
  eq(w.footer, "2 recipes · read just now")
end)

test("an open window fills in when the profession is read", function()
  world()
  prices()
  Slash()
  eq(#Window().rows, 0)
  OpenProfession("Tailoring", 197)
  eq(#Window().rows, 2)
end)

test("losing money is red", function()
  world()
  prices()
  SetPrice(4238, 300)
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(names(w), "Bolt of Linen Cloth,Linen Bag")
  eq(w.rows[2].profit, "-1s 95c")
  eq(w.rows[2].color, "bad")
end)

test("no scan yet: red header, grey rows", function()
  world()
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(w.status, "No prices — scan with Auctionator")
  eq(w.statusColor, "bad")
  eq(w.rows[1].profit, "—")
  eq(w.rows[1].color, "muted")
end)

test("learning a recipe updates the list and announces it once", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Mock.printed = {}
  AddRecipe(197, { id = 3914, name = "Brown Linen Pants", out = 4343, mats = { { 2996, 2 } } })
  FireEvent("NEW_RECIPE_LEARNED", 3914)
  Advance(1)
  ok(Printed("Craft Margin: read 3 Tailoring recipes."))
  Mock.printed = {}
  OpenProfession("Tailoring", 197)
  eq(#Mock.printed, 0, "same count: nothing printed")
end)

test("a vendor discount lowers the cost", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  VisitVendor({ { id = 2320, price = 9 }, { id = 2589, price = 5000, available = 2 } })
  local w = Window()
  eq(w.rows[1].cost, "4s 77c")
  eq(NS.db.vendor.Alliance[2589], nil, "limited supply isn't recorded")
  VisitVendor({ { id = 2320, price = 10 } })
  eq(NS.db.vendor.Alliance[2320], 9, "cheapest price is kept")
end)

test("the AH wins when it's cheaper than the vendor", function()
  local ns = world()
  prices()
  SetPrice(2320, 4)
  eq(select(1, ns.Prices.Material(2320)), 4)
  eq(select(2, ns.Prices.Material(2320)), "ah")
  SetPrice(2320, nil)
  eq(select(2, ns.Prices.Material(2320)), "vendor")
end)

test("hovering the profit shows the money math", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  Enter(Window().rows[1].row.hit)
  local got = {}
  for _, l in ipairs(GameTooltip.lines) do table.insert(got, Strip(l[1]) .. (l[2] and (" = " .. Strip(l[2])) or "")) end
  eq(table.concat(got, "\n"), table.concat({
    "Linen Bag",
    "Auction house",
    "  Sells for = 12s (today)",
    "  AH cut (5%) = -60c",
    "  Profit = +6s 60c (138%) ✓",
    "Vendor = vendors won't buy it",
    "Materials = -4s 80c",
  }, "\n"))
end)

test("someone else's profession is never read", function()
  local ns = world()
  prices()
  OpenProfession("Tailoring", 197, true)
  eq(next(ns.char.profs), nil)
  ok(not Printed("read"))
end)

test("products that bind on pickup are left out", function()
  world({ bagBind = 1 })
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  eq(names(Window()), "Bolt of Linen Cloth")
  eq(Window().footer, "1 recipes · read just now")
end)

test("clicking a tab switches profession and is remembered", function()
  local ns = world()
  OpenProfession("Tailoring", 197)
  Slash()
  Click(ns.UI.Main.tabs[2])
  local w = Window()
  eq(w.tabs[2].on, true)
  eq(w.tabs[1].on, false)
  eq(w.empty, "Open your Cooking window once to read your recipes.")
  eq(ns.db.window.tab, 185)
end)

test("an Auctionator scan updates the header", function()
  local ns = world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  AucScanFinished()
  eq(Window().status, "Prices updated just now")
  Advance(2 * 3600)
  ns.Update()
  Advance(1)
  eq(Window().status, "Prices updated 2h ago")
  eq(Window().statusColor, "muted")
  Advance(23 * 3600)
  ns.Update()
  Advance(1)
  eq(Window().status, "Prices updated 1 day ago")
  eq(Window().statusColor, "warn")
end)

test("prices older than a day turn the header yellow", function()
  world()
  prices(2)
  OpenProfession("Tailoring", 197)
  Slash()
  eq(Window().status, "Prices: 2 days old")
  eq(Window().statusColor, "warn")
end)

test("an Auctionator without the age function still works", function()
  world({ noAge = true })
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  eq(Window().status, "Prices from Auctionator")
  eq(Window().rows[1].profit, "+6s 60c")
end)

test("secret values are ignored", function()
  world()
  prices()
  Mock.secret[1200] = true
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(names(w), "Bolt of Linen Cloth,Linen Bag")
  eq(w.rows[2].profit, "—")
end)

test("saved recipes show after a reload without opening the profession", function()
  CraftMarginCharDB = { profs = { [197] = { name = "Tailoring", readAt = Mock.clock - 3 * 86400, noItem = 0, recipes = {
    { id = 3755, name = "Linen Bag", out = 4238, min = 1, max = 1, mats = { { id = 2996, n = 3 } } },
  } } } }
  world()
  prices()
  Slash()
  local w = Window()
  eq(names(w), "Linen Bag")
  eq(w.footer, "1 recipes · read 3 days ago")
end)

test("no crafting professions", function()
  InstallAuctionator()
  AddProfession("Herbalism", 182, 1)
  Boot()
  Slash()
  eq(Window().empty, "You have no crafting professions.")
  eq(#Window().tabs, 0)
end)

test("slash toggles; Esc can close it", function()
  world()
  Slash()
  eq(Window().shown, true)
  Slash()
  eq(Window().shown, false)
  eq(UISpecialFrames[1], "CraftMarginFrame")
end)

test("debug command dumps state", function()
  world()
  OpenProfession("Tailoring", 197)
  Mock.printed = {}
  Slash("debug")
  ok(Printed("Tailoring (197): 2 recipes, 0 make no item, read just now"))
  ok(Printed("Cooking (185): not read yet"))
  ok(Printed("Herbalism (182) gathering: not read yet"))
  ok(Printed("GetAuctionPriceByItemID yes"))
  ok(Printed("built in"))
  ok(Printed("Errors: 0"))
end)

test("hovering a recipe name shows what it makes", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  Enter(Window().rows[1].row.nameHit)
  eq(GameTooltip.recipe, 3755)
  GameTooltip.SetRecipeResultItem = function() error("no recipe data") end
  Enter(Window().rows[1].row.nameHit)
  eq(GameTooltip.item, 4238, "falls back to the item tooltip")
end)

test("clicking a recipe name opens it in the profession window", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  Click(Window().rows[2].row.nameHit)
  eq(Mock.openedRecipe, 2963)
  ok(not Printed("can't open"))
  C_TradeSkillUI.OpenRecipe = nil
  Click(Window().rows[1].row.nameHit)
  ok(Printed("can't open a recipe from here"))
end)

test("the row stays highlighted while hovering its name or profit", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  local row = Window().rows[1].row
  for _, area in ipairs({ row.nameHit, row.costHit, row.hit }) do
    Enter(area)
    eq(row:IsLit(), true)
    Leave(area)
    eq(row:IsLit(), false)
  end
end)

test("vendor beats the AH: tag shown, sorted by vendor profit", function()
  world()
  prices()
  Item(2996, "Bolt of Linen Cloth", 0, 400) -- vendors pay 4s for a bolt, AH only 1s 50c
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(names(w), "Linen Bag,Bolt of Linen Cloth")
  local bolt = w.rows[2]
  eq(bolt.profit, "+3s")
  eq(bolt.sells, "4s")
  eq(bolt.row.tag:IsShown(), true)
  eq(w.rows[1].row.tag:IsShown(), false, "AH rows have no tag")
end)

test("no AH price but a vendor value: priced, not grey", function()
  world()
  prices()
  SetPrice(4238, nil)
  Item(4238, "Linen Bag", 0, 250)
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(names(w), "Bolt of Linen Cloth,Linen Bag")
  eq(w.rows[2].profit, "-2s 30c")
  eq(w.rows[2].color, "bad")
  eq(w.rows[2].row.tag:IsShown(), true)
end)

test("bind-on-pickup products with a vendor value are listed, vendor only", function()
  world({ bagBind = 1 })
  prices()
  Item(4238, "Linen Bag", 1, 900)
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(names(w), "Linen Bag,Bolt of Linen Cloth")
  eq(w.rows[1].profit, "+4s 20c", "AH price ignored: 9s - 4s 80c")
  eq(w.rows[1].row.tag:IsShown(), true)
  Enter(w.rows[1].row.hit)
  eq(Strip(GameTooltip.lines[2][2]), "binds when picked up")
end)

test("clicking anywhere on a row opens its recipe", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  local row = Window().rows[2].row
  for _, target in ipairs({ row, row.nameHit, row.costHit, row.hit }) do
    Mock.openedRecipe = nil
    Click(target)
    eq(Mock.openedRecipe, 2963)
  end
end)

test("hovering the cost shows the materials", function()
  world()
  prices()
  OpenProfession("Tailoring", 197)
  Slash()
  local row = Window().rows[1].row
  Enter(row.costHit)
  eq(row:IsLit(), true)
  local got = {}
  for _, l in ipairs(GameTooltip.lines) do table.insert(got, Strip(l[1]) .. (l[2] and (" = " .. Strip(l[2])) or "")) end
  eq(table.concat(got, "\n"), table.concat({
    "Linen Bag",
    "3 × Bolt of Linen Cloth = 4s 50c AH",
    "3 × Coarse Thread = 30c vendor",
    "Total = 4s 80c",
  }, "\n"))
  Leave(row.costHit)
  eq(row:IsLit(), false)
end)

test("each row shows its product's icon, a question mark until it loads", function()
  world()
  prices()
  Item(4238, "Linen Bag", 0, 0, 133639)
  OpenProfession("Tailoring", 197)
  Slash()
  local w = Window()
  eq(w.rows[1].row.icon:GetTexture(), 133639)
  eq(w.rows[2].row.icon:GetTexture(), 134400, "no icon yet")
end)
