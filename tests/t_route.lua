-- Level up view: route boxes, shopping by step, alternatives and pins, trainer recipes.

local function world(opts)
  opts = opts or {}
  InstallAuctionator()
  AddProfession("Tailoring", 197, 1, opts.rank or 100)
  Item(2589, "Linen Cloth")
  Item(4305, "Bolt of Silk Cloth")
  Item(7001, "Linen Belt")
  Item(7002, "Heavy Linen Gloves")
  Item(7003, "Silk Headband")
  AddRecipe(197, { id = 9001, name = "Linen Belt", out = 7001, mats = { { 2589, 1 } } })
  AddRecipe(197, { id = 9002, name = "Heavy Linen Gloves", out = 7002, mats = { { 2589, 2 } }, grey = opts.liveGrey })
  AddRecipe(197, { id = 9003, name = "Silk Headband", out = 7003, mats = { { 4305, 1 } }, learned = false })
  Mock.sources = { [9003] = "Trainer" }
  local ns = Boot()
  ns.ThresholdData[9001] = { 120, 150 }
  ns.ThresholdData[9002] = { 140, 180 }
  ns.ThresholdData[9003] = { 200, 300 }
  ns.RecipeSources[9003] = opts.bundled ~= false and { 160, 1000, "t" } or nil
  SetPrice(2589, 50)
  SetPrice(4305, 300)
  OpenProfession("Tailoring", 197)
  if opts.trainer then
    VisitTrainer({ { name = "Silk Headband", profession = "Tailoring", skill = opts.trainer.skill, cost = opts.trainer.cost } })
  end
  Slash()
  Click(ns.UI.Main.modes[2])
  Advance(1)
  return ns
end

local function boxes()
  local out = {}
  for _, b in ipairs(NS.UI.Route.boxes) do
    if b:IsShown() then
      local s = b.step
      table.insert(out, s.gap and b.gapText:GetText() or (b.name:GetText() .. " " .. s.from .. "-" .. s.to))
    end
  end
  return out
end

