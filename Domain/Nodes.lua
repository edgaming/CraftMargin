-- Herb and mining nodes: from the names in the minimap's tooltip to the item they give.
local _, ns = ...
local Nodes = {}
ns.Nodes = Nodes

local Api = ns.Api

-- Pure: the node names in a minimap tooltip text (one per line, with colour codes and icons removed).
function Nodes.Parse(text)
  local out = {}
  if type(text) ~= "string" then return out end
  for line in (text .. "\n"):gmatch("(.-)\n") do
    line = line:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""):gsub("|A.-|a", "")
    line = line:match("^%s*(.-)%s*$")
    if line ~= "" then out[#out + 1] = line end
  end
  return out
end

-- Item ID gathered from a node: the bundled table, else an item with the node's own name that
-- the game has cached (most herbs are named after their node).
function Nodes.Item(name)
  local data = ns.NodeData and ns.NodeData[name]
  if data then return data[1] end
  return Api.ItemIDByName(name)
end

-- A node's rare drops, likeliest first: { { id, name, chance (%), price or nil } }.
function Nodes.Rares(name)
  local data = ns.NodeData and ns.NodeData[name]
  local out = {}
  for _, r in ipairs((data and data.rare) or {}) do
    out[#out + 1] = { id = r[1], chance = r[2], price = ns.Prices.Sell(r[1]),
      name = (Api.Item(r[1])) or ("item " .. r[1]) }
  end
  table.sort(out, function(a, b)
    if a.chance ~= b.chance then return a.chance > b.chance end
    if (a.price or 0) ~= (b.price or 0) then return (a.price or 0) > (b.price or 0) end
    return a.name < b.name
  end)
  return out
end

-- { { name = item name, price = copper } } for the nodes in a tooltip text, priced ones only,
-- one line per item.
function Nodes.Prices(text)
  local out, seen = {}, {}
  for _, node in ipairs(Nodes.Parse(text)) do
    local id = Nodes.Item(node)
    if id and not seen[id] then
      seen[id] = true
      local price = ns.Prices.Sell(id)
      if price then out[#out + 1] = { name = (Api.Item(id)) or node, price = price, id = id } end
    end
  end
  return out
end
