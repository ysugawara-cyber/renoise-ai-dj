-- scene_launcher.lua
-- Switches the Renoise sequencer position to a scene (sequence slot).
-- Scene index is 1-based (matches /ai/scene argument).

local M = {}
local _ctx

function M.init(config, ctx)
  _ctx = ctx
end

function M.deinit() end

function M.launch(scene_index)
  local slot = tonumber(scene_index)
  if not slot or slot < 1 or slot > #renoise.song().sequencer.pattern_sequence then
    renoise.app():show_warning("AIDJ: scene out of range " .. tostring(scene_index))
    return false
  end
  local t = renoise.song().transport
  if t.playing then
    local pos = t.playback_pos
    pos.sequence = slot
    pos.line = 1
    t.playback_pos = pos
  else
    -- 停止中は playback_pos への書込が Renoise に無視されるため edit_pos を動かす。
    -- 次回の Play はカーソル位置 (edit_pos) から始まる。
    local pos = t.edit_pos
    pos.sequence = slot
    pos.line = 1
    t.edit_pos = pos
  end
  return true
end

return M