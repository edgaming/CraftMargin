-- Pure helpers: money, percentages, time, colours. Plus the error-once printer.
local _, ns = ...
local Util = {}
ns.Util = Util

local L = {
  JUST_NOW = "just now",
  MINUTES = "%dm ago",
  HOURS = "%dh ago",
  DAY = "1 day ago",
  DAYS = "%d days ago",
  TODAY = "today",
  DAY_OLD = "1 day old",
  DAYS_OLD = "%d days old",
  ERROR = "|cffff4040Craft Margin error:|r %s (please screenshot)",
}

-- Status colours, used everywhere: good, attention, problem, inactive.
Util.RGB = {
  good = { 0.25, 0.85, 0.25 },
  warn = { 1.00, 0.82, 0.00 },
  bad = { 1.00, 0.30, 0.30 },
  muted = { 0.55, 0.55, 0.55 },
  head = { 1.00, 0.82, 0.00 },
  text = { 1.00, 1.00, 1.00 },
}

function Util.Hex(kind)
  local c = Util.RGB[kind] or Util.RGB.text
  return string.format("ff%02x%02x%02x", c[1] * 255, c[2] * 255, c[3] * 255)
end

function Util.Color(kind, text)
  return "|c" .. Util.Hex(kind) .. text .. "|r"
end

local G, S, C = "|cffffd700g|r", "|cffc7c7cfs|r", "|cffeda55fc|r"

-- 41000 -> "4g 10s"; 8500 -> "85s"; 1234 -> "12s 34c". Copper is dropped once there is gold.
function Util.Money(copper)
  if copper == nil then return "—" end
  copper = math.floor(math.abs(copper) + 0.5)
  local g = math.floor(copper / 10000)
  local s = math.floor(copper / 100) % 100
  local c = copper % 100
  if g > 0 then
    if s > 0 then return g .. G .. " " .. s .. S end
    return g .. G
  end
  if s > 0 then
    if c > 0 then return s .. S .. " " .. c .. C end
    return s .. S
  end
  return c .. C
end

function Util.SignedMoney(copper)
  if copper == nil then return "—" end
  if copper > 0 then return "+" .. Util.Money(copper) end
  if copper < 0 then return "-" .. Util.Money(copper) end
  return Util.Money(0)
end

function Util.Percent(x)
  if x == nil then return "" end
  return string.format("%d%%", math.floor(x * 100 + 0.5))
end

function Util.Ago(seconds)
  seconds = math.max(0, seconds or 0)
  if seconds < 60 then return L.JUST_NOW end
  if seconds < 3600 then return string.format(L.MINUTES, math.floor(seconds / 60)) end
  if seconds < 86400 then return string.format(L.HOURS, math.floor(seconds / 3600)) end
  local d = math.floor(seconds / 86400)
  if d == 1 then return L.DAY end
  return string.format(L.DAYS, d)
end

-- Auctionator reports age in whole days.
function Util.DaysOld(days)
  if days == nil then return nil end
  if days <= 0 then return L.TODAY end
  if days == 1 then return L.DAY_OLD end
  return string.format(L.DAYS_OLD, days)
end

function Util.Yield(x)
  if x == math.floor(x) then return string.format("×%d", x) end
  return string.format("×%.1f", x)
end

function Util.IsSecret(v)
  return v ~= nil and issecretvalue ~= nil and issecretvalue(v) == true
end

-- Errors: each distinct one is printed once, in red.
ns.errors = {}
local seen = {}
function ns.Error(where, err)
  local msg = tostring(where) .. ": " .. tostring(err)
  if seen[msg] then return end
  seen[msg] = true
  table.insert(ns.errors, msg)
  print(string.format(L.ERROR, msg))
end
