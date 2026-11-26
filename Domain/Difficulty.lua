-- Recipe difficulty: the colour the game gives a recipe at your skill (orange, yellow, green,
-- grey), which says how likely a craft is to give a skill point.
local _, ns = ...
local Difficulty = {}
ns.Difficulty = Difficulty

-- Easiest last, the order the settings show them in.
Difficulty.ORDER = { "orange", "yellow", "green", "grey" }
Difficulty.NAMES = { orange = "Orange", yellow = "Yellow", green = "Green", grey = "Grey" }

-- The game's Enum.TradeskillRelativeDifficulty (and the older text names).
local FROM_GAME = {
  [0] = "orange", [1] = "yellow", [2] = "green", [3] = "grey",
  optimal = "orange", medium = "yellow", easy = "green", trivial = "grey",
}

function Difficulty.FromGame(v)
  if type(v) == "string" then v = v:lower() end
  return FROM_GAME[v]
end

-- Pure: colour at skill s for yellow/grey thresholds. Green starts halfway between them.
function Difficulty.At(s, yellow, grey)
  if s >= grey then return "grey" end
  if s >= math.floor((yellow + grey) / 2) then return "green" end
  if s >= yellow then return "yellow" end
  return "orange"
end

-- Thresholds for a recipe: the bundled yellow and grey, with the game's own grey winning.
function Difficulty.Thresholds(recipe)
  local t = ns.ThresholdData and ns.ThresholdData[recipe.id]
  if not t then return nil end
  local yellow, grey = t[1], t[2]
  if recipe.grey and recipe.grey ~= grey then
    grey = recipe.grey
    yellow = math.min(yellow, grey - 1)
  end
  return yellow, grey
end

-- Colour of a stored recipe at your current skill, or nil if unknown. The game's own colour
-- wins while your skill is what it was when the recipe was read; after that it's worked out
-- from the thresholds, so the list stays right as you skill up.
function Difficulty.Of(recipe, rank, readRank)
  if recipe.difficulty and rank and rank == readRank then return recipe.difficulty end
  local yellow, grey = Difficulty.Thresholds(recipe)
  if yellow and rank then return Difficulty.At(rank, yellow, grey) end
  return recipe.difficulty
end

function Difficulty.Shown(d)
  return d == nil or not (ns.db and ns.db.hide[d])
end

-- Names of the shown colours, or nil when all are shown.
function Difficulty.Filter()
  local shown, all = {}, true
  for _, d in ipairs(Difficulty.ORDER) do
    if Difficulty.Shown(d) then shown[#shown + 1] = Difficulty.NAMES[d]:lower() else all = false end
  end
  if all then return nil end
  return shown
end
