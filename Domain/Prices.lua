-- Where prices come from: Auctionator for sale prices, cheapest of AH and vendor for materials.
local _, ns = ...
local Prices = {}
ns.Prices = Prices

local Api, Util = ns.Api, ns.Util

local L = {
  NO_AUC = "Auctionator not installed",
  NO_SCAN = "No prices — scan with Auctionator",
  UPDATED = "Prices updated %s",
  AGE = "Prices: %s",
  FROM_AUC = "Prices from Auctionator",
}

function Prices.Sell(itemID)
  return Api.AucPrice(itemID)
end

-- What a vendor pays for one; 0 if vendors won't buy it, nil if the item isn't loaded yet.
function Prices.Vendor(itemID)
  local _, _, value = Api.Item(itemID)
  return value
end

-- copper, source ("vendor" or "ah"), or nil when nothing is known.
function Prices.Material(itemID)
  local ah, vendor = Api.AucPrice(itemID), ns.Vendor.Price(itemID)
  if vendor and (not ah or vendor <= ah) then return vendor, "vendor" end
  if ah then return ah, "ah" end
  return nil
end

-- Header text and colour. hasAny: at least one listed product has a price.
-- newestDays: youngest Auctionator age among them (nil if Auctionator doesn't say).
function Prices.Status(hasAny, newestDays)
  if not Api.HasAuctionator() then return L.NO_AUC, "bad" end
  if not hasAny then return L.NO_SCAN, "bad" end
  local at = ns.db.priceUpdatedAt
  if at then
    local age = Api.Now() - at
    return string.format(L.UPDATED, Util.Ago(age)), age > 86400 and "warn" or "muted"
  end
  if newestDays == nil then return L.FROM_AUC, "muted" end
  return string.format(L.AGE, Util.DaysOld(newestDays)), newestDays >= 1 and "warn" or "muted"
end

ns.Listen("READY", function()
  Api.AucOnUpdate(function()
    ns.db.priceUpdatedAt = Api.Now()
    ns.Update()
  end)
end)
