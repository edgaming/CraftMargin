-- Thin layer over the game's API and Auctionator's. Everything else goes through here.
-- Secret values (Midnight) are turned into nil so nothing downstream compares them.
local _, ns = ...
local Api = {}
ns.Api = Api

Api.CALLER = "CraftMargin" -- Auctionator caller ID

local IsSecret = ns.Util.IsSecret
local function clean(v)
  if IsSecret(v) then return nil end
  return v
end

local function collect(...)
  local out = {}
  for i = 1, select("#", ...) do
    local v = select(i, ...)
    if v ~= nil then out[#out + 1] = v end
  end
  return out
end

function Api.Now()
  return time()
end

function Api.Faction()
  local f = UnitFactionGroup and UnitFactionGroup("player")
  return clean(f) or "Neutral"
end

---------------------------------------------------------------------------
-- Professions

-- The character's professions: { { name, skillLine }, ... }
function Api.Professions()
  local out = {}
  if not GetProfessions or not GetProfessionInfo then return out end
  for _, index in ipairs(collect(GetProfessions())) do
    local name, _, _, _, _, _, skillLine = GetProfessionInfo(index)
    name, skillLine = clean(name), clean(skillLine)
    if name and skillLine then out[#out + 1] = { name = name, skillLine = skillLine } end
  end
  return out
end

-- The profession window that's open right now, if it's the player's own.
function Api.OpenProfession()
  local T = C_TradeSkillUI
  if not T then return nil end
  if (T.IsTradeSkillLinked and T.IsTradeSkillLinked())
      or (T.IsTradeSkillGuild and T.IsTradeSkillGuild())
      or (T.IsNPCCrafting and T.IsNPCCrafting()) then
    return nil, "not yours"
  end
  local info = T.GetBaseProfessionInfo and T.GetBaseProfessionInfo()
  if (not info or not info.professionID or info.professionID == 0) and T.GetChildProfessionInfo then
    local child = T.GetChildProfessionInfo()
    if child then
      info = {
        professionID = child.parentProfessionID or child.professionID,
        professionName = child.parentProfessionName or child.professionName,
      }
    end
  end
  if not info or not clean(info.professionID) or info.professionID == 0 then return nil end
  return { skillLine = info.professionID, name = clean(info.professionName) or "?" }
end

function Api.RecipeIDs()
  local T = C_TradeSkillUI
  return T and T.GetAllRecipeIDs and T.GetAllRecipeIDs() or {}
end

function Api.RecipeInfo(recipeID)
  local T = C_TradeSkillUI
  return T and T.GetRecipeInfo and T.GetRecipeInfo(recipeID)
end

function Api.Schematic(recipeID)
  local T = C_TradeSkillUI
  return T and T.GetRecipeSchematic and T.GetRecipeSchematic(recipeID, false)
end

-- Tooltip for what a recipe makes. Falls back to the plain item tooltip.
function Api.RecipeTooltip(owner, recipeID, itemID)
  GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
  local shown = false
  if recipeID and GameTooltip.SetRecipeResultItem then
    shown = pcall(GameTooltip.SetRecipeResultItem, GameTooltip, recipeID)
  end
  if not shown and itemID and GameTooltip.SetItemByID then
    shown = pcall(GameTooltip.SetItemByID, GameTooltip, itemID)
  end
  GameTooltip:Show()
  return shown
end

-- Opens the profession window with this recipe selected.
function Api.OpenRecipe(recipeID)
  local T = C_TradeSkillUI
  if recipeID and T and T.OpenRecipe then
    return (pcall(T.OpenRecipe, recipeID))
  end
  return false
end

function Api.ReagentBasicType()
  return Enum and Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
end

---------------------------------------------------------------------------
-- Items

-- name, bindType (nil until the game has the item cached)
function Api.Item(itemID)
  local getInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not getInfo then return nil end
  local r = { getInfo(itemID) }
  return clean(r[1]), clean(r[14])
end

function Api.RequestItem(itemID)
  if C_Item and C_Item.RequestLoadItemDataByID then
    pcall(C_Item.RequestLoadItemDataByID, itemID)
  end
end

---------------------------------------------------------------------------
-- Merchant

-- Items in the open merchant window: { { id, price (copper per item), unlimited } }
function Api.MerchantItems()
  local out = {}
  local n = GetMerchantNumItems and GetMerchantNumItems() or 0
  for i = 1, n do
    local id = clean(GetMerchantItemID and GetMerchantItemID(i))
    local price, stack, available, extended
    if C_MerchantFrame and C_MerchantFrame.GetItemInfo then
      local info = C_MerchantFrame.GetItemInfo(i)
      if info then
        price, stack, available, extended = info.price, info.stackCount, info.numAvailable, info.hasExtendedCost
      end
    elseif GetMerchantItemInfo then
      local _, _, p, q, a, _, _, e = GetMerchantItemInfo(i)
      price, stack, available, extended = p, q, a, e
    end
    price, stack, available = clean(price), clean(stack), clean(available)
    if id and price and price > 0 and not extended then
      out[#out + 1] = {
        id = id,
        price = math.ceil(price / math.max(1, stack or 1)),
        unlimited = (available == nil or available < 0),
      }
    end
  end
  return out
end

---------------------------------------------------------------------------
-- Auctionator

local function auc()
  return Auctionator and Auctionator.API and Auctionator.API.v1
end

function Api.HasAuctionator()
  return auc() ~= nil
end

local function call(name, ...)
  local a = auc()
  local f = a and a[name]
  if not f then return nil end
  local ok, v = pcall(f, Api.CALLER, ...)
  if ok then return clean(v) end
  return nil
end

function Api.AucPrice(itemID) return call("GetAuctionPriceByItemID", itemID) end
function Api.AucAge(itemID) return call("GetAuctionAgeByItemID", itemID) end

function Api.AucOnUpdate(fn)
  local a = auc()
  if not (a and a.RegisterForDBUpdate) then return false end
  return (pcall(a.RegisterForDBUpdate, Api.CALLER, fn))
end

-- For /margin debug.
function Api.AucFunctions()
  local a, out = auc(), {}
  if not a then return out end
  for _, name in ipairs({ "GetAuctionPriceByItemID", "GetAuctionAgeByItemID", "RegisterForDBUpdate" }) do
    out[#out + 1] = name .. (a[name] and " yes" or " no")
  end
  return out
end
