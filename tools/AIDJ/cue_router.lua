-- cue_router.lua
-- Routes a track's signal to the CUE bus (PC headphone out) by toggling
-- a Send device named with "CUE" in its name via OSC control.

local M = {}
local _ctx

local function cue_receiver_index()
  local receiver_index = 0
  for _, track in ipairs(renoise.song().tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEND then
      if string.find(string.lower(track.name or ""), "cue", 1, true) then
        return receiver_index
      end
      receiver_index = receiver_index + 1
    end
  end
  return nil
end

local function keep_source_audible(device)
  local receiver = device.parameters[3].value
  local data = device.active_preset_data or ""
  local updated, count = string.gsub(data, "<MuteSource>true</MuteSource>",
    "<MuteSource>false</MuteSource>")
  if count > 0 then device.active_preset_data = updated end
  device.parameters[1].value = 0
  device.parameters[3].value = receiver
end

function M.init(config, ctx)
  _ctx = ctx
  local cue_receiver = cue_receiver_index()
  if cue_receiver == nil then return end
  for track_index = 1, renoise.song().sequencer_track_count do
    for _, device in ipairs(renoise.song():track(track_index).devices) do
      local receiver = device.parameters and device.parameters[3]
      if string.find(string.lower(device.name or ""), "#send", 1, true) and receiver and
         math.floor(receiver.value + 0.5) == cue_receiver then
        keep_source_audible(device)
      end
    end
  end
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
  local cue_receiver = cue_receiver_index()
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
