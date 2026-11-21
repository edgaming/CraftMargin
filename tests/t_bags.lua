-- A red border on the cheapest thing in your bags.

local function world()
  InstallAuctionator()
  Item(1001, "Broken Fang", 0, 5)       -- grey, vendors pay 5c
  Item(1002, "Linen Cloth", 0, 13)
  Item(1003, "Hearthstone", 1, 0)       -- no value at all
  Item(1004, "Quest Letter", 4, 0)
  Mock.items[1004].class = 12
  Item(1005, "Silk Cloth", 0, 38)
  Mock.slots = {
    [0] = { [1] = { id = 1003, noValue = true }, [2] = { id = 1002, count = 4 }, [3] = { id = 1001, count = 3 } },
    [1] = { [1] = { id = 1004 }, [2] = { id = 1005 } },
  }
  local ns = Boot()
  SetPrice(1002, 10)   -- AH: 10c each, after cut 9c; vendor 13c wins: 4 x 13 = 52c
  return ns
end

local function open()
  local buttons = {}
  for bag, slots in pairs(Mock.slots) do
    for slot in pairs(slots) do buttons[bag .. ":" .. slot] = BagButton(bag, slot) end
  end
  FireEvent("BAG_OPEN")
  Advance(1)
  return buttons
end

test("worth: count x the better of vendor and AH after cut; unknown worth and quest items never", function()
  local C = Boot().Cheapest
  eq(C.Worth({ count = 4, vendor = 13, ah = 10 }, 0.05), 52)
  eq(C.Worth({ count = 2, vendor = 5, ah = 100 }, 0.05), 190)
  eq(C.Worth({ count = 1, vendor = 0, ah = nil }, 0.05), nil)
  eq(C.Worth({ count = 1, vendor = 50, noValue = true }, 0.05), nil)
  eq(C.Worth({ count = 1, vendor = 50, classID = 12 }, 0.05), nil)
  eq(C.Worth({ count = 1, vendor = 5, ah = 100, bound = true }, 0.05), 5, "bound: no AH")
end)

test("the cheapest slot gets a red border over its bag button", function()
  local ns = world()
  local buttons = open()
  local target, cheapest = ns.UI.BagHighlight.Target()
  eq(cheapest.itemID, 1001, "3 x 5c = 15c is the cheapest")
  eq(cheapest.worth, 15)
  eq(target, buttons["0:3"])
end)

test("the border moves when bags change, and hides with the bag window", function()
  local ns = world()
  local buttons = open()
  Mock.slots[0][3] = nil
  buttons["0:3"]:Hide()
  FireEvent("BAG_UPDATE_DELAYED")
  Advance(1)
  local target, cheapest = ns.UI.BagHighlight.Target()
  eq(cheapest.itemID, 1005, "Silk Cloth 38c is next, Linen 52c")
  eq(target, buttons["1:2"])
  for _, b in pairs(buttons) do b:Hide() end
  Frames(0.1)
  eq((ns.UI.BagHighlight.Target()), nil)
end)

test("an AH price can make something worth keeping", function()
  local ns = world()
  SetPrice(1001, 5000)
  open()
  local _, cheapest = ns.UI.BagHighlight.Target()
  eq(cheapest.itemID, 1005)
end)

test("debug says what's cheapest and whether its button was found", function()
  world()
  open()
  Mock.printed = {}
  Slash("debug")
  ok(Printed("Cheapest in bags: Broken Fang (bag 0 slot 3, 15c), highlighted"))
end)

test("bags closed: nothing highlighted, nothing breaks", function()
  local ns = world()
  FireEvent("BAG_UPDATE_DELAYED")
  Advance(1)
  local target, cheapest = ns.UI.BagHighlight.Target()
  eq(target, nil)
  eq(cheapest.itemID, 1001)
end)

test("frames whose state is secret are skipped, not tested", function()
  local ns = world()
  local SECRET = setmetatable({}, { __tostring = function() return "secret" end })
  Mock.secret[SECRET] = true
  local decoy = CreateFrame("Frame", nil, UIParent)
  function decoy:IsVisible() return SECRET end
  function decoy:GetBagID() return 0 end
  decoy:SetID(3)
  local nameplate = CreateFrame("Frame", nil, UIParent)
  function nameplate:IsVisible() error("attempt to perform boolean test on a secret boolean value") end
  local buttons = open()
  local target = ns.UI.BagHighlight.Target()
  eq(target, buttons["0:3"], "the real button, past the secret ones")
  ok(not Printed("Craft Margin error"), "no error")
end)
