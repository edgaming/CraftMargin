-- Records what you loot from herb and mining nodes, so nodes the bundled Classic data doesn't
-- cover (new Forever nodes, or rare drops it doesn't list) get real numbers from your own gathering.
--
-- When you start gathering, the game says which node you targeted (UNIT_SPELLCAST_SENT gives its
-- name); the loot window that follows is that node's loot.
local _, ns = ...
local Gathering = {}
ns.Gathering = Gathering

local Api = ns.Api

-- Herb Gathering and Mining, all ranks, plus their names as a fallback for client-specific IDs.
Gathering.SPELLS = { [2366] = true, [2368] = true, [3570] = true, [11993] = true,
  [2575] = true, [2576] = true, [3564] = true, [10248] = true }
Gathering.SPELL_NAMES = { ["Herb Gathering"] = true, ["Mining"] = true }
Gathering.WINDOW = 10 -- seconds between starting to gather and the loot window

local pending -- { name, at }

local function isGathering(spellID)
  if Gathering.SPELLS[spellID] then return true end
  local name = Api.SpellName(spellID)
  return name ~= nil and Gathering.SPELL_NAMES[name] == true
end

function Gathering.OnCast(unit, target, _, spellID)
  if unit ~= "player" or type(target) ~= "string" or target == "" then return end
  if ns.Util.IsSecret(target) or not isGathering(spellID) then return end
  pending = { name = target, at = Api.Now() }
end

-- Pure: add one loot to a node's record.
function Gathering.Add(record, itemIDs)
  record.n = (record.n or 0) + 1
  record.items = record.items or {}
  local seen = {}
  for _, id in ipairs(itemIDs) do
    if not seen[id] then
      seen[id] = true
      record.items[id] = (record.items[id] or 0) + 1
    end
  end
  return record
end

function Gathering.OnLoot()
  local p = pending
  if not p or Api.Now() - p.at > Gathering.WINDOW then return end
  pending = nil
  local items = Api.LootItems()
  if #items == 0 then return end
  ns.db.gathered[p.name] = Gathering.Add(ns.db.gathered[p.name] or {}, items)
end

function Gathering.Record(name)
  return ns.db.gathered and ns.db.gathered[name]
end

-- Pure: from a record, the main item (the one in most loots) and every other item with its
-- observed chance. Returns main, { { id, chance (%), count } }, total.
function Gathering.Summary(record)
  if not record or not record.n or record.n == 0 then return nil, {}, 0 end
  local main, mainCount
  for id, count in pairs(record.items) do
    if not mainCount or count > mainCount or (count == mainCount and id < main) then main, mainCount = id, count end
  end
  local rares = {}
  for id, count in pairs(record.items) do
    if id ~= main then rares[#rares + 1] = { id, 100 * count / record.n, count } end
  end
  return main, rares, record.n
end

ns.Listen("READY", function()
  ns.On("UNIT_SPELLCAST_SENT", Gathering.OnCast)
  ns.On("LOOT_READY", Gathering.OnLoot)
  ns.On("LOOT_OPENED", Gathering.OnLoot)
end)
