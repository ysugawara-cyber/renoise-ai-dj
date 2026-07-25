-- pattern_writer.lua
-- Writes pattern rows / note events into the current Renoise song.
-- Uses string-based column APIs (note_string / instrument_string / volume_string)
-- which Renoise parses internally; safer than numeric value conversions.

local M = {}
local _ctx
local _config
local _locked_rows = {}  -- {track_id_num -> { [row] = tui_id }}
local _performance_notes = {}

local function clear_performance_entry(entry)
  local ok, pt = pcall(function()
    return renoise.song():pattern(entry.pattern_index + 1):track(entry.track)
  end)
  if not ok or not pt then return end
  local note_col = pt:line(entry.row):note_column(entry.column)
  if note_col.note_string == entry.note and
     note_col.instrument_value == entry.instrument and
     note_col.volume_value == entry.volume then
    note_col:clear()
  end
  local off_col = pt:line(entry.off_row):note_column(entry.column)
  if off_col.note_string == "OFF" and off_col.instrument_value == 255 then off_col:clear() end
end

local function instrument_index(instrument)
  local inst_val = tonumber(instrument)
  if inst_val then
    if inst_val < 0 or inst_val >= #renoise.song().instruments or inst_val % 1 ~= 0 then
      return nil
    end
    return inst_val
  end
  if type(instrument) == "string" then
    local target = string.lower(instrument)
    for i = 1, #renoise.song().instruments do
      if string.lower(renoise.song():instrument(i).name) == target then
        return i - 1
      end
    end
  end
  return nil
end

local function track_num(track_id)
  local n = tonumber(track_id)
  if n and n >= 1 and n <= #renoise.song().tracks then return n end
  if type(track_id) == "string" then
    local lower = string.lower(track_id)
    if lower == "master" then
      for i, track in ipairs(renoise.song().tracks) do
        if track.type == renoise.Track.TRACK_TYPE_MASTER then return i end
      end
      return nil
    end
  end
  return nil
end

-- 現在のシーケンス slot: 再生中は playback_pos、停止中は edit_pos(カーソル)。
-- Renoise は停止中の playback_pos 書込/読出を無視・陳腐化させるため。
local function cur_seq()
  local t = renoise.song().transport
  return t.playing and t.playback_pos.sequence or t.edit_pos.sequence
end

local function cur_pattern_track(track_n)
  local song = renoise.song()
  local seq = cur_seq()
  local pattern_index = song.sequencer:pattern(seq)
  local pat = song:pattern(pattern_index)
  return pat, pat:track(track_n)
end

function M.init(config, ctx)
  _config = config
  _ctx = ctx
  _locked_rows = {}
  _performance_notes = {}
end

function M.deinit()
  for _, entry in ipairs(_performance_notes) do clear_performance_entry(entry) end
  _performance_notes = {}
  _locked_rows = {}
end

--------------------------------------------------------------------------------
-- row locking (internal advisory; cross-process lock is in session.json)
--------------------------------------------------------------------------------

function M.lock_row(track_id, tui_id, row)
  local tn = track_num(track_id)
  if not tn then return false end
  local t = _locked_rows[tn] or {}
  if t[row] and t[row] ~= tui_id then
    renoise.app():show_warning("AIDJ: row lock denied for " .. tui_id ..
      " on track " .. track_id .. " row " .. row)
    return false
  end
  t[row] = tui_id
  _locked_rows[tn] = t
  return true
end

--------------------------------------------------------------------------------
-- pattern write (one row, note column 1, optional effect column 1)
--------------------------------------------------------------------------------

function M.write_row(track_id, instrument, note_index, note, velocity, fx_cmds)
  local tn = track_num(track_id)
  if not tn then return false end

  local line_idx = tonumber(note_index) or 0
  local pat, pt = cur_pattern_track(tn)
  if line_idx < 0 or line_idx >= pat.number_of_lines then
    renoise.app():show_warning("AIDJ: write_row out of range " .. line_idx)
    return false
  end

  local line = pt:line(line_idx + 1)
  local col = line:note_column(1)

  local inst_val = instrument_index(instrument)
  if not inst_val then
    renoise.app():show_warning("AIDJ: instrument not found: " .. tostring(instrument))
    return false
  end

  col.note_string        = tostring(note or "---")
  col.instrument_string  = string.format("%02X", math.max(0, math.min(0xFE, inst_val)))
  col.volume_value       = math.max(0, math.min(127, tonumber(velocity) or 100))

  if false and fx_cmds and type(fx_cmds) == "string" and #fx_cmds >= 4 then
    local ec = line:effect_column(1)
    ec.effect_value = tonumber(string.sub(fx_cmds, 1, 2), 16)
    ec.number_string = string.sub(fx_cmds, 3, 4)
  end
  return true
