-- Shift-click a recipe: search its materials at the auction house through Auctionator.
-- With the AH closed the search is queued and runs when you next open it.
local _, ns = ...
local Shopping = {}
ns.Shopping = Shopping

local Api = ns.Api

local L = {
  QUEUED = "Craft Margin: open the auction house to search for %s materials.",
  NO_MATS = "Craft Margin: %s has no materials to search for.",
  CANT_SEARCH = "Craft Margin: this Auctionator version can't search for other addons.",
  NEEDS_ADDON = "Craft Margin: AH search needs Auctionator or TSM.",
}

Shopping.EXPIRE = 600 -- a queued search is dropped after 10 minutes
local NAME_RETRIES = 6

local ahOpen = false
local pending -- { recipe = name, terms = {...}, at = time }

-- Pure: Auctionator search terms for one craft, every material included.
-- Returns terms, or nil plus the item IDs whose names aren't loaded yet.
function Shopping.Terms(r, nameOf)
  local terms, unloaded = {}, {}
  for _, m in ipairs(r.mats) do
    local name = nameOf(m.id)
    if name then
      terms[#terms + 1] = { searchString = name, isExact = true, quantity = m.n }
    else
      unloaded[#unloaded + 1] = m.id
    end
  end
  if #unloaded > 0 then return nil, unloaded end
  return terms
end

-- Pure: TSM search string for one craft, e.g. "i:2996/x3;i:2320/x3".
function Shopping.TSMString(r)
  local parts = {}
  for _, m in ipairs(r.mats) do parts[#parts + 1] = string.format("i:%d/x%d", m.id, m.n) end
  return table.concat(parts, ";")
end

local function run(terms)
  if not Api.AucSearch(terms) then print(L.CANT_SEARCH) end
end

function Shopping.Pending()
  if pending and Api.Now() - pending.at > Shopping.EXPIRE then pending = nil end
  return pending
end

function Shopping.Request(r, attempt)
  local name = r.recipe.name or "?"
  local source = ns.Prices.Source()
  if not source then return print(L.NEEDS_ADDON) end
  if #r.mats == 0 then return print(string.format(L.NO_MATS, name)) end
  if source.key == "tsm" then
    -- TSM can't be told to search, so hand the player a search string to paste.
    ns.Emit("TSM_SEARCH", name, Shopping.TSMString(r))
    return
  end
  local terms, unloaded = Shopping.Terms(r, function(id) return (Api.Item(id)) end)
  if not terms then
    attempt = attempt or 1
    if attempt > NAME_RETRIES then return end
    for _, id in ipairs(unloaded) do Api.RequestItem(id) end
    ns.After(0.5, function() Shopping.Request(r, attempt + 1) end)
    return
  end
  if ahOpen then
    pending = nil
    run(terms)
  else
    pending = { recipe = name, terms = terms, at = Api.Now() }
    print(string.format(L.QUEUED, name))
  end
  ns.Update()
end

ns.Listen("READY", function()
  ns.On("AUCTION_HOUSE_SHOW", function()
    ahOpen = true
    local p = Shopping.Pending()
    if not p then return end
    pending = nil
    ns.Update()
    -- Give Auctionator a moment to build its tabs.
    ns.After(0.5, function() if ahOpen then run(p.terms) end end)
  end)
  ns.On("AUCTION_HOUSE_CLOSED", function() ahOpen = false end)
end)
