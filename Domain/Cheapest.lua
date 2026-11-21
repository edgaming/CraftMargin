-- The cheapest thing in your bags: the slot you'd lose least by throwing away.
local _, ns = ...
local Cheapest = {}
ns.Cheapest = Cheapest

local Api = ns.Api

local QUEST_CLASS = 12

-- Pure: worth of one bag slot, or nil if it shouldn't be suggested (worth unknown, quest item).
-- slot = { count, vendor (per item, may be 0), ah (per item or nil), bound, classID, noValue }
function Cheapest.Worth(slot, cut)
  if slot.classID == QUEST_CLASS then return nil end
  local ah = (not slot.bound and slot.ah) and math.floor(slot.ah * (1 - cut)) or nil
  local vendor = (not slot.noValue and slot.vendor and slot.vendor > 0) and slot.vendor or nil
  if not ah and not vendor then return nil end
  return (slot.count or 1) * math.max(ah or 0, vendor or 0)
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
    if vendor == nil then
      Api.RequestItem(s.itemID) -- not cached yet; it'll count next time
    else
      s.vendor, s.classID, s.ah = vendor, classID, ns.Prices.Sell(s.itemID)
      slots[#slots + 1] = s
    end
  end
  return Cheapest.Pick(slots, ns.AH_CUT)
end
