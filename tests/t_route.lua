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
  SetPrice(2589, 50)
  SetPrice(4305, 300)
  OpenProfession("Tailoring", 197)
  if opts.trainer ~= false then
    VisitTrainer({ { name = "Silk Headband", profession = "Tailoring", skill = 160, cost = 1000 } })
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
  eq(ns.UI.Route.title:GetText(), "Tailoring 100 → 300")
  local b = boxes()
  eq(b[#b]:match("^Silk Headband") ~= nil, true, "trainer recipe used at the end: " .. table.concat(b, " | "))
  eq(ns.UI.Route.boxes[1].side:GetText(), "You are here")
  ok(Strip(ns.UI.Route.total:GetText()):find("^About .+ after selling$"), ns.UI.Route.total:GetText())
  eq(ns.UI.Route.note:GetText(), "")
  eq(ns.UI.Main.hint:GetText(), "Click: shop for this step  ·  Shift-click: open recipe")
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

test("without a trainer visit: a note, and a gap where only the trainer recipe would do", function()
  local ns = world({ trainer = false })
  eq(ns.UI.Route.note:GetText(), "Visit your trainer to include recipes you haven't learned.")
  local b = boxes()
  eq(b[#b], "No priced recipe for 180–300")
  VisitTrainer({ { name = "Silk Headband", profession = "Tailoring", skill = 160, cost = 1000 } })
  b = boxes()
  ok(b[#b]:match("^Silk Headband"), "added after the visit")
  eq(ns.UI.Route.note:GetText(), "")
end)

test("an unlearned step says where to learn it and its fee", function()
  local ns = world()
  local last
  for _, bx in ipairs(ns.UI.Route.boxes) do if bx:IsShown() then last = bx end end
  eq(Strip(last.side:GetText()), "Learn: trainer · 10s")
  Enter(last)
  local found = false
  for _, l in ipairs(GameTooltip.lines) do
    if l[1] == "Learn" then found = Strip(l[2]) == "trainer · 10s (skill 160)" end
  end
  ok(found, "tooltip has the trainer line")
end)

test("clicking a box shops for every craft in the step", function()
  local ns = world()
  OpenAuctionHouse()
  local first = ns.UI.Route.boxes[1]
  Click(first)
  Advance(1)
  local n = ns.Leveling.Crafts(first.step.crafts)
  eq(LastSearch(), "advanced: Linen Cloth x" .. (n * (first.step.cand.id == 9001 and 1 or 2)))
  eq(Mock.openedRecipe, nil)
end)

test("shift-clicking a box opens its recipe", function()
  local ns = world()
  ShiftClick(ns.UI.Route.boxes[1])
  eq(Mock.openedRecipe, ns.UI.Route.boxes[1].step.cand.id)
end)

test("alternatives open, and picking one pins it; reset undoes it", function()
  local ns = world()
  local first = ns.UI.Route.boxes[1]
  local chosen = first.step.cand.name
  eq(Strip(first.more.text:GetText()):match("alternative") ~= nil, true)
  Click(first.more)
  local alt = first.alts[1]
  eq(alt:IsShown(), true)
  local altName = alt.name:GetText()
  ok(altName ~= chosen)
  ok(Strip(alt.delta:GetText()):match("^%+") or alt.delta:GetText() == "same", alt.delta:GetText())
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
  eq(ns.UI.Route.title:GetText(), "Tailoring 185 → 300")
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
