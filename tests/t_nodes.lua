-- AH prices on minimap herb and mining node tooltips.

local function world()
  InstallAuctionator()
  Item(3820, "Stranglekelp")
  Item(2770, "Copper Ore")
  Item(2447, "Peacebloom")
  local ns = Boot()
  SetPrice(3820, 12000)
  SetPrice(2770, 1550)
  return ns
end

local function hover(text, owner)
  GameTooltip:SetOwner(owner or Minimap)
  GameTooltip:SetText(text)
  local out = {}
  for _, l in ipairs(GameTooltip.lines) do
    table.insert(out, Strip(l[1]) .. (l[2] and (" = " .. Strip(l[2])) or ""))
  end
  return table.concat(out, " | ")
end

test("a herb on the minimap gets its AH price", function()
  world()
  eq(hover("Stranglekelp"), "Stranglekelp | AH price = 1g 20s")
end)

test("a mining node shows the price of the ore it gives", function()
  world()
  eq(hover("Copper Vein"), "Copper Vein | AH price = 15s 50c")
end)

test("several nodes under the cursor: one price line each, by item name", function()
  world()
  eq(hover("|cffffffffStranglekelp|r\nCopper Vein"), "Stranglekelp\nCopper Vein | Stranglekelp = 1g 20s | Copper Ore = 15s 50c")
end)

test("no price: nothing added; other tooltips are left alone", function()
  world()
  eq(hover("Peacebloom"), "Peacebloom")
  eq(hover("Stranglekelp", UIParent), "Stranglekelp", "not a minimap tooltip")
  eq(hover("Mailbox"), "Mailbox")
end)

test("a node missing from the table falls back to an item of the same name", function()
  local ns = world()
  Item(250001, "Moonpetal")
  SetPrice(250001, 900)
  eq(hover("Moonpetal"), "Moonpetal | AH price = 9s")
end)

test("parse strips colour codes and icons", function()
  local N = Boot().Nodes
  local names = N.Parse("|TInterface\\Icons\\x:0|t |cff00ff00Stranglekelp|r\n  Copper Vein  \n")
  eq(#names, 2)
  eq(names[1], "Stranglekelp")
  eq(names[2], "Copper Vein")
end)
