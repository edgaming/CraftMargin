-- Price source choice: Auctionator, TSM, both, neither.

local function world(opts)
  opts = opts or {}
  if opts.auc then InstallAuctionator() end
  if opts.tsm then InstallTSM() end
  AddProfession("Tailoring", 197, 1)
  Item(2589, "Linen Cloth")
  Item(2996, "Bolt of Linen Cloth")
  Item(2320, "Coarse Thread")
  Item(4238, "Linen Bag")
  AddRecipe(197, { id = 3755, name = "Linen Bag", out = 4238, mats = { { 2996, 3 }, { 2320, 3 } } })
  if opts.savedSource then CraftMarginDB = { source = opts.savedSource } end
  local ns = Boot()
  if opts.auc then SetPrice(2996, 150); SetPrice(4238, 1200) end
  if opts.tsm then SetTSMPrice(2996, 100); SetTSMPrice(4238, 2000) end
  OpenProfession("Tailoring", 197)
  Slash()
  return ns
end

local function gear() Click(NS.UI.Settings.button) end
local function radios()
  local out = {}
  for _, r in ipairs(NS.UI.Settings.rows) do
    table.insert(out, string.format("%s %s%s", r:GetChecked() and "(•)" or "( )", r.label:GetText(),
      r:IsEnabled() and "" or " [not installed]"))
  end
  return table.concat(out, " | ")
end

test("only Auctionator: it's used and TSM is greyed", function()
  world({ auc = true })
  gear()
  eq(NS.UI.Settings.popup:IsShown(), true)
  eq(radios(), "(•) Auctionator | ( ) TradeSkillMaster [not installed]")
  eq(NS.UI.Settings.rows[2].note:IsShown(), true)
  eq(Window().rows[1].profit, "+6s 60c")
  gear()
  eq(NS.UI.Settings.popup:IsShown(), false, "cogwheel closes it again")
end)

test("only TSM: TSM prices, its header, Auctionator greyed", function()
  world({ tsm = true })
  gear()
  eq(radios(), "( ) Auctionator [not installed] | (•) TradeSkillMaster")
  local w = Window()
  eq(w.rows[1].profit, "+15s 70c", "TSM price 20s x 0.95 - (3 x 1s + 3 x 10c)")
  eq(w.status, "Prices from TSM")
  eq(w.statusColor, "muted")
  eq(Mock.tsm.strings[1], "first(dbmarket, dbminbuyout)")
  eq(NS.UI.Main.hint:GetText(), "Click: open recipe  ·  Shift-click: copy a TSM search")
end)

test("TSM with no data: red header", function()
  InstallTSM()
  AddProfession("Tailoring", 197, 1)
  Item(4238, "Linen Bag")
  AddRecipe(197, { id = 3755, name = "Linen Bag", out = 4238, mats = {} })
  Boot()
  OpenProfession("Tailoring", 197)
  Slash()
  eq(Window().status, "No prices from TSM yet")
  eq(Window().statusColor, "bad")
end)

test("both installed: Auctionator by default, switching recalculates at once", function()
  local ns = world({ auc = true, tsm = true })
  eq(Window().rows[1].profit, "+6s 60c")
  gear()
  eq(radios(), "(•) Auctionator | ( ) TradeSkillMaster")
  Click(ns.UI.Settings.rows[2])
  Advance(1)
  eq(radios(), "( ) Auctionator | (•) TradeSkillMaster")
  eq(Window().rows[1].profit, "+15s 70c")
  eq(ns.db.source, "tsm")
end)

test("a saved choice that's no longer installed falls back", function()
  world({ auc = true, savedSource = "tsm" })
  gear()
  eq(radios(), "(•) Auctionator | ( ) TradeSkillMaster [not installed]")
  eq(Window().rows[1].profit, "+6s 60c")
end)

test("neither installed: both greyed, red header, click-only hint", function()
  world()
  gear()
  eq(radios(), "( ) Auctionator [not installed] | ( ) TradeSkillMaster [not installed]")
  eq(Window().status, "No price addon — install Auctionator or TSM")
  eq(NS.UI.Main.hint:GetText(), "Click: open recipe")
  ShiftClick(Window().rows[1].row)
  ok(Printed("Craft Margin: AH search needs Auctionator or TSM."))
end)

test("with TSM, shift-click opens a copy box holding the search string", function()
  world({ tsm = true })
  ShiftClick(Window().rows[1].row)
  local box = NS.UI.CopyBox.frame
  eq(box:IsShown(), true)
  eq(box.title:GetText(), "TSM search for Linen Bag")
  eq(box.box:GetText(), "i:2996/x3;i:2320/x3")
  eq(box.box._highlighted, true, "selected, ready for Ctrl+C")
  eq(UISpecialFrames[#UISpecialFrames], "CraftMarginCopyBox", "Esc closes it")
  -- typing can't change it
  box.box:SetText("oops")
  box.box._scripts.OnTextChanged(box.box, true)
  eq(box.box:GetText(), "i:2996/x3;i:2320/x3")
  eq(Mock.openedRecipe, nil)
end)

test("with both installed and Auctionator chosen, shift-click searches in Auctionator", function()
  world({ auc = true, tsm = true })
  OpenAuctionHouse()
  ShiftClick(Window().rows[1].row)
  eq(LastSearch(), "advanced: Bolt of Linen Cloth x3, Coarse Thread x3")
  eq(NS.UI.CopyBox.frame, nil)
end)

test("the popup closes with the window", function()
  world({ auc = true })
  gear()
  Slash()
  eq(NS.UI.Settings.popup:IsShown(), false)
end)
