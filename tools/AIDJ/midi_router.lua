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
local _ctx, _apc_in, _apc_out, _mix_in, _mix_out = nil, nil, nil, nil, nil
local _grid = nil
local _mix_leds = {}

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
    if #bytes < 3 or bytes[2] < 0 or bytes[2] > 127 or bytes[3] < 0 or bytes[3] > 127 then return nil end
    m.type = "note"
    m.note = bytes[2]
    m.velocity = bytes[3]
    m.is_note_on = (kind == 0x90) and (m.velocity > 0)
  elseif kind == 0xB0 then
    if #bytes < 3 or bytes[2] < 0 or bytes[2] > 127 or bytes[3] < 0 or bytes[3] > 127 then return nil end
    m.type = "cc"
    m.cc = bytes[2]
    m.value = bytes[3]
  elseif kind == 0xE0 then
    if #bytes < 3 or bytes[2] < 0 or bytes[2] > 127 or bytes[3] < 0 or bytes[3] > 127 then return nil end
    m.type = "pitchbend"
    m.value = bytes[3] * 128 + bytes[2]
  else
    m.type = "other"
  end
  return m
end

local function send_mix_led(note, on)
  if _mix_out then _mix_out:send {0x90, note, on and 127 or 0} end
end

function M.update_feedback()
  if not _mix_out then return end
  for track = 1, 8 do
    local song_track = renoise.song().tracks[track]
    if song_track then
      local mute = song_track.mute_state == renoise.Track.MUTE_STATE_MUTED
      local solo = song_track.solo_state == true
      local mute_note = 1 + (track - 1) * 3
      local solo_note = 3 + (track - 1) * 3
      if _mix_leds[mute_note] ~= mute then
        send_mix_led(mute_note, mute)
        _mix_leds[mute_note] = mute
      end
      if _mix_leds[solo_note] ~= solo then
        send_mix_led(solo_note, solo)
        _mix_leds[solo_note] = solo
      end
    end
  end
end

local function handle_apc(bytes)
  local msg = parse(bytes)
  if not msg or msg.channel ~= 0 then return end
  if msg.type == "note" then
    if msg.note == 122 then
      _grid.set_shift(msg.is_note_on)
      return
    end
    if msg.is_note_on then
      local t = renoise.song().transport
      if msg.note == 100 then
        t:start(1)
      elseif msg.note == 101 then
        t:stop()
      elseif msg.note == 102 then
        t.loop_pattern = not t.loop_pattern
      elseif msg.note == 103 or msg.note == 104 then
        local pos = t.playing and t.playback_pos or t.edit_pos
        local count = #renoise.song().sequencer.pattern_sequence
        local target = math.max(1, math.min(count, pos.sequence + (msg.note == 103 and -1 or 1)))
        require("scene_launcher").launch(target)
      elseif msg.note == 105 then
        _grid.change_bank(-1)
      elseif msg.note == 106 then
        _grid.change_bank(1)
      elseif msg.note == 107 then
        if _grid.is_shifted() then _grid.clear_bank() else _grid.toggle_mode() end
      elseif msg.note >= 112 and msg.note <= 119 then
        local scene = msg.note - 111 + (_grid.is_shifted() and 8 or 0)
        require("scene_launcher").launch(scene)
      elseif msg.note >= 0 and msg.note <= 63 then
        _grid.handle_pad_press(msg.note)
      end
    elseif msg.note >= 0 and msg.note <= 63 then
      _grid.handle_pad_release(msg.note)
    end
  elseif msg.type == "cc" then
    local pw = require "pattern_writer"
    if msg.cc >= 48 and msg.cc <= 55 then
      pw.set_volume(tostring(msg.cc - 47), math.floor(msg.value * 1000 / 127))
    elseif msg.cc == 56 then
      pw.set_volume("master", math.floor(msg.value * 1000 / 127))
    end
  end
end

