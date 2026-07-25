-- grid_controller.lua
-- APC mini mk2 hybrid 8x8 grid: 64-step editor + performance one-shots.

local M = {}
local _apc_out = nil
local _mode = "step"
local _selected_track = 1
local _bank = 0
local _shift = false
local _last_play_pad = nil
local _last_scene = -1
local _last_scene_shift = nil
local _refresh_tick = 0
local _clear_armed_until = 0
local _clear_target = nil
local _last_control_state = ""

local COLOR_OFF = 0
local COLOR_RED = 5
local COLOR_AMBER = 9
local COLOR_GREEN = 21
local PERFORMANCE_NOTES = {"C-6", "B-5", "A-5", "G-5", "F-5", "D#5", "D-5", "C-5"}

local function pad_position(note)
  if note < 0 or note > 63 then return nil, nil end
  return 7 - math.floor(note / 8), note % 8
end

local function pad_note(step)
  local row = math.floor(step / 8)
  local col = step % 8
  return (7 - row) * 8 + col
end

local function current_pattern_track(track_n)
  local song = renoise.song()
  if track_n < 1 or track_n > #song.tracks then return nil, nil, nil end
  if song:track(track_n).type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return nil, nil, nil end
  local t = song.transport
  local seq = t.playing and t.playback_pos.sequence or t.edit_pos.sequence
  local pattern_index = song.sequencer:pattern(seq)
  if not pattern_index then return nil, nil, nil end
  local pat = song:pattern(pattern_index)
  return pat, pat:track(track_n), pattern_index
end

local function send_pad(note, color)
  if _apc_out then _apc_out:send {0x96, note, color or COLOR_OFF} end
end

local function step_color(step, resolved_pat, resolved_track)
  local pat, pt = resolved_pat, resolved_track
  if not pat or not pt then pat, pt = current_pattern_track(_selected_track) end
  local row = _bank * 64 + step + 1
  if not pat or row > pat.number_of_lines then return COLOR_OFF end
  local col = pt:line(row):note_column(1)
  if col.note_string == "OFF" then return COLOR_RED end
  return col.is_empty and COLOR_OFF or COLOR_GREEN
end

local function refresh_scene_leds(active_sequence)
  if not _apc_out then return end
  if active_sequence == _last_scene and _shift == _last_scene_shift then return end
  for index = 0, 7 do
    local scene = index + 1 + (_shift and 8 or 0)
    _apc_out:send {0x90, 112 + index, scene == active_sequence and 1 or 0}
  end
  _last_scene = active_sequence
  _last_scene_shift = _shift
end

local function refresh_control_leds(is_playing)
  if not _apc_out then return end
  local loop = renoise.song().transport.loop_pattern
  local state = table.concat({tostring(is_playing), tostring(loop), _mode, tostring(_bank)}, ":")
  if state == _last_control_state then return end
  _apc_out:send {0x90, 100, is_playing and 1 or 0}
  _apc_out:send {0x90, 101, is_playing and 0 or 1}
  _apc_out:send {0x90, 102, loop and 1 or 0}
  _apc_out:send {0x90, 103, 1}
  _apc_out:send {0x90, 104, 1}
  _apc_out:send {0x90, 105, _bank > 0 and 1 or 0}
  _apc_out:send {0x90, 106, _bank < 3 and 1 or 0}
  _apc_out:send {0x90, 107, _mode == "perform" and 1 or 0}
  _last_control_state = state
end

function M.refresh()
  if not _apc_out then return end
  _last_play_pad = nil
  if _shift then
    for note = 0, 63 do send_pad(note, COLOR_OFF) end
    for col = 0, 7 do
      send_pad(56 + col, col + 1 == _selected_track and COLOR_RED or COLOR_GREEN)
    end
    for col = 0, 3 do
      send_pad(48 + col, col == _bank and COLOR_RED or COLOR_AMBER)
    end
  elseif _mode == "step" then
    local pat, pt = current_pattern_track(_selected_track)
    for step = 0, 63 do send_pad(pad_note(step), step_color(step, pat, pt)) end
  else
    for note = 0, 63 do send_pad(note, COLOR_AMBER) end
  end
  _last_scene = -1
end

function M.init(config, ctx)
  _mode = "step"
  _selected_track = 1
  _bank = 0
  _shift = false
  _refresh_tick = 0
  _clear_armed_until = 0
  _clear_target = nil
  _last_control_state = ""
