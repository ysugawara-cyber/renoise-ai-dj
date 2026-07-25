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
  return M.set_cue_level(track_id, tonumber(on) == 1 and 1000 or 0)
end

function M.set_cue_level(track_id, value)
  local tn = tonumber(track_id)
  if not tn or tn < 1 or tn > #renoise.song().tracks then return false end
  local tr = renoise.song():track(tn)
  local found = false
  local level = math.max(0, math.min(1, (tonumber(value) or 0) / 1000))
  local cue_receiver = nil
  local receiver_index = 0
  for _, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEND then
      if string.find(string.lower(track.name or ""), "cue", 1, true) then
        cue_receiver = receiver_index
        break
      end
      receiver_index = receiver_index + 1
    end
  end
  if cue_receiver == nil then return false end
  for _, dev in ipairs(tr.devices) do
    local name = string.lower(dev.name or "")
    local receiver = dev.parameters and dev.parameters[3]
    if string.find(name, "#send", 1, true) and receiver and
       math.floor(receiver.value + 0.5) == cue_receiver then
      -- #Send's first parameter is the amount (0..1)
      if dev.parameters and dev.parameters[1] then
        dev.parameters[1].value = level
        found = true
      end
    end
  end
  return found
end

return M