test("the Level up view shows the route from your skill to 300", function()
  local ns = world()
  eq(ns.db.window.mode, "level")
  eq(ns.UI.Route.scroll:IsShown(), true)
  eq(ns.UI.Main.scroll:IsShown(), false, "profit list hidden")
  eq(ns.UI.Route.title:GetText(), "Tailoring 100 to 300")
  local b = boxes()
  eq(b[#b]:match("^Silk Headband") ~= nil, true, "trainer recipe used at the end: " .. table.concat(b, " | "))
  eq(ns.UI.Route.boxes[1].side:GetText(), "Learned")
  ok(Strip(ns.UI.Route.boxes[1].skill:GetText()):find("you are here$"), ns.UI.Route.boxes[1].skill:GetText())
  ok(Strip(ns.UI.Route.total:GetText()):find("^Costs about .+ after selling$"), ns.UI.Route.total:GetText())
  ok(Strip(ns.UI.Route.boxes[1].cost:GetText()):find("^Costs "), ns.UI.Route.boxes[1].cost:GetText())
  eq(ns.UI.Route.note:GetText(), "")
  eq(ns.UI.Main.hint:GetText(), "Click: open recipe  ·  Shift-click: search this step's materials at the AH")
end)

test("the chosen mode is remembered", function()
  local ns = world()
  Slash()
  Slash()
  eq(ns.UI.Route.scroll:IsShown(), true)
  Click(ns.UI.Main.modes[1])
  Advance(1)
  eq(ns.UI.Route.scroll:IsShown(), false)
  eq(ns.UI.Main.scroll:IsShown(), true)
end)

test("trainer recipes are included without visiting a trainer", function()
  local ns = world()
  local b = boxes()
  ok(b[#b]:match("^Silk Headband"), table.concat(b, " | "))
  eq(ns.UI.Route.note:GetText(), "")
end)

test("a recipe with no known source leaves a gap", function()
  world({ bundled = false })
  local b = boxes()
  eq(b[#b], "No priced recipe from 180 to 300")
end)

test("a vendor recipe is planned; its price shows once known", function()
  local ns = world({ bundled = false })
  Mock.areas = { [357] = "Feralas" }
  ns.RecipeSources[9003] = { 160, 0, "v", teach = 8003, vendors = { { 357, "" } } }
  ns.Update()
  Advance(1)
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(last.name:GetText(), "Silk Headband")
  eq(Strip(last.side:GetText()), "Not learned  ·  Vendor · price unknown")
  VisitVendor({ { id = 8003, price = 2500, available = 1 } })
  eq(Strip(last.side:GetText()), "Not learned  ·  Vendor · 25s", "limited-supply pattern recorded")
  Enter(last)
  local where
  for _, l in ipairs(GameTooltip.lines) do if l[1] == "  Where" then where = l[2] end end
  eq(where, "Feralas")
end)

test("a vendor for the other faction only isn't planned", function()
  local ns = world({ bundled = false })
  ns.RecipeSources[9003] = { 160, 0, "v", vendors = { { 357, "H" } } }
  ns.Update()
  Advance(1)
  local b = boxes()
  eq(b[#b], "No priced recipe from 180 to 300")
  Mock.printed = {}
  Slash("debug")
  ok(Printed("1 you can't get"))
end)

test("a tradeable drop is planned from the AH", function()
  local ns = world({ bundled = false })
  ns.RecipeSources[9003] = { 160, 0, "d", teach = 8003 }
  SetPrice(8003, 4000)
  ns.Update()
  Advance(1)
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(Strip(last.side:GetText()), "Not learned  ·  AH pattern · 40s")
end)

test("a quest reward is planned with its zone and level", function()
  local ns = world({ bundled = false })
  Mock.areas = { [33] = "Stranglethorn Vale" }
  ns.RecipeSources[9003] = { 160, 0, "q", quests = { { 123, 33, "", 38 }, { 124, 44, "H", 30 } } }
  ns.Update()
  Advance(1)
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(Strip(last.side:GetText()), "Not learned  ·  Quest reward")
  Enter(last)
  local got = {}
  for _, l in ipairs(GameTooltip.lines) do got[l[1]] = l[2] end
  eq(got["  Where"], "Stranglethorn Vale")
  eq(got["  Quest level"], "38")
end)

test("a recipe behind reputation you don't have isn't planned", function()
  local ns = world({ bundled = false })
  ns.RecipeSources[9003] = { 160, 1000, "t", rep = { { 2586, 5 } } }
  Mock.reps = { [2586] = 4 }
  ns.Update()
  Advance(1)
  local b = boxes()
  eq(b[#b], "No priced recipe from 180 to 300")
  Mock.reps = { [2586] = 5 }
  ns.Update()
  Advance(1)
  b = boxes()
  ok(b[#b]:match("^Silk Headband"))
end)

test("not-learned recipes stand out: red border and a red Not learned", function()
  local ns = world()
  local first, last = ns.UI.Route.boxes[1]
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(last.border, "bad")
  ok(last.side:GetText():find("|c" .. ns.Util.Hex("bad") .. "Not learned|r", 1, true), "red Not learned")
  eq(first.border, "head", "current learned step keeps the gold border")
  eq(first.side:GetText(), "Learned")
end)

test("the step tooltip is short and in plain words", function()
  local ns = world()
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  Enter(last)
  local got = {}
  for _, l in ipairs(GameTooltip.lines) do
    table.insert(got, Strip(l[1]) .. (l[2] and (" = " .. Strip(l[2])) or ""))
  end
  local text = table.concat(got, "\n")
  ok(text:find("^Silk Headband\nNot learned\n  Get it from = Trainer · 10s\n  Needs skill = 160\nEach craft\n"), text)
  ok(text:find("  Materials cost = 3s\n  Result sells for = nothing\nThis step\n  Crafts = about %d+\n  Costs = "), text)
  ok(text:find("  Including learning it = 10s"), text)
  ok(not text:find("[+]"), "no plus or minus signs on money")
end)

test("recipes with a cooldown are left out of routes", function()
  local ns = world()
  local entry = ns.Recipes.For({ skillLine = 197, name = "Tailoring" })
  entry.unlearned[1].cooldown = true
  ns.Update()
  Advance(1)
  local b = boxes()
  eq(b[#b], "No priced recipe from 180 to 300")
  Mock.printed = {}
  Slash("debug")
  ok(Printed("1 on a cooldown"))
end)

test("transmutes are detected as cooldown recipes when read", function()
  InstallAuctionator()
  AddProfession("Alchemy", 171, 1, 280)
  Item(12360, "Arcanite Bar")
  AddRecipe(171, { id = 17187, name = "Transmute: Arcanite", out = 12360, mats = {} })
  AddRecipe(171, { id = 3171, name = "Elixir of Wisdom", out = 3383, mats = {} })
  local ns = Boot()
  OpenProfession("Alchemy", 171)
  local entry = ns.Recipes.For({ skillLine = 171, name = "Alchemy" })
  local byName = {}
  for _, r in ipairs(entry.recipes) do byName[r.name] = r end
  eq(byName["Transmute: Arcanite"].cooldown, true)
  eq(byName["Elixir of Wisdom"].cooldown, nil)
end)

test("debug <recipe> prints every number behind it", function()
  world()
  Mock.printed = {}
  Slash("debug linen belt")
  ok(Printed("Linen Belt (9001) · learned"))
  ok(Printed("  1 x Linen Cloth at 50c (ah) = 50c"))
  ok(Printed("  Materials: 50c"))
  ok(Printed("  Thresholds: yellow 120, green 135, grey 150"))
  Mock.printed = {}
  Slash("debug silk")
  ok(Printed("Silk Headband (9003) · not learned"))
  ok(Printed("  Learn: Trainer · 10s, skill 160"))
end)

test("a trainer visit overrides the bundled fee and skill", function()
  local ns = world({ trainer = { skill = 170, cost = 900 } })
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(Strip(last.side:GetText()), "Not learned  ·  Trainer · 9s")
  ok(last.step.from >= 170, "not before the trainer's skill: " .. last.step.from)
end)

test("an unlearned step says where to learn it and its fee", function()
  local ns = world()
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(Strip(last.side:GetText()), "Not learned  ·  Trainer · 10s")
  Enter(last)
  local found = false
  for _, l in ipairs(GameTooltip.lines) do
    if l[1] == "  Get it from" then found = Strip(l[2]) == "Trainer · 10s" end
  end
  ok(found, "tooltip has the trainer line")
end)

test("shift-clicking a box shops for every craft in the step", function()
  local ns = world()
  OpenAuctionHouse()
  local first = ns.UI.Route.boxes[1]
  ShiftClick(first)
  local n = ns.Leveling.Crafts(first.step.crafts)
  eq(LastSearch(), "advanced: Linen Cloth x" .. (n * (first.step.cand.id == 9001 and 1 or 2)))
  eq(Mock.openedRecipe, nil)
end)

test("clicking a box opens its recipe and doesn't shop", function()
  local ns = world()
  OpenAuctionHouse()
  Click(ns.UI.Route.boxes[1])
  Advance(1)
  eq(Mock.openedRecipe, ns.UI.Route.boxes[1].step.cand.id)
  eq(#Mock.auc.searches, 0)
end)

test("alternatives open, and picking one pins it; reset undoes it", function()
  local ns = world()
  local first = ns.UI.Route.boxes[1]
  local chosen = first.step.cand.name
  eq(first.more.text:GetText(), "1 other recipe for this range")
  Click(first.more)
  local alt = first.alts[1]
  eq(alt:IsShown(), true)
  local altName = alt.name:GetText()
  ok(altName ~= chosen)
  ok(Strip(alt.delta:GetText()):match(" more$") or alt.delta:GetText() == "same", alt.delta:GetText())
  local from, to = first.step.from, first.step.to
  Click(alt)
  Advance(1)
  eq(ns.UI.Route.boxes[1].name:GetText(), altName)
  ok(ns.UI.Route.boxes[1].skill:GetText():find("pinned", 1, true))
  eq(ns.UI.Route.reset:IsShown(), true)
  eq(#ns.char.pins[197], 1)
  eq(ns.char.pins[197][1].from, from)
  eq(ns.char.pins[197][1].to, to)
  Click(ns.UI.Route.reset)
  Advance(1)
  eq(ns.UI.Route.boxes[1].name:GetText(), chosen)
  eq(ns.UI.Route.reset:IsShown(), false)
end)

test("levelling up moves the route along", function()
  local ns = world()
  SetSkill(197, 185)
  eq(ns.UI.Route.title:GetText(), "Tailoring 185 to 300")
  eq(boxes()[1], "Silk Headband 185-300")
end)

test("at 300 the profession is maxed", function()
  local ns = world({ rank = 300 })
  eq(ns.UI.Route.title:GetText(), "Tailoring is maxed.")
  eq(#boxes(), 0)
end)

test("the game's grey threshold wins over the bundled one, and debug lists it", function()
  local ns = world({ liveGrey = 170 })
  eq(ns.Leveling.Thresholds(ns.Recipes.For({ skillLine = 197, name = "Tailoring" }).recipes[2]), 140)
  local _, grey, mismatch = ns.Leveling.Thresholds(ns.Recipes.For({ skillLine = 197, name = "Tailoring" }).recipes[2])
  eq(grey, 170)
  eq(mismatch, true)
  Mock.printed = {}
  Slash("debug")
  ok(Printed("Grey mismatches: Heavy Linen Gloves (9002)"))
end)

test("unread profession in Level up says how to read it", function()
  InstallAuctionator()
  AddProfession("Tailoring", 197, 1, 50)
  local ns = Boot()
  Slash()
  Click(ns.UI.Main.modes[2])
  Advance(1)
  eq(Window().empty, "Open your Tailoring window once to read your recipes.")
  eq(ns.UI.Route.scroll:IsShown(), false)
end)
