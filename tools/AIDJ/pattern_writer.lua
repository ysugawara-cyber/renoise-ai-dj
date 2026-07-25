-- pattern_writer.lua
-- Writes pattern rows / note events into the current Renoise song.
-- Uses string-based column APIs (note_string / instrument_string / volume_string)
-- which Renoise parses internally; safer than numeric value conversions.

local M = {}
local _ctx
local _config
local _locked_rows = {}  -- {track_id_num -> { [row] = tui_id }}

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

-- 再生中パターンの解決: sequencer slot 番号は pattern index ではない。
-- pattern_sequence[slot] の値は 0-based の pattern 番号(GUI の "Pattern 00" 等)。
-- song:pattern() は 1-based なので +1 して渡すこと。
local function cur_pattern_track(track_n)
  local song = renoise.song()
  local seq = cur_seq()
  local pat_idx = song.sequencer.pattern_sequence[seq]
  local pat = pat_idx and song:pattern(pat_idx + 1) or song:pattern(seq)
  return pat, pat:track(track_n)
end

function M.init(config, ctx)
  _config = config
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
  local pat_idx = song.sequencer.pattern_sequence[seq]
  local pat = pat_idx and song:pattern(pat_idx + 1) or song:pattern(seq)
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
