-- AH prices on minimap herb and mining node tooltips.

local function world()
  InstallAuctionator()
  Item(3820, "Stranglekelp")
  Item(2770, "Copper Ore")
  Item(2447, "Peacebloom")
  Item(774, "Malachite")
  Item(818, "Tigerseye")
  Item(1210, "Shadowgem")
  local ns = Boot()
  SetPrice(3820, 12000)
  SetPrice(2770, 1550)
  return ns
end

local function hover(text, owner)
  GameTooltip:SetOwner(owner or UIParent) -- the minimap's node tooltip is owned by UIParent
  GameTooltip:SetText(text)
  local out = {}
  for _, l in ipairs(GameTooltip.lines) do
    table.insert(out, (Strip(l[1]):gsub("^%s+", "")) .. (l[2] and (" = " .. Strip(l[2])) or ""))
  end
  return table.concat(out, " | ")
end

test("a herb on the minimap gets its AH price on the name line", function()
  world()
  eq(hover("Stranglekelp"), "Stranglekelp (AH 1g 20s)")
end)

test("a mining node shows the price of the ore it gives", function()
  world()
  eq(hover("Copper Vein"), "Copper Vein (AH 15s 50c) | Chance for: | Malachite 1% (no AH price) | Shadowgem 1% (no AH price) | Tigerseye 1% (no AH price)")
end)

test("rare drops list each one with its chance and AH price, likeliest then dearest first", function()
  world()
  SetPrice(774, 300)
  SetPrice(1210, 2500)
  eq(hover("Copper Vein"), "Copper Vein (AH 15s 50c) | Chance for: | Shadowgem 1% (AH 25s) | Malachite 1% (AH 3s) | Tigerseye 1% (no AH price)")
end)

test("fractional chances keep one decimal", function()
  local ns = world()
  ns.NodeData["Test Vein"] = { 2770, rare = { { 1210, 0.8 } } }
  SetPrice(1210, 2500)
  eq(hover("Test Vein"), "Test Vein (AH 15s 50c) | Chance for: | Shadowgem 0.8% (AH 25s)")
end)

test("several nodes under the cursor: one price line per item, no rares", function()
  world()
  eq(hover("|cffffffffStranglekelp|r\nCopper Vein"), "Stranglekelp\nCopper Vein | Stranglekelp = 1g 20s | Copper Ore = 15s 50c")
end)

test("no price: nothing added; tooltips for anything that isn't a node are left alone", function()
  world()
  eq(hover("Peacebloom"), "Peacebloom")
  eq(hover("Mailbox"), "Mailbox")
  eq(hover("Stranglekelp\nMailbox"), "Stranglekelp\nMailbox", "mixed with something else: left alone")
  eq(hover("Stranglekelp", Minimap), "Stranglekelp (AH 1g 20s)", "any owner")
end)

test("an item name alone doesn't make a tooltip a node, until you've gathered it", function()
  world()
  Item(250001, "Moonpetal")
  SetPrice(250001, 900)
  eq(hover("Moonpetal"), "Moonpetal")
  Gather("Moonpetal", { 250001 })
  eq(hover("Moonpetal"), "Moonpetal (AH 9s)")
end)

