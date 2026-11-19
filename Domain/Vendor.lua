-- Vendor prices: the built-in table (Domain/VendorData.lua) plus prices seen at merchants.
local _, ns = ...
local Vendor = {}
ns.Vendor = Vendor

local Api = ns.Api

function Vendor.Builtin(itemID)
  return ns.VendorData and ns.VendorData[itemID]
end

function Vendor.Recorded(itemID)
  local t = ns.db and ns.db.vendor[Api.Faction()]
  return t and t[itemID]
end

-- Cheapest known vendor price for one item, or nil if no vendor sells it.
function Vendor.Price(itemID)
  local a, b = Vendor.Builtin(itemID), Vendor.Recorded(itemID)
  if a and b then return math.min(a, b) end
  return a or b
end

function Vendor.Record()
  local faction = Api.Faction()
  local t = ns.db.vendor[faction] or {}
  ns.db.vendor[faction] = t
  local changed = false
  for _, item in ipairs(Api.MerchantItems()) do
    if (item.unlimited or Vendor.IsPattern(item.id)) and (not t[item.id] or item.price < t[item.id]) then
      t[item.id] = item.price
      changed = true
    end
  end
  if changed then ns.Update() end
end

-- Recipe patterns (the items that teach a recipe) from the bundled recipe sources; vendors often
-- sell these in limited supply, so they're recorded even then.
local patterns
function Vendor.IsPattern(itemID)
  if not patterns then
    patterns = {}
    for _, data in pairs(ns.RecipeSources or {}) do
      if data.teach then patterns[data.teach] = true end
    end
  end
  return patterns[itemID] == true
end

function Vendor.Count()
  local n, r = 0, 0
  for _ in pairs(ns.VendorData or {}) do n = n + 1 end
  for _ in pairs((ns.db and ns.db.vendor[Api.Faction()]) or {}) do r = r + 1 end
  return n, r
end

ns.Listen("READY", function()
  ns.On("MERCHANT_SHOW", Vendor.Record)
  ns.On("MERCHANT_UPDATE", Vendor.Record)
end)