end

function M.deinit()
  if _apc_out then
    for note = 0, 63 do _apc_out:send {0x90, note, 0} end
    for note = 112, 119 do _apc_out:send {0x90, note, 0} end
    for note = 100, 107 do _apc_out:send {0x90, note, 0} end
  end
  _last_play_pad = nil
  _last_control_state = ""
end

function M.set_apc_out(apc_out)
  _apc_out = apc_out
  M.refresh()
end

function M.set_shift(on)
  _shift = on and true or false
  M.refresh()
end

function M.is_shifted()
  return _shift
end

function M.toggle_mode()
  _mode = (_mode == "step") and "perform" or "step"
  renoise.app():show_status("AIDJ APC mode: " .. _mode)
  M.refresh()
end

function M.change_bank(delta)
  _bank = math.max(0, math.min(3, _bank + delta))
  renoise.app():show_status("AIDJ APC step bank: " .. (_bank + 1) .. "/4")
  M.refresh()
end

function M.clear_bank()
  local now = os.time()
  local _, _, pattern_index = current_pattern_track(_selected_track)
  if pattern_index == nil then return false end
  local same_target = _clear_target and
    _clear_target.pattern_index == pattern_index and
    _clear_target.track == _selected_track and _clear_target.bank == _bank
  if now > _clear_armed_until or not same_target then
    _clear_armed_until = now + 3
    _clear_target = {pattern_index = pattern_index, track = _selected_track, bank = _bank}
    renoise.app():show_warning("AIDJ: press SHIFT+MODE again within 3s to clear bank")
    return false
  end
  _clear_armed_until = 0
  _clear_target = nil
  local pw = require "pattern_writer"
  local ok = pw.clear_note_column_range(tostring(_selected_track), _bank * 64, 64, 1)
  if ok then M.refresh() end
  return ok
end

function M.handle_pad_press(note)
  local row, col = pad_position(note)
  if not row then return false end
  if _shift then
    if row == 0 then
      _selected_track = col + 1
      renoise.app():show_status("AIDJ APC edit track: " .. _selected_track)
    elseif row == 1 and col < 4 then
      _bank = col
      renoise.app():show_status("AIDJ APC step bank: " .. (_bank + 1) .. "/4")
    end
    M.refresh()
    return true
  end

  if _mode == "perform" then
    local pw = require "pattern_writer"
    local ok = pw.performance_one_shot(tostring(col + 1), PERFORMANCE_NOTES[row + 1], 110, 2)
    if ok then send_pad(note, COLOR_RED) end
    return ok
  end

  local step = row * 8 + col
  local pattern_row = _bank * 64 + step
  local pat, pt = current_pattern_track(_selected_track)
  if not pat or pattern_row >= pat.number_of_lines then return false end
  local note_col = pt:line(pattern_row + 1):note_column(1)
  if note_col.is_empty then
    local config = require "config"
    local instrument = config.track_instruments[_selected_track]
    local notes = {"C-4", "C-4", "C-2", "C-4", "C-4", "C-5", "C-4", "C-4"}
    local written = require("pattern_writer").write_row(
      tostring(_selected_track), instrument, tostring(pattern_row), notes[_selected_track], 100, "")
    if not written then return false end
  else
    note_col:clear()
  end
  send_pad(note, step_color(step))
  return true
end

function M.handle_pad_release(note)
  if _mode == "perform" and not _shift then send_pad(note, COLOR_AMBER) end
end

function M.update_playback_position(current_line, is_playing, active_sequence)
  refresh_scene_leds(active_sequence or 0)
  refresh_control_leds(is_playing)
  _refresh_tick = (_refresh_tick + 1) % 10
  if _refresh_tick == 0 then M.refresh() end
  if not _apc_out or _mode ~= "step" or _shift then return end
  if _last_play_pad then
    local previous_row, previous_col = pad_position(_last_play_pad)
    local previous_step = previous_row * 8 + previous_col
    send_pad(_last_play_pad, step_color(previous_step))
    _last_play_pad = nil
  end
  if not is_playing then return end
  local line = math.max(0, current_line - 1)
  if math.floor(line / 64) ~= _bank then return end
  local step = line % 64
  _last_play_pad = pad_note(step)
  send_pad(_last_play_pad, COLOR_RED)
end

return M