test("the minimap's arrow icon before the name is fine, and a tooltip is handled once", function()
  world()
  SetPrice(3369, 700)
  local text = hover("|TInterface\\Minimap\\arrow:0|t Grave Moss")
  ok(text:find("Grave Moss %(AH 7s%)$"), text)
  GameTooltip._scripts.OnShow(GameTooltip)
  eq(#GameTooltip.lines, 1, "OnShow after SetText adds nothing twice")
end)

test("filled without SetText: the OnShow hook handles it", function()
  world()
  GameTooltip:SetOwner(UIParent)
  GameTooltip.lines = { { "Stranglekelp" } }
  GameTooltip._scripts.OnShow(GameTooltip)
  eq(Strip(GameTooltip.lines[1][1]), "Stranglekelp (AH 1g 20s)")
end)

test("parse strips colour codes and icons", function()
  local N = Boot().Nodes
  local names = N.Parse("|TInterface\\Icons\\x:0|t |cff00ff00Stranglekelp|r\n  Copper Vein  \n")
  eq(#names, 2)
  eq(names[1], "Stranglekelp")
  eq(names[2], "Copper Vein")
end)

test("gathering a node records what it gave, once per loot window", function()
  local ns = world()
  Gather("Stranglekelp", { 3820, 3820, 250500 })
  Gather("Stranglekelp", { 3820 })
  local rec = ns.db.gathered["Stranglekelp"]
  eq(rec.n, 2)
  eq(rec.items[3820], 2)
  eq(rec.items[250500], 1)
end)

test("a node with no Classic rare data lists what you've gathered from it", function()
  world()
  Item(250500, "Stranglevine")
  SetPrice(250500, 23000)
  for i = 1, 9 do Gather("Stranglekelp", { 3820 }) end
  Gather("Stranglekelp", { 3820, 250500 })
  eq(hover("Stranglekelp"), "Stranglekelp (AH 1g 20s) | Chance for (from your 10 gathers): | Stranglevine 10% (AH 2g 30s)")
end)

test("a new vein nobody knows gets its ore and rares from your gathering", function()
  world()
  Item(260000, "Forever Ore")
  Item(260001, "Forever Gem")
  SetPrice(260000, 5000)
  SetPrice(260001, 90000)
  for i = 1, 3 do Gather("Glimmering Vein", { 260000 }, 2575) end
  Gather("Glimmering Vein", { 260000, 260001 }, 2575)
  eq(hover("Glimmering Vein"), "Glimmering Vein (AH 50s) | Chance for (from your 4 gathers): | Forever Gem 25% (AH 9g)")
end)

test("nodes with Classic rare data keep the Classic rates", function()
  local ns = world()
  SetPrice(1210, 2500)
  Gather("Copper Vein", { 2770, 1210 }, 2575)
  ok(hover("Copper Vein"):find("| Chance for: |", 1, true), "Classic header, not 'from your gathers'")
end)

test("only gathering is recorded: other casts and late loot windows are ignored", function()
  local ns = world()
  Gather("Battered Chest", { 3820 }, 6477) -- Opening, not gathering
  eq(ns.db.gathered["Battered Chest"], nil)
  FireEvent("UNIT_SPELLCAST_SENT", "player", "Peacebloom", "g", 2366)
  Advance(30)
  Mock.loot = { 2447 }
  FireEvent("LOOT_OPENED")
  eq(ns.db.gathered["Peacebloom"], nil, "loot came too long after the cast")
end)

test("a gathering spell recognised by name on this client", function()
  local ns = world()
  Mock.spellNames = { [265819] = "Herb Gathering" }
  Gather("Stranglekelp", { 3820 }, 265819)
  eq(ns.db.gathered["Stranglekelp"].n, 1)
end)

test("a tooltip filled without SetText or OnShow still gets prices, once", function()
  world()
  SetPrice(2453, 146)
  Item(2453, "Bruiseweed")
  GameTooltip:SetOwner(UIParent)
  GameTooltip._shown = true
  GameTooltip.lines = { { "Bruiseweed" } } -- set straight on the font string, no hooks fire
  Frames(0.3)
  eq(Strip(GameTooltip.lines[1][1]), "Bruiseweed (AH 1s 46c)")
  Frames(1)
  eq(#GameTooltip.lines, 1, "nothing added twice")
end)

test("the poll leaves a node tooltip that already has more lines alone", function()
  world()
  SetPrice(1210, 2500)
  Item(1210, "Shadowgem")
  GameTooltip:SetOwner(UIParent)
  GameTooltip._shown = true
  GameTooltip.lines = { { "Copper Vein" } }
  Frames(0.3)
  local n = #GameTooltip.lines
  ok(n > 1, "rares added")
  Frames(1)
  eq(#GameTooltip.lines, n, "not added again")
end)