local function apply_macro(index, msg)
  local pw = require "pattern_writer"
  local value = math.floor(msg.value * 1000 / 127)
  if index == 1 then
    renoise.song().transport.bpm = math.max(120, math.min(240, math.floor(120 + 120 * value / 1000)))
  elseif index == 2 then
    local swing = math.max(0, math.min(1, value / 1000))
    renoise.song().transport.groove_enabled = true
    renoise.song().transport.groove_amounts = {swing, swing, swing, swing}
  elseif index == 3 then
    pw.set_pan("master", math.floor((msg.value * 2000 / 127) - 1000))
  elseif index == 4 then
    pw.set_fx_param("7", 0, 0, value)
  elseif index == 5 then
    pw.set_fx_param("7", 1, 4, value)
  elseif index == 6 then
    pw.set_fx_param("master", 0, 1, value)
  elseif index == 7 then
    pw.set_fx_param("2", 0, 1, value)
  elseif index == 8 then
    pw.set_fx_param("7", 2, 2, value)
  end
end

local function handle_mix(bytes)
  local msg = parse(bytes)
  if not msg or msg.channel ~= 0 then return end
  if msg.is_note_on then
    local pw = require "pattern_writer"
    if msg.note >= 1 and msg.note <= 24 then
      local tn = math.floor((msg.note - 1) / 3) + 1
      if tn >= 1 and tn <= 8 then
        local tk = renoise.song():track(tn)
        local button = msg.note % 3
        if button == 0 then
          pw.set_solo(tostring(tn), tk.solo_state and 0 or 1)
        elseif button == 1 then
          local active = (tk.mute_state == renoise.Track.MUTE_STATE_MUTED)
          pw.set_mute(tostring(tn), active and 0 or 1)
        end
      end
    end
    M.update_feedback()
  elseif msg.type == "cc" then
    local pan_cc = {[16]=1, [20]=2, [24]=3, [28]=4, [46]=5, [50]=6, [54]=7, [58]=8}
    local cue_cc = {[17]=1, [21]=2, [25]=3, [29]=4, [47]=5, [51]=6, [55]=7, [59]=8}
    local macro_cc = {[18]=1, [22]=2, [26]=3, [30]=4, [48]=5, [52]=6, [56]=7, [60]=8}
    local fader_cc = {[19]=1, [23]=2, [27]=3, [31]=4, [49]=5, [53]=6, [57]=7, [61]=8}
    if pan_cc[msg.cc] then
      require("pattern_writer").set_pan(
        tostring(pan_cc[msg.cc]), math.floor((msg.value * 2000 / 127) - 1000))
    elseif cue_cc[msg.cc] then
      require("cue_router").set_cue_level(
        tostring(cue_cc[msg.cc]), math.floor(msg.value * 1000 / 127))
    elseif macro_cc[msg.cc] then
      apply_macro(macro_cc[msg.cc], msg)
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
  _mix_leds = {}
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
    elseif string.match(lower, "midi.mix") and not _mix_out then
      local ok, dev = pcall(renoise.Midi.create_output_device, name)
      if ok and dev then _mix_out = dev end
    end
  end
  if not _apc_in  then renoise.app():show_warning("AIDJ: APC mini not found") end
  if not _mix_in  then renoise.app():show_warning("AIDJ: MIDImix not found") end
  M.update_feedback()
end

function M.deinit()
  if _grid   then _grid.deinit() end
  if _apc_in  then _apc_in:close()  end
  if _apc_out then _apc_out:close() end
  if _mix_in  then _mix_in:close()  end
  if _mix_out then
    for track = 1, 8 do
      send_mix_led(1 + (track - 1) * 3, false)
      send_mix_led(3 + (track - 1) * 3, false)
    end
    _mix_out:close()
  end
  _apc_in, _apc_out, _mix_in, _mix_out, _grid = nil, nil, nil, nil, nil
  _mix_leds = {}
end

function M.feedback_apc(note, color_mode)
  if not _apc_out then return end
  local vel = color_mode or 1
  _apc_out:send {0x90, note, vel}
end

return M
