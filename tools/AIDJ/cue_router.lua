-- cue_router.lua
-- Routes a track's signal to the CUE bus (PC headphone out) by toggling
-- a Send device named with "CUE" in its name via OSC control.

local M = {}
local _ctx

function M.init(config, ctx)
  _ctx = ctx
end

function M.deinit() end

function M.set_cue(track_id, on)
  local tn = tonumber(track_id)
  if not tn or tn < 1 or tn > #renoise.song().tracks then return false end
  local tr = renoise.song():track(tn)
  local found = false
  for _, dev in ipairs(tr.devices) do
    local name = string.lower(dev.name or "")
    local receiver = dev.parameters and dev.parameters[3]
    if string.find(name, "#send", 1, true) and receiver and receiver.value == 0 then
      -- #Send's first parameter is the amount (0..1)
      if dev.parameters and dev.parameters[1] then
        dev.parameters[1].value = (tonumber(on) == 1) and 1.0 or 0.0
        found = true
      end
    end
  end
  return found
end

return M
