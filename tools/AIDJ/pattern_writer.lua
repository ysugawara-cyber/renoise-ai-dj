-- pattern_writer.lua
-- Writes pattern rows / note events into the current Renoise song.
-- Uses string-based column APIs (note_string / instrument_string / volume_string)
-- which Renoise parses internally; safer than numeric value conversions.

local M = {}
local _ctx
local _locked_rows = {}  -- {track_id_num -> { [row] = tui_id }}

local function track_num(track_id)
  local n = tonumber(track_id)
  if n and n >= 1 and n <= #renoise.song().tracks then return n end
  if type(track_id) == "string" then
    local lower = string.lower(track_id)
    if lower == "master" then
      return #renoise.song().tracks
    end
  end
  return nil
end

local function cur_pattern_seq()
  return renoise.song().transport.playback_pos.sequence
end

local function cur_pattern_track(track_n)
  local seq = cur_pattern_seq()
  local pat = renoise.song():pattern(seq)
  return pat, pat:track(track_n)
end

function M.init(config, ctx)
  _ctx = ctx
  _locked_rows = {}
end

function M.deinit()
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

  local inst_val = tonumber(instrument)
  if not inst_val and type(instrument) == "string" then
    for i = 1, #renoise.song().instruments do
      if renoise.song():instrument(i).name == instrument then
        inst_val = i - 1
        break
      end
    end
  end
  inst_val = inst_val or 0

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
  local pos = song.transport.playback_pos
  local pat = song:pattern(pos.sequence)
  local pt = pat:track(tn)

  local row = pos.line + 1
  if row > pat.number_of_lines then row = 1 end
  local line = pt:line(row)
  local col = line:note_column(1)
  col.note_string  = tostring(note or "C-4")
  col.instrument_string = string.format("%02X", tn - 1)
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

--------------------------------------------------------------------------------
-- phrase trigger: write Zxx effect on current line
--------------------------------------------------------------------------------
function M.trigger_phrase(track_id, phrase_hex)
  local slot = tonumber(phrase_hex, 16)
  if not slot or slot < 1 then return false end
  slot = math.min(slot, #renoise.song().sequencer.pattern_sequence)
  local pos = renoise.song().transport.playback_pos
  pos.sequence = slot
  pos.line = 1
  renoise.song().transport.playback_pos = pos
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
  local fx = tr.devices[tonumber(fx_index) + 3]  -- skip TrackVolPan + #Send
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