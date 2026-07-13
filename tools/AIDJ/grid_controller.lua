-- grid_controller.lua
-- APC mini mk2 8x8 grid
-- Columns 0-7 = Tracks 1-8 (left to right)
-- Rows 7 (bottom) to 0 (top): pad press triggers note on column's track
-- Playback: vertical progress — red dot sweeps down each column

local M = {}
local _ctx, _apc_out = nil, nil
local _last_line = -1

-- Note mapping: each pad (column C, row R) triggers a note on track C+1
-- Row determines pitch: row 7 = C-4, row 0 = C-6 (lower = higher row index... actually let's do the intuitive one: top = higher pitch)
-- Row 0 (top) = C-6, Row 7 (bottom) = C-2 (2 octave range)
local NOTES = {"C-6", "B-5", "A-5", "G-5", "F-5", "D#5", "D-5", "C-5"}

function M.init(config, ctx)
  _ctx = ctx
end

function M.deinit()
  if _apc_out then
    for i = 0, 63 do
      _apc_out:send {0x90, i, 0}
    end
  end
  _last_line = -1
end

function M.set_apc_out(apc_out)
  _apc_out = apc_out
end

-- Handle pad press: column = track, row = note index
-- Returns (track_id, note) for osc_server to dispatch
function M.handle_pad_press(note)
  local row = 7 - math.floor(note / 8)
  local col = note % 8
  if col < 0 or col > 7 then return nil, nil end
  local track_id = tostring(col + 1)
  local note_str = NOTES[row + 1]
  return track_id, note_str
end

-- Update playback position: vertical progress in each column
-- Maps 64 lines to 8 rows: row = 7 - (line * 8) / 64
function M.update_playback_position(current_line, is_playing)
  if not _apc_out then return end

  if not is_playing then
    if _last_line >= 0 then
      local prev_row = 7 - math.floor((_last_line % 64) * 8 / 64)
      for col = 0, 7 do
        _apc_out:send {0x90, prev_row * 8 + col, 0}
      end
      _last_line = -1
    end
    return
  end

  local line = current_line % 64
  local row = 7 - math.floor(line * 8 / 64)

  if row ~= (7 - math.floor((_last_line % 64) * 8 / 64)) then
    -- Clear previous row
    if _last_line >= 0 then
      local prev_row = 7 - math.floor((_last_line % 64) * 8 / 64)
      for col = 0, 7 do
        _apc_out:send {0x90, prev_row * 8 + col, 0}
      end
    end
    -- Light current row (red, all columns)
    for col = 0, 7 do
      _apc_out:send {0x96, row * 8 + col, 0x05}
    end
    _last_line = line
  end
end

return M
