-- Reads learned recipes from the open profession window and keeps them per character.
local _, ns = ...
local Recipes = {}
ns.Recipes = Recipes

local Api = ns.Api

local L = {
  READ = "Craft Margin: read %d %s recipes.",
}

-- Pure: turn the game's recipe info + schematic into a stored entry.
-- Returns entry, or nil and a reason ("unlearned", "other", "noItem").
function Recipes.Build(info, schematic, basicType)
  if not info or not info.learned then return nil, "unlearned" end
  if info.isRecraft or info.isSalvageRecipe or info.isGatheringRecipe then return nil, "other" end
  local out = schematic and schematic.outputItemID
  if not out or out == 0 then return nil, "noItem" end
  local mats = {}
  for _, slot in ipairs(schematic.reagentSlotSchematics or {}) do
    local basic = slot.reagentType == nil or basicType == nil or slot.reagentType == basicType
    if basic and slot.required ~= false then
      local r = slot.reagents and slot.reagents[1]
      if r and r.itemID then
        mats[#mats + 1] = { id = r.itemID, n = slot.quantityRequired or 1 }
      end
    end
  end
  local qmin = math.max(1, schematic.quantityMin or 1)
  local qmax = math.max(qmin, schematic.quantityMax or qmin)
  local entry = { id = info.recipeID, name = info.name, out = out, min = qmin, max = qmax, mats = mats }
  -- Difficulty: the game's own grey threshold, and its colour for the recipe right now.
  if info.maxTrivialLevel and info.maxTrivialLevel > 0 then entry.grey = info.maxTrivialLevel end
  entry.difficulty = ns.Difficulty.FromGame(info.relativeDifficulty or info.difficulty)
  return entry
end

function Recipes.Index()
  local prof = Api.OpenProfession()
  if not prof then return end
  local ids = Api.RecipeIDs()
  if not ids or #ids == 0 then return end

  local list, noItem = {}, 0
  local basic = Api.ReagentBasicType()
  for _, id in ipairs(ids) do
    local info = Api.RecipeInfo(id)
    if info then
      local entry, why = Recipes.Build(info, Api.Schematic(id), basic)
      if entry then
        entry.id = entry.id or id
        list[#list + 1] = entry
      elseif why == "noItem" then
        noItem = noItem + 1
      end
    end
  end
  if #list == 0 and noItem == 0 then return end -- data not ready yet

  -- The skill the game's colours were for: they're only trusted while it hasn't changed.
  local rank
  for _, p in ipairs(Api.Professions()) do
    if p.skillLine == prof.skillLine or p.name == prof.name then rank = p.rank end
  end
  local old = ns.char.profs[prof.skillLine]
  ns.char.profs[prof.skillLine] = {
    name = prof.name, readAt = Api.Now(), recipes = list, noItem = noItem, rank = rank,
  }
  if not old or #old.recipes ~= #list then
    print(string.format(L.READ, #list, prof.name))
  end
  ns.Update()
end

-- Stored entry for one of the character's professions (matched by skill line, then name).
function Recipes.For(prof)
  local profs = ns.char.profs
  if profs[prof.skillLine] then return profs[prof.skillLine] end
  for _, entry in pairs(profs) do
    if entry.name == prof.name then return entry end
  end
  return nil
end

local function schedule()
  ns.Debounce("index", 0.5, Recipes.Index)
end

ns.Listen("READY", function()
  ns.On("TRADE_SKILL_SHOW", schedule)
  ns.On("TRADE_SKILL_LIST_UPDATE", schedule)
  ns.On("TRADE_SKILL_DATA_SOURCE_CHANGED", schedule)
  ns.On("NEW_RECIPE_LEARNED", schedule)
  ns.On("SKILL_LINES_CHANGED", ns.Update)
end)
