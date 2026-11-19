-- Pure: the cheapest levelling route, by dynamic programming over skill points × recipes.
--
-- A candidate recipe:
--   { id, name, yellow, grey, req, fee, known, points, net }
--   req    skill needed to craft it (0 when known)
--   fee    one-time cost to learn it (0 when known)
--   points skill points one craft can give
--   net    copper per craft: materials minus what the result sells for (may be negative)
--
-- At each skill point s the planner keeps, for every recipe, the cheapest total cost of reaching
-- s + 1 while crafting that recipe at s. Moving onto a recipe from another one pays its fee (if
-- not known) and a small switching penalty, so the route doesn't flip between near-equal recipes.
-- The penalty steers the route; it's never part of the reported cost.
local _, ns = ...
local Planner = {}
ns.Planner = Planner

Planner.PENALTY_POINTS = 5 -- switching costs about this many points of crafting the new recipe
Planner.ALTERNATIVES = 2

local INF = math.huge

-- Chance that crafting at skill s gives a point: 100% below yellow, falling to 0 at grey.
function Planner.Chance(c, s)
  if s >= c.grey then return 0 end
  if s < c.yellow then return 1 end
  return (c.grey - s) / (c.grey - c.yellow)
end

local function available(c, s)
  return c.req <= s and Planner.Chance(c, s) > 0
end

-- Green starts halfway between yellow and grey.
function Planner.Green(c)
  return math.floor((c.yellow + c.grey) / 2)
end

local function isGreen(c, s)
  return s >= Planner.Green(c)
end

-- Expected copper per skill point, and expected crafts per point, at skill s.
function Planner.PerPoint(c, s)
  local ch = Planner.Chance(c, s) * (c.points or 1)
  if ch <= 0 then return nil end
  return c.net / ch, 1 / ch
end

local function penalty(step)
  return Planner.PENALTY_POINTS * math.max(math.abs(step), 1)
end

local function pinAt(pins, s)
  for _, p in ipairs(pins or {}) do
    if s >= p.from and s < p.to then return p end
  end
end

-- Cost of covering [from, to) with one recipe alone, or nil if it can't cover all of it.
local function cover(c, from, to)
  local cost, crafts = c.known and 0 or c.fee, 0
  for s = from, to - 1 do
    local per, n = Planner.PerPoint(c, s)
    if not per or c.req > s then return nil end
    cost, crafts = cost + per, crafts + n
  end
  return cost, crafts
end

-- Plan from skill `from` to skill `to`. pins: { { from, to, id } } forces a recipe over a range
-- (ignored at points where that recipe can't be crafted).
-- Returns { steps = { ... }, total = copper }. A step is
--   { cand, from, to, cost, crafts, chanceFrom, chanceTo, pinned, alternatives = { { cand, cost, crafts, delta } } }
-- or a gap { gap = true, from, to } where no candidate can be crafted.
function Planner.Plan(from, to, cands, pins)
  local back = {}
  local prev, prevMin, prevArg = nil, 0, 0 -- prevArg 0 = start (or just after a gap)

  for s = from, to - 1 do
    local pin = pinAt(pins, s)
    local pinIndex
    if pin then
      for i, c in ipairs(cands) do
        if c.id == pin.id and available(c, s) then pinIndex = i end
      end
    end

    -- Green recipes only when nothing orange or yellow can be crafted at this point.
    local greenOK = true
    if not pinIndex then
      for _, c in ipairs(cands) do
        if available(c, s) and not isGreen(c, s) then
          greenOK = false
          break
        end
      end
    end

    local cur, curMin, curArg = {}, INF, nil
    local b = {}
    for i, c in ipairs(cands) do
      if (not pinIndex or i == pinIndex) and available(c, s) and (greenOK or pinIndex or not isGreen(c, s)) then
        local step = Planner.PerPoint(c, s)
        local best, origin = INF, nil
        if prev and prev[i] then best, origin = prev[i], i end
        local switch = prevMin + (c.known and 0 or c.fee)
        if prevArg ~= 0 and prevArg ~= i then switch = switch + penalty(step) end
        if prevArg ~= i and switch < best then best, origin = switch, prevArg end
        cur[i] = best + step
        b[i] = origin
        if cur[i] < curMin then curMin, curArg = cur[i], i end
      end
    end

    if curArg then
      back[s] = b
      prev, prevMin, prevArg = cur, curMin, curArg
    else
      back[s] = { gap = true, prior = prevArg }
      prev, prevArg = nil, 0
    end
  end

  -- Walk back to find which recipe each point used (false = gap).
  local path, i = {}, prevArg
  for s = to - 1, from, -1 do
    local b = back[s]
    if b.gap then
      path[s] = false
      i = b.prior
    else
      path[s] = i
      i = b[i]
    end
  end

  -- Merge runs into steps.
  local steps, total = {}, 0
  local s = from
  while s < to do
    local idx = path[s]
    local e = s
    while e + 1 < to and path[e + 1] == idx do e = e + 1 end
    if idx == false then
      steps[#steps + 1] = { gap = true, from = s, to = e + 1 }
    else
      local c = cands[idx]
      local cost, crafts = cover(c, s, e + 1)
      local pin = pinAt(pins, s)
      local step = {
        cand = c, from = s, to = e + 1, cost = cost, crafts = crafts, green = isGreen(c, e),
        chanceFrom = Planner.Chance(c, s), chanceTo = Planner.Chance(c, e),
        pinned = pin ~= nil and pin.id == c.id,
        alternatives = {},
      }
      -- A recipe learned earlier in the route doesn't pay its fee again.
      for _, earlier in ipairs(steps) do
        if earlier.cand == c and not c.known then step.cost = step.cost - c.fee end
      end
      local alts = {}
      for j, other in ipairs(cands) do
        if j ~= idx then
          local altCost, altCrafts = cover(other, s, e + 1)
          if altCost then
            alts[#alts + 1] = { cand = other, cost = altCost, crafts = altCrafts, delta = altCost - step.cost }
          end
        end
      end
      table.sort(alts, function(a, b2)
        if a.cost ~= b2.cost then return a.cost < b2.cost end
        return (a.cand.name or "") < (b2.cand.name or "")
      end)
      for k = 1, math.min(Planner.ALTERNATIVES, #alts) do step.alternatives[k] = alts[k] end
      steps[#steps + 1] = step
      total = total + step.cost
    end
    s = e + 1
  end
  return { steps = steps, total = total }
end