end

function M.clear_range(track_id, start_row, row_count)
  local tn = track_num(track_id)
  if not tn then return false end
  local pat, pt = cur_pattern_track(tn)
  for i = 0, (row_count or 1) - 1 do
    local r = start_row + 1 + i
    if r > 0 and r <= pat.number_of_lines then
      pt:line(r):clear()
    end
  end
  return true
end

function M.clear_note_column_range(track_id, start_row, row_count, column_index)
  local tn = track_num(track_id)
  if not tn then return false end
  if renoise.song():track(tn).type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return false end
  local pat, pt = cur_pattern_track(tn)
  local column = math.max(1, math.min(12, tonumber(column_index) or 1))
  for i = 0, (row_count or 1) - 1 do
    local row = start_row + 1 + i
    if row > 0 and row <= pat.number_of_lines then
      pt:line(row):note_column(column):clear()
    end
  end
  return true
end

--------------------------------------------------------------------------------
-- one-shot note injection
-- Renoise has no public "trigger_note" Lua API; instead we write the note
-- into the next line of the currently playing position. If transport is
-- playing, Renoise will render it near-immediately. If not playing, we write
-- to the start of the current pattern so it triggers on the next Play.
--------------------------------------------------------------------------------

function M.one_shot(track_id, note, velocity, length_lines)
  local tn = track_num(track_id)
  if not tn then return false end

  local song = renoise.song()
  local seq = cur_seq()
  local pattern_index = song.sequencer:pattern(seq)
  local pat = song:pattern(pattern_index)
  local pt = pat:track(tn)

  local pos = song.transport.playing and song.transport.playback_pos
                                   or  song.transport.edit_pos

  -- 再生中は次行に書いて即発音させる。停止中はパターン先頭に書き、
  -- 次回 Play で鳴るようにする。
  local row = 1
  if song.transport.playing then
    row = pos.line + 1
  end
  if row > pat.number_of_lines then row = 1 end
  local line = pt:line(row)
  local col = line:note_column(1)
  local expected = _config and _config.track_instruments and _config.track_instruments[tn]
  local inst_val = instrument_index(expected)
  if not inst_val then
    renoise.app():show_warning("AIDJ: track instrument not found: " .. tostring(expected))
    return false
  end
  col.note_string  = tostring(note or "C-4")
  col.instrument_string = string.format("%02X", inst_val)
  col.volume_value = math.max(0, math.min(127, tonumber(velocity) or 100))

  if length_lines and tonumber(length_lines) > 1 then
    local end_row = math.min(row + tonumber(length_lines), pat.number_of_lines)
    for r = row + 1, end_row do
      local ec = pt:line(r):note_column(1)
      ec.note_string = "---"
    end
    if end_row + 1 <= pat.number_of_lines then
      pt:line(end_row + 1):note_column(1).note_string = "OFF"
    end
  end
  return true
end

function M.performance_one_shot(track_id, note, velocity, length_lines)
  local tn = track_num(track_id)
  if not tn then return false end
  local song = renoise.song()
  if not song.transport.playing then
    renoise.app():show_status("AIDJ: Perform mode requires playback")
    return false
  end
  if song:track(tn).type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return false end
  local seq = cur_seq()
  local pattern_index = song.sequencer:pattern(seq)
  if not pattern_index then return false end
  local pat = song:pattern(pattern_index)
  local loop_seconds = pat.number_of_lines / song.transport.lpb * 60 / song.transport.bpm
  if loop_seconds < 1 then return false end
  local pt = pat:track(tn)
  local pos = song.transport.playing and song.transport.playback_pos or song.transport.edit_pos
  local row = song.transport.playing and math.min(pos.line + 1, pat.number_of_lines) or 1
  local note_length = math.max(1, tonumber(length_lines) or 2)
  local off_row = row + note_length
  if off_row > pat.number_of_lines then return false end
  local column = nil
  for candidate = 2, 12 do
    local available = true
    for check_row = row, off_row do
      if not pt:line(check_row):note_column(candidate).is_empty then
        available = false
        break
      end
    end
    if available then
      column = candidate
      break
    end
  end
  if not column then
    renoise.app():show_warning("AIDJ: no empty performance note column on track " .. tn)
    return false
  end
  local expected = _config and _config.track_instruments and _config.track_instruments[tn]
  local inst_val = instrument_index(expected)
  if not inst_val then return false end
  local track = song:track(tn)
  track.visible_note_columns = math.max(track.visible_note_columns, column)
  local note_col = pt:line(row):note_column(column)
  local note_velocity = math.max(0, math.min(127, tonumber(velocity) or 100))
  note_col.note_string = tostring(note or "C-4")
  note_col.instrument_string = string.format("%02X", inst_val)
  note_col.volume_value = note_velocity
  pt:line(off_row):note_column(column).note_string = "OFF"
  table.insert(_performance_notes, {
    pattern_index = pattern_index,
    sequence = seq,
    track = tn,
    row = row,
    off_row = off_row,
    column = column,
    note = note_col.note_string,
    instrument = inst_val,
    volume = note_velocity,
    start_line = pos.line,
  })
  return true
