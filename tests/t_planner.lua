-- The levelling route planner, on plain candidate tables.

local function cand(t)
  t.req = t.req or 0
  t.fee = t.fee or 0
  t.known = t.known ~= false
  t.points = t.points or 1
  return t
end

local function names(plan)
  local out = {}
  for _, s in ipairs(plan.steps) do
    table.insert(out, s.gap and string.format("gap %d-%d", s.from, s.to)
      or string.format("%s %d-%d", s.cand.name, s.from, s.to))
  end
  return table.concat(out, ", ")
end

test("chance: 100% below yellow, falling to 0 at grey", function()
  local P = Boot().Planner
  local c = { yellow = 100, grey = 140 }
  eq(P.Chance(c, 50), 1)
  eq(P.Chance(c, 100), 1)
  eq(P.Chance(c, 120), 0.5)
  eq(P.Chance(c, 139), 1 / 40)
  eq(P.Chance(c, 140), 0)
end)

test("one recipe: crafts and cost add up over the range", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 120, { cand({ id = 1, name = "A", yellow = 100, grey = 140, net = 10 }) })
  eq(names(plan), "A 100-120")
  local s = plan.steps[1]
  local crafts = 0
  for x = 100, 119 do crafts = crafts + 40 / (140 - x) end
  ok(math.abs(s.crafts - crafts) < 1e-9)
  ok(math.abs(s.cost - crafts * 10) < 1e-6)
  eq(plan.total, s.cost)
end)

test("an older recipe that's still cheaper wins over the newest while it's yellow", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 120, {
    cand({ id = 1, name = "Old", yellow = 90, grey = 150, net = 10 }),
    cand({ id = 2, name = "New", yellow = 140, grey = 180, net = 40 }),
  })
  eq(names(plan), "Old 100-120")
end)

test("green only when nothing orange or yellow fits", function()
  local P = Boot().Planner
  -- Old turns green at 120; New is orange from 100 but much dearer.
  local plan = P.Plan(100, 130, {
    cand({ id = 1, name = "Old", yellow = 90, grey = 150, net = 1 }),
    cand({ id = 2, name = "New", yellow = 140, grey = 180, net = 400 }),
  })
  eq(names(plan), "Old 100-120, New 120-130")
  eq(plan.steps[1].green, false)
  -- With nothing else, green is used.
  plan = P.Plan(100, 130, { cand({ id = 1, name = "Old", yellow = 90, grey = 150, net = 1 }) })
  eq(names(plan), "Old 100-130")
  eq(plan.steps[1].green, true)
end)

test("switches once the cheap recipe gets too unlikely", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 150, {
    cand({ id = 1, name = "Old", yellow = 100, grey = 140, net = 10 }),
    cand({ id = 2, name = "New", yellow = 160, grey = 200, net = 30 }),
  })
  local s1, s2 = plan.steps[1], plan.steps[2]
  eq(s1.cand.name, "Old")
  eq(s2.cand.name, "New")
  eq(s1.to, s2.from)
  ok(s1.to > 110 and s1.to < 140, "switches part way: " .. s1.to)
  eq(s2.to, 150)
end)

test("no flip-flopping between near-equal recipes", function()
  local P = Boot().Planner
  local plan = P.Plan(1, 60, {
    cand({ id = 1, name = "A", yellow = 100, grey = 140, net = 100 }),
    cand({ id = 2, name = "B", yellow = 100, grey = 140, net = 99 }),
  })
  eq(#plan.steps, 1)
  eq(plan.steps[1].cand.name, "B")
end)

test("a training fee is paid only when it saves more than it costs", function()
  local P = Boot().Planner
  local known = cand({ id = 1, name = "Known", yellow = 200, grey = 250, net = 20 })
  local cheap = cand({ id = 2, name = "Trainer", yellow = 200, grey = 250, net = 10, known = false, fee = 150 })
  eq(names(P.Plan(100, 110, { known, cheap })), "Known 100-110", "saves 100, costs 150")
  eq(names(P.Plan(100, 130, { known, cheap })), "Trainer 100-130", "saves 300, costs 150")
  local plan = P.Plan(100, 130, { known, cheap })
  ok(math.abs(plan.total - (150 + 30 * 10)) < 1e-6, "fee counted in the total: " .. plan.total)
end)

test("a trainer recipe isn't used before its required skill", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 140, {
    cand({ id = 1, name = "Known", yellow = 100, grey = 200, net = 50 }),
    cand({ id = 2, name = "Later", yellow = 200, grey = 250, net = 1, known = false, fee = 0, req = 120 }),
  })
  eq(names(plan), "Known 100-120, Later 120-140")
end)

test("a range with nothing to craft becomes a gap and the route goes on", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 160, {
    cand({ id = 1, name = "A", yellow = 100, grey = 120, net = 5 }),
    cand({ id = 2, name = "B", yellow = 170, grey = 200, net = 5, req = 140 }),
  })
  eq(names(plan), "A 100-120, gap 120-140, B 140-160")
end)

test("a pinned recipe is used over its range even when dearer", function()
  local P = Boot().Planner
  local cands = {
    cand({ id = 1, name = "Cheap", yellow = 200, grey = 250, net = 5 }),
    cand({ id = 2, name = "Dear", yellow = 200, grey = 250, net = 20 }),
  }
  local plan = P.Plan(100, 140, cands, { { from = 110, to = 120, id = 2 } })
  eq(names(plan), "Cheap 100-110, Dear 110-120, Cheap 120-140")
  eq(plan.steps[2].pinned, true)
  eq(plan.steps[1].pinned, false)
end)

test("alternatives: the next two cheapest over the same range, with the difference", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 110, {
    cand({ id = 1, name = "Best", yellow = 200, grey = 250, net = 10 }),
    cand({ id = 2, name = "Second", yellow = 200, grey = 250, net = 12 }),
    cand({ id = 3, name = "Third", yellow = 200, grey = 250, net = 15 }),
    cand({ id = 4, name = "Fourth", yellow = 200, grey = 250, net = 30 }),
    cand({ id = 5, name = "Too late", yellow = 200, grey = 250, net = 1, req = 105, known = false, fee = 100000 }),
  })
  local alts = plan.steps[1].alternatives
  eq(#alts, 2)
  eq(alts[1].cand.name, "Second")
  eq(alts[1].delta, 20)
  eq(alts[2].cand.name, "Third")
  eq(alts[2].delta, 50)
end)

test("a recipe that makes money is preferred and the total goes negative", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 110, {
    cand({ id = 1, name = "Costs", yellow = 200, grey = 250, net = 10 }),
    cand({ id = 2, name = "Pays", yellow = 200, grey = 250, net = -5 }),
  })
  eq(names(plan), "Pays 100-110")
  eq(plan.total, -50)
end)

test("two points per craft halves the crafts", function()
  local P = Boot().Planner
  local plan = P.Plan(100, 110, { cand({ id = 1, name = "Double", yellow = 200, grey = 250, net = 10, points = 2 }) })
  eq(plan.steps[1].crafts, 5)
  eq(plan.total, 50)
end)
