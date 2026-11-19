-- Namespace, constants and saved settings.
local addonName, ns = ...

_G[addonName] = ns -- the one global, for /dump debugging
ns.name = addonName

local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
ns.version = (getMeta and getMeta(addonName, "Version")) or "dev"

ns.AH_CUT = 0.05

-- Professions with no recipes worth listing: Herbalism, Skinning, Fishing.
ns.GATHERING = { [182] = true, [393] = true, [356] = true }

function ns.InitDB()
  CraftMarginDB = CraftMarginDB or {}
  local db = CraftMarginDB
  db.window = db.window or {}
  db.vendor = db.vendor or {} -- [faction][itemID] = cheapest copper seen at a vendor
  db.trainer = db.trainer or {} -- [profession][recipe name] = { skill, cost }

  CraftMarginCharDB = CraftMarginCharDB or {}
  local char = CraftMarginCharDB
  char.profs = char.profs or {} -- [skillLine] = { name, readAt, recipes, unlearned, noItem }
  char.pins = char.pins or {} -- [skillLine] = { { from, to, id } } recipes pinned in the levelling route

  ns.db, ns.char = db, char
end
