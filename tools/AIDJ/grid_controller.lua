-- grid_controller.lua
-- APC mini mk2 8x8 grid as Ableton Session View
-- Rows 0-4: Clip launcher (5 scenes × 8 tracks)
-- Playback position: 64-LED progress sweep (trumps clip LEDs when playing)

local M = {}
local _ctx, _apc_out = nil, nil

-- Track armed state: grid[scene_idx][track_idx] = true
local _grid_state = {}
for s = 1, 5 do
  _grid_state[s] = {}
  for t = 1, 8 do _grid_state[s][t] = false end
end

-- Last playback line (for diff-based LED updates)
local _last_line = -1

-- Map scene+track to pad index (0-63)
-- Row 0-4 = scene 1-5, Col 0-7 = track 1-8
-- pad_idx = (4 - scene_idx + 1) * 8 + (track_idx - 1)
-- Actually, scene 1 = row 0 (top), so: pad_idx = (scene_idx - 1) * 8 + (track_idx - 1)
local function pad_idx(scene_idx, track_idx)
  return (scene_idx - 1) * 8 + (track_idx - 1)
end

function M.init(config, ctx)
  _ctx = ctx
end

function M.deinit()
  if _apc_out then
    for i = 0, 63 do
      _apc_out:send {0x90, i, 0}
    end
  end
end

-- Set APC output reference from midi_router
function M.set_apc_out(apc_out)
  _apc_out = apc_out
end

-- Arm a scene/track cell (user pressed the pad)
function M.arm_scene(scene_idx, track_idx)
  if scene_idx < 1 or scene_idx > 5 or track_idx < 1 or track_idx > 8 then return end
  _grid_state[scene_idx][track_idx] = true
  M.refresh_led(scene_idx, track_idx)
end

-- Refresh a single cell LED
function M.refresh_led(scene_idx, track_idx)
  if not _apc_out then return end
  local idx = pad_idx(scene_idx, track_idx)
  if _grid_state[scene_idx][track_idx] then
    _apc_out:send {0x96, idx, 0x15}  -- green solid
  else
    _apc_out:send {0x90, idx, 0}      -- off
  end
end

-- Refresh all scene/track LEDs (rows 0-4)
function M.refresh_all()
  for s = 1, 5 do
    for t = 1, 8 do
      M.refresh_led(s, t)
    end
  end
end

-- Update playback position LED (called ~10Hz from status_publisher)
-- Maps 64 lines to 64 pads: pad_idx = 63 - line (top-left = line 0)
function M.update_playback_position(current_line, is_playing)
  if not _apc_out then return end

  if not is_playing then
    if _last_line >= 0 then
      -- Clear last position LED, restore grid
      _apc_out:send {0x90, 63 - _last_line, 0}
      _last_line = -1
      M.refresh_all()
    end
    return
  end

  local line = current_line % 64
  local idx = 63 - line  -- top-left = line 0

  -- Turn off previous position LED
  if _last_line >= 0 then
    local prev_idx = 63 - (_last_line % 64)
    _apc_out:send {0x90, prev_idx, 0}
  end

  -- Light current position (red)
  _apc_out:send {0x96, idx, 0x05}  -- red solid
  _last_line = line
end

return M
