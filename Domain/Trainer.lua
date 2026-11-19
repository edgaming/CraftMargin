-- Profession trainers: what each recipe needs and costs to learn, recorded when you open a trainer.
local _, ns = ...
local Trainer = {}
ns.Trainer = Trainer

local Api = ns.Api

-- ns.db.trainer[profession name][recipe name] = { skill = required skill, cost = copper }
function Trainer.Record()
  local changed = false
  for _, s in ipairs(Api.TrainerServices()) do
    ns.db.trainer[s.profession] = ns.db.trainer[s.profession] or {}
    local t = ns.db.trainer[s.profession]
    local old = t[s.name]
    if not old or old.skill ~= s.skill or old.cost ~= s.cost then
      t[s.name] = { skill = s.skill, cost = s.cost }
      changed = true
    end
  end
  if changed then ns.Update() end
end

-- What the trainer asks for this recipe, or nil if it isn't known (not a trainer recipe, or not visited).
function Trainer.For(professionName, recipeName)
  local t = ns.db.trainer[professionName]
  return t and t[recipeName]
end

function Trainer.Visited(professionName)
  return ns.db.trainer[professionName] ~= nil
end

ns.Listen("READY", function()
  ns.On("TRAINER_SHOW", Trainer.Record)
  ns.On("TRAINER_UPDATE", Trainer.Record)
end)
