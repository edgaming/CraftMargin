-- WoW event dispatch (ns.On), the internal bus (ns.Emit / ns.Listen) and timers.
local _, ns = ...

local frame = CreateFrame("Frame")
local wow, bus, pending = {}, {}, {}

function ns.Safe(label, fn, ...)
  local ok, err = pcall(fn, ...)
  if not ok then ns.Error(label, err) end
  return ok
end

function ns.On(event, fn)
  if not wow[event] then
    wow[event] = {}
    frame:RegisterEvent(event)
  end
  table.insert(wow[event], fn)
end

frame:SetScript("OnEvent", function(_, event, ...)
  local list = wow[event]
  if not list then return end
  for i = 1, #list do ns.Safe(event, list[i], ...) end
end)

function ns.Listen(name, fn)
  bus[name] = bus[name] or {}
  table.insert(bus[name], fn)
end

function ns.Emit(name, ...)
  local list = bus[name]
  if not list then return end
  for i = 1, #list do ns.Safe(name, list[i], ...) end
end

function ns.After(seconds, fn)
  C_Timer.After(seconds, function() ns.Safe("timer", fn) end)
end

-- Run fn once, `seconds` after the first call; later calls in that window are dropped.
function ns.Debounce(key, seconds, fn)
  if pending[key] then return end
  pending[key] = true
  ns.After(seconds, function()
    pending[key] = nil
    fn()
  end)
end

-- Domain code calls this; the window listens for "UPDATE" and redraws itself.
function ns.Update()
  ns.Debounce("update", 0.1, function() ns.Emit("UPDATE") end)
end

ns.On("ADDON_LOADED", function(name)
  if name ~= ns.name then return end
  ns.InitDB()
  ns.Emit("READY")
end)
