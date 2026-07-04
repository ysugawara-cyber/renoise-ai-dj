-- midi_router.lua
-- Routes APC mini mk2 / AKAI MIDImix input to Renoise parameters and emits
-- LED feedback to APC for pad lighting. Uses Renoise's MIDI input/output APIs.
-- Track indices are 1-based throughout (Renoise convention).
--
-- Renoise MIDI API notes:
--   renoise.Midi.available_input_devices() / available_output_devices()
--   create_input_device(name, callback, sysex_callback)
--   callback receives a MIDI message as a plain array of byte numbers
--   (no .is_note_on / .cc / .value object fields)

local M = {}
local _ctx, _apc_in, _apc_out, _mix_in = nil, nil, nil, nil

-- APC pad note numbers in Generic MIDI mode: 56..63 row0, 64..71 row1, ...
-- Formula: note = 56 + (row * 8) + col
local function apc_row_col(note)
  if note < 56 or note > 119 then return nil, nil end
  local o = note - 56
  return math.floor(o / 8), (o % 8)
end

-- parse a raw MIDI bytes array into a small table
-- bytes[1] = status byte, bytes[2..] = data bytes
local function parse(bytes)
  if not bytes or #bytes < 1 then return nil end
  local status = bytes[1]
  local channel = status % 16
  local kind = status - channel  -- status & 0xF0
  local m = { channel = channel, kind = kind }
  if kind == 0x80 or kind == 0x90 then
    m.type = "note"
    m.note = bytes[2]
    m.velocity = bytes[3]
    m.is_note_on = (kind == 0x90) and (m.velocity > 0)
  elseif kind == 0xB0 then
    m.type = "cc"
    m.cc = bytes[2]
    m.value = bytes[3]
  elseif kind == 0xE0 then
    m.type = "pitchbend"
    m.value = bytes[3] * 128 + bytes[2]
  else
    m.type = "other"
  end
  return m
end

local function handle_apc(bytes)
  local msg = parse(bytes)
  if not msg then return end
  if msg.is_note_on then
    local row, col = apc_row_col(msg.note)
    if row == 0 then
      local sl = require "scene_launcher"
      sl.launch(col + 1)
      M.feedback_apc(msg.note, 1)  -- green
    end
  elseif msg.type == "cc" then
    local pw = require "pattern_writer"
    -- APC sliders CC 48..55 -> Track 1..8 volume
    if msg.cc >= 48 and msg.cc <= 55 then
      pw.set_volume(tostring(msg.cc - 47), math.floor(msg.value * 1000 / 127))
    end
  end
end

local function handle_mix(bytes)
  local msg = parse(bytes)
  if not msg then return end
  if msg.is_note_on then
    local pw = require "pattern_writer"
    -- MIDImix MUTE buttons Note 1..8 -> Track mute toggle
    if msg.note >= 1 and msg.note <= 8 then
      local tk = renoise.song():track(msg.note)
      local active = (tk.mute_state == renoise.Track.MUTE_STATE_MUTED)
      pw.set_mute(tostring(msg.note), active and 0 or 1)
    -- MIDImix SOLO buttons Note 16..23 -> Track solo toggle
    elseif msg.note >= 16 and msg.note <= 23 then
      pw.set_solo(tostring(msg.note - 15), 1)
    end
  elseif msg.type == "cc" then
    -- Macro knobs (CC 10..17) are handled by osc_bridge.py -> /ai/fx/macro.
    -- MIDImix master slider (CC 7) -> master volume handled in Renoise MIDI Map.
  end
end

function M.init(config, ctx)
  _ctx = ctx
  for _, name in ipairs(renoise.Midi.available_input_devices()) do
    local lower = string.lower(name)
    if string.match(lower, "apc.mini") then
      _apc_in  = renoise.Midi.create_input_device(name, handle_apc, function() end)
      _apc_out = renoise.Midi.create_output_device(name)
    elseif string.match(lower, "midi.mix") then
      _mix_in = renoise.Midi.create_input_device(name, handle_mix, function() end)
    end
  end
  if not _apc_in  then renoise.app():show_warning("AIDJ: APC mini not found") end
  if not _mix_in  then renoise.app():show_warning("AIDJ: MIDImix not found") end
end

function M.deinit()
  if _apc_in  then _apc_in:close()  end
  if _apc_out then _apc_out:close() end
  if _mix_in  then _mix_in:close()  end
  _apc_in, _apc_out, _mix_in = nil, nil, nil
end

function M.feedback_apc(note, color_mode)
  if not _apc_out then return end
  _apc_out:send { string.char(0x90, note, color_mode) }
end

return M