end

function M.cleanup_performance_notes(sequence, line, is_playing)
  for index = #_performance_notes, 1, -1 do
    local entry = _performance_notes[index]
    local passed = not is_playing or sequence ~= entry.sequence or
      line > entry.off_row or line < entry.start_line
    if passed then
      clear_performance_entry(entry)
      table.remove(_performance_notes, index)
    end
  end
end

--------------------------------------------------------------------------------
-- phrase trigger: write Zxx effect on current line
--------------------------------------------------------------------------------
function M.trigger_phrase(track_id, phrase_hex)
  local slot = tonumber(phrase_hex, 16)
  if not slot or slot < 1 then return false end
  slot = math.min(slot, #renoise.song().sequencer.pattern_sequence)
  local t = renoise.song().transport
  if t.playing then
    local pos = t.playback_pos
    pos.sequence = slot
    pos.line = 1
    t.playback_pos = pos
  else
    local pos = t.edit_pos
    pos.sequence = slot
    pos.line = 1
    t.edit_pos = pos
  end
  return true
end

--------------------------------------------------------------------------------
-- mixer (1-based)
--------------------------------------------------------------------------------

function M.set_volume(track_id, v)
  local tn = track_num(track_id)
  if not tn then return false end
  local tr = renoise.song():track(tn)
  tr.postfx_volume.value = math.max(0, math.min(1.41253, ((tonumber(v) or 1000) / 1000) * 1.41253))
  return true
end

function M.set_pan(track_id, p)
  local tn = track_num(track_id)
  if not tn then return false end
  local pn = math.max(-1000, math.min(1000, tonumber(p) or 0))
  renoise.song():track(tn).postfx_panning.value = (pn / 1000 + 1) / 2
  return true
end

function M.set_mute(track_id, m)
  local tn = track_num(track_id)
  if not tn then return false end
  local tr = renoise.song():track(tn)
  if tr.type == renoise.Track.TRACK_TYPE_SEQUENCER or tr.type == renoise.Track.TRACK_TYPE_GROUP then
    tr.mute_state = (tonumber(m) == 1)
      and renoise.Track.MUTE_STATE_MUTED
      or  renoise.Track.MUTE_STATE_ACTIVE
  end
  return true
end

function M.set_solo(track_id, s)
  local tn = track_num(track_id)
  if not tn then return false end
  local tr = renoise.song():track(tn)
  if tr.type == renoise.Track.TRACK_TYPE_SEQUENCER or tr.type == renoise.Track.TRACK_TYPE_GROUP then
    tr.solo_state = (tonumber(s) == 1) and true or false
  end
  return true
end

--------------------------------------------------------------------------------
-- FX
--------------------------------------------------------------------------------

function M.set_fx_param(track_id, fx_index, param_index, value)
  local tn = track_num(track_id)
  if not tn then return false end
  local tr = renoise.song():track(tn)
  local first_fx = 2  -- skip TrackVolPan
  if tr.devices[2] and string.find(string.lower(tr.devices[2].name or ""), "#send", 1, true) then
    first_fx = 3
  end
  local fx = tr.devices[tonumber(fx_index) + first_fx]
  if not fx then return false end
  local param = fx.parameters[tonumber(param_index) + 1]
  if not param then return false end
  param.value = math.max(0, math.min(1, (tonumber(value) or 0) / 1000))
  return true
end

function M.set_macro(name, value)
  -- macros are declared in config/macros.yaml and resolved by osc_bridge.py
  -- which sends individual /ai/fx/param messages; this handler is the fallback
  renoise.app():show_status("AIDJ: macro " .. tostring(name) .. " " .. tostring(value))
  return true
end

return M
