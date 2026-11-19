-- Where prices come from: the chosen price addon (Auctionator or TSM) for AH prices,
-- the cheaper of AH and vendor for materials.
local _, ns = ...
local Prices = {}
ns.Prices = Prices

local Api, Util = ns.Api, ns.Util

local L = {
  NO_SOURCE = "No price addon — install Auctionator or TSM",
  NO_SCAN = "No prices — scan with Auctionator",
  NO_TSM = "No prices from TSM yet",
  UPDATED = "Prices updated %s",
  AGE = "Prices: %s",
  FROM_AUC = "Prices from Auctionator",
  FROM_TSM = "Prices from TSM",
}

-- Price addons, in default order.
Prices.SOURCES = {
  { key = "auctionator", name = "Auctionator", available = Api.HasAuctionator, price = Api.AucPrice },
  { key = "tsm", name = "TradeSkillMaster", available = Api.HasTSM, price = Api.TSMPrice },
}

-- The source in use: the saved choice if it's installed, otherwise the first installed one.
function Prices.Source()
  local chosen = ns.db and ns.db.source
  for _, s in ipairs(Prices.SOURCES) do
    if s.key == chosen and s.available() then return s end
  end
  for _, s in ipairs(Prices.SOURCES) do
    if s.available() then return s end
  end
  return nil
end

function Prices.Choose(key)
  ns.db.source = key
  ns.Update()
end

function Prices.Sell(itemID)
  local s = Prices.Source()
  return s and s.price(itemID)
end

-- Age in days of the AH price, when the source says (only Auctionator does).
function Prices.Age(itemID)
  local s = Prices.Source()
  if s and s.key == "auctionator" then return Api.AucAge(itemID) end
  return nil
end

-- What a vendor pays for one; 0 if vendors won't buy it, nil if the item isn't loaded yet.
function Prices.Vendor(itemID)
  local _, _, value = Api.Item(itemID)
  return value
end

-- copper, source ("vendor" or "ah"), or nil when nothing is known.
function Prices.Material(itemID)
  local ah, vendor = Prices.Sell(itemID), ns.Vendor.Price(itemID)
  if vendor and (not ah or vendor <= ah) then return vendor, "vendor" end
  if ah then return ah, "ah" end
  return nil
end

-- Profit for one recipe with current prices. Returns the result and whether the product can be
-- sold at all (false: binds on pickup and vendors won't buy it).
function Prices.Evaluate(recipe)
  local _, bind, value = Api.Item(recipe.out)
  if bind == nil then Api.RequestItem(recipe.out) end
  local bound = ns.Ranking.SellableBind(bind) == false
  local r = ns.Costing.Evaluate(recipe, {
    sell = Prices.Sell, mat = Prices.Material, vendor = Prices.Vendor, bound = bound,
  }, ns.AH_CUT)
  return r, not (bound and value == 0)
end

-- Header text and colour. hasAny: at least one listed product has a price.
-- newestDays: youngest Auctionator age among them (nil if not known).
function Prices.Status(hasAny, newestDays)
  local s = Prices.Source()
  if not s then return L.NO_SOURCE, "bad" end
  if s.key == "tsm" then
    if not hasAny then return L.NO_TSM, "bad" end
    return L.FROM_TSM, "muted"
  end
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
