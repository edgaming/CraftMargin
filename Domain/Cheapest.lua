-- The cheapest thing in your bags: the slot you'd lose least by throwing away.
local _, ns = ...
local Cheapest = {}
ns.Cheapest = Cheapest

local Api = ns.Api

local QUEST_CLASS = 12

-- Pure: worth of one bag slot, or nil if it shouldn't be suggested. Only things a vendor buys
-- are suggested (no sell price usually means quest, soulbound or otherwise special); quest
-- items never are. The AH price can make something worth more, never eligible.
-- slot = { count, vendor (per item, may be 0), ah (per item or nil), bound, classID, noValue }
function Cheapest.Worth(slot, cut)
  if slot.classID == QUEST_CLASS or slot.noValue then return nil end
  if not slot.vendor or slot.vendor <= 0 then return nil end
  local ah = (not slot.bound and slot.ah) and math.floor(slot.ah * (1 - cut)) or 0
  return (slot.count or 1) * math.max(ah, slot.vendor)
end

-- Pure: the cheapest of a list of slots ({ bag, slot, ... }), first one on a tie.
function Cheapest.Pick(slots, cut)
  local best, bestWorth
  for _, s in ipairs(slots) do
    local w = Cheapest.Worth(s, cut)
    if w and (not bestWorth or w < bestWorth) then best, bestWorth = s, w end
  end
  if best then best.worth = bestWorth end
  return best
end

-- The cheapest slot in your bags right now, with prices from the chosen price addon.
function Cheapest.Find()
  local slots = {}
  for _, s in ipairs(Api.BagItems()) do
    local _, _, vendor, classID = Api.Item(s.itemID)
    if ns.db.keep[s.itemID] then
      -- kept: never suggested
    elseif vendor == nil then
      Api.RequestItem(s.itemID) -- not cached yet; it'll count next time
    else
      s.vendor, s.classID, s.ah = vendor, classID, ns.Prices.Sell(s.itemID)
      slots[#slots + 1] = s
    end
  end
  return Cheapest.Pick(slots, ns.AH_CUT)
end
