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
local _grid = nil

-- APC pad note numbers: bottom row = 0-7, top row = 56-63
-- Formula: note = (7 - row) * 8 + col  =>  row = 7 - floor(note/8), col = note % 8
local function apc_row_col(note)
  if note < 0 or note > 63 then return nil, nil end
  return 7 - math.floor(note / 8), (note % 8)
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
    -- FADER CTRL (notes 100-107): transport
    if msg.note == 100 then
      renoise.song().transport:start(1)
    elseif msg.note == 101 then
      renoise.song().transport:stop()
    -- SCENE LAUNCH (notes 112-119): scene switching
    elseif msg.note >= 112 and msg.note <= 119 then
      local sl = require "scene_launcher"
      sl.launch(msg.note - 111)
    -- Pad grid (notes 0-63): one-shot note on column's track
    else
      local col = msg.note % 8
      local row = 7 - math.floor(msg.note / 8)
      if col >= 0 and col <= 7 and row >= 0 and row <= 7 then
        local pw = require "pattern_writer"
        local NOTES = {"C-6", "B-5", "A-5", "G-5", "F-5", "D#5", "D-5", "C-5"}
        pw.one_shot(tostring(col + 1), NOTES[row + 1], 100, 1)
      end
    end
  elseif msg.type == "cc" then
    local pw = require "pattern_writer"
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
    if msg.note >= 1 and msg.note <= 24 then
      local tn = math.floor((msg.note - 1) / 3) + 1
      if tn >= 1 and tn <= 8 then
        local tk = renoise.song():track(tn)
        if msg.note % 3 == 0 then
          pw.set_solo(tostring(tn), tk.solo_state and 0 or 1)
        else
          local active = (tk.mute_state == renoise.Track.MUTE_STATE_MUTED)
          pw.set_mute(tostring(tn), active and 0 or 1)
        end
      end
    end
  elseif msg.type == "cc" then
    local knob_cc = {[16]=0, [20]=1, [24]=2, [28]=3, [46]=4, [50]=5, [54]=6, [58]=7}
    local fader_cc = {[19]=1, [23]=2, [27]=3, [31]=4, [49]=5, [53]=6, [57]=7, [61]=8}
    local mi = knob_cc[msg.cc]
    if mi then
      local pw = require "pattern_writer"
      local v = math.floor(msg.value * 1000 / 127)
      if mi == 0 then
        local bpm = math.floor(120 + 120 * v / 1000)
        renoise.song().transport.bpm = math.max(120, math.min(240, bpm))
      elseif mi == 1 then
        local sw = math.max(0, math.min(1, v / 1000))
        renoise.song().transport.groove_enabled = true
        renoise.song().transport.groove_amounts = {sw, sw, sw, sw}
      elseif mi == 2 then
        local pn = math.floor((msg.value * 2000 / 127) - 1000)
        pw.set_pan("master", pn)
      elseif mi == 3 then
        pw.set_fx_param("7", 0, 0, v)
      elseif mi == 4 then
        pw.set_fx_param("7", 1, 0, v)
      elseif mi == 5 then
        pw.set_fx_param("master", 0, 1, v)
      elseif mi == 6 then
        pw.set_fx_param("2", 0, 1, v)
      elseif mi == 7 then
        pw.set_fx_param("7", 2, 0, v)
      end
    elseif msg.cc == 62 then
      local pw = require "pattern_writer"
      local v = math.floor(msg.value * 1000 / 127)
      pw.set_volume("master", v)
    else
      local tn = fader_cc[msg.cc]
      if tn then
        local pw = require "pattern_writer"
        local v = math.floor(msg.value * 1000 / 127)
        pw.set_volume(tostring(tn), v)
      end
    end
  end
end

function M.init(config, ctx)
  _ctx = ctx
  _grid = require "grid_controller"
  _grid.init(config, ctx)
  for _, name in ipairs(renoise.Midi.available_input_devices()) do
    local lower = string.lower(name)
    if string.match(lower, "apc.mini") and not _apc_in then
      _apc_in = renoise.Midi.create_input_device(name, handle_apc, function() end)
    elseif string.match(lower, "midi.mix") and not _mix_in then
      _mix_in = renoise.Midi.create_input_device(name, handle_mix, function() end)
    end
  end
  for _, name in ipairs(renoise.Midi.available_output_devices()) do
    local lower = string.lower(name)
    if string.match(lower, "apc.mini") and not _apc_out then
      local ok, dev = pcall(renoise.Midi.create_output_device, name)
      if ok and dev then
        _apc_out = dev
        _grid.set_apc_out(_apc_out)
      end
    end
  end
  if not _apc_in  then renoise.app():show_warning("AIDJ: APC mini not found") end
  if not _mix_in  then renoise.app():show_warning("AIDJ: MIDImix not found") end
end

function M.deinit()
  if _grid   then _grid.deinit() end
  if _apc_in  then _apc_in:close()  end
  if _apc_out then _apc_out:close() end
  if _mix_in  then _mix_in:close()  end
  _apc_in, _apc_out, _mix_in, _grid = nil, nil, nil, nil
end

function M.feedback_apc(note, color_mode)
  if not _apc_out then return end
  local vel = color_mode or 1
  _apc_out:send {0x90, note, vel}
end

return M