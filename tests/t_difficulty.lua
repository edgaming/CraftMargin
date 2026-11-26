-- Recipe names coloured by difficulty, and the cogwheel filter for which colours show.

local function world(rank)
  InstallAuctionator()
  AddProfession("Tailoring", 197, 1, rank or 40)
  Item(2589, "Linen Cloth")
  Item(2996, "Bolt of Linen Cloth")
  Item(2320, "Coarse Thread")
  Item(4238, "Linen Bag")
  Item(9999, "Odd Cloak")
  -- the game's colours at skill 40: Bolt (25/50) yellow... per its own data; Bag (30/65) yellow
  AddRecipe(197, { id = 2963, name = "Bolt of Linen Cloth", out = 2996, mats = { { 2589, 2 } }, difficulty = 2 })
  AddRecipe(197, { id = 3755, name = "Linen Bag", out = 4238, mats = { { 2996, 3 }, { 2320, 3 } }, difficulty = 1 })
  AddRecipe(197, { id = 999001, name = "Odd Cloak", out = 9999, mats = { { 2589, 1 } } }) -- no colour known
  local ns = Boot()
  SetPrice(2589, 50); SetPrice(2996, 150); SetPrice(2320, 30); SetPrice(4238, 1200); SetPrice(9999, 500)
  OpenProfession("Tailoring", 197)
  Slash()
  return ns
end

local function colours(w)
  local out = {}
  for _, r in ipairs(w.rows) do out[r.name] = r.nameColor end
  return out
end

local function box(ns, d)
  for _, b in ipairs(ns.UI.Settings.boxes) do if b.key == d then return b end end
end

local function toggle(ns, d)
  Click(ns.UI.Settings.button)
  local b = box(ns, d)
  b:SetChecked(not b:GetChecked())
  Click(b)
  Advance(1)
end

test("colour from thresholds: orange below yellow, then yellow, green from halfway, grey", function()
  local D = Boot().Difficulty
  eq(D.At(29, 30, 65), "orange")
  eq(D.At(30, 30, 65), "yellow")
  eq(D.At(46, 30, 65), "yellow")
  eq(D.At(47, 30, 65), "green")
  eq(D.At(65, 30, 65), "grey")
  eq(D.FromGame(0), "orange")
  eq(D.FromGame(3), "grey")
  eq(D.FromGame("Medium"), "yellow")
end)

test("recipe names are coloured the way the game colours them", function()
  world()
  local c = colours(Window())
  eq(c["Bolt of Linen Cloth"], "green")
  eq(c["Linen Bag"], "yellow")
  eq(c["Odd Cloak"], "text", "no colour known: plain white")
end)

test("after a skill-up with the profession closed, colours follow your new skill", function()
  world()
  CloseProfession()
  SetSkill(197, 55)
  local c = colours(Window())
  eq(c["Bolt of Linen Cloth"], "grey", "25/50: grey at 55")
  eq(c["Linen Bag"], "green", "30/65: green from 47")
end)

test("the cogwheel has all four colours ticked by default", function()
  local ns = world()
  Click(ns.UI.Settings.button)
  for _, d in ipairs({ "orange", "yellow", "green", "grey" }) do
    eq(box(ns, d):GetChecked(), true, d)
    eq(ColorOf(box(ns, d).label), d)
  end
  ok(not Window().footer:find("showing"), "no filter note when all show")
end)

test("unticking a colour hides those recipes and the footer says what's showing", function()
  local ns = world()
  toggle(ns, "green")
  local w = Window()
  local c = colours(w)
  eq(c["Bolt of Linen Cloth"], nil, "green: hidden")
  eq(c["Linen Bag"], "yellow")
  eq(c["Odd Cloak"], "text", "unknown colour still shows")
  ok(w.footer:find("showing orange, yellow, grey", 1, true), w.footer)
  eq(ns.db.hide.green, true, "saved for every character")
  toggle(ns, "green")
  eq(#Window().rows, 3, "ticked again: back")
  eq(ns.db.hide.green, nil)
end)

test("orange only: a profession with no orange recipes says so", function()
  local ns = world()
  toggle(ns, "yellow"); toggle(ns, "green"); toggle(ns, "grey")
  local w = Window()
  eq(#w.rows, 1, "only the recipe with no known colour")
  for _, d in ipairs({ "orange" }) do ok(w.footer:find("showing " .. d, 1, true)) end
  ns.char.profs[197].recipes[3] = nil -- drop the unknown one
  NS.Update(); Advance(1)
  eq(Window().empty, "No orange recipes here. Pick which colours show with the cogwheel.")
end)

test("debug for one recipe shows its thresholds and colour", function()
  world()
  Mock.printed = {}
  Slash("debug linen bag")
  ok(Printed("Thresholds: yellow 30, green 47, grey 65 · game said yellow at skill 40 · now yellow at skill 40"))
end)

test("the cogwheel popup is tall enough for the last checkbox, with room below it", function()
  local ns = world()
  Click(ns.UI.Settings.button)
  local pop, lowest = ns.UI.Settings.popup, 0
  for _, b in ipairs(ns.UI.Settings.boxes) do
    local _, y = select(2, b:GetPoint()), select(3, b:GetPoint())
    lowest = math.max(lowest, -y + 22)
  end
  ok(pop:GetHeight() >= lowest + 8, string.format("popup %d tall, last box ends at %d", pop:GetHeight(), lowest))
end)
