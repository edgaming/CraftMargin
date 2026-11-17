test("money formatting", function()
  local U = Boot().Util
  eq(Strip(U.Money(41000)), "4g 10s")
  eq(Strip(U.Money(40000)), "4g")
  eq(Strip(U.Money(40099)), "4g")
  eq(Strip(U.Money(8500)), "85s")
  eq(Strip(U.Money(1234)), "12s 34c")
  eq(Strip(U.Money(7)), "7c")
  eq(Strip(U.Money(0)), "0c")
  eq(U.Money(nil), "—")
  eq(Strip(U.Money(-500)), "5s", "sign is dropped")
end)

test("signed money and percent", function()
  local U = Boot().Util
  eq(Strip(U.SignedMoney(49200)), "+4g 92s")
  eq(Strip(U.SignedMoney(-500)), "-5s")
  eq(Strip(U.SignedMoney(0)), "0c")
  eq(U.Percent(1.2), "120%")
  eq(U.Percent(-0.166), "-17%")
end)

test("ages", function()
  local U = Boot().Util
  eq(U.Ago(5), "just now")
  eq(U.Ago(600), "10m ago")
  eq(U.Ago(7200), "2h ago")
  eq(U.Ago(86400), "1 day ago")
  eq(U.Ago(3 * 86400), "3 days ago")
  eq(U.DaysOld(0), "today")
  eq(U.DaysOld(1), "1 day old")
  eq(U.DaysOld(4), "4 days old")
  eq(U.Yield(1), "×1")
  eq(U.Yield(1.5), "×1.5")
end)

test("errors print once, in red, asking for a screenshot", function()
  local ns = Boot()
  ns.Error("x", "boom")
  ns.Error("x", "boom")
  local n = 0
  for _, line in ipairs(Mock.printed) do if line:find("boom", 1, true) then n = n + 1 end end
  eq(n, 1)
  ok(Printed("(please screenshot)"))
  ok(Mock.printed[#Mock.printed]:find("|cffff4040", 1, true), "red")
end)

test("a failing event handler is caught and reported", function()
  local ns = Boot()
  ns.On("SOME_EVENT", function() error("kaboom") end)
  local reached = false
  ns.On("SOME_EVENT", function() reached = true end)
  FireEvent("SOME_EVENT")
  ok(Printed("kaboom"))
  ok(reached, "later handlers still run")
end)

test("money uses coin icons", function()
  local U = Boot().Util
  eq(U.Money(41005), "4|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t 10|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t")
  eq(U.Money(7), "7|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t")
end)
