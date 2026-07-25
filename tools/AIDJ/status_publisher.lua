-- status_publisher.lua
-- Broadcasts BPM/scene/play via OSC to osc_bridge.py at ~10 Hz.
-- Uses renoise.Socket.SocketClient + local osc_protocol encoder.

local M = {}
local _client, _host, _port, _running = nil, "", 0, false
local _config = nil
local osc_protocol = require "osc_protocol"
local _grid = nil
local _timer_fn = nil
local STATUS_INTERVAL_MS = 100

local function instrument_index(name)
  if not name then return -1 end
  local target = string.lower(name)
  for i = 1, #renoise.song().instruments do
    if string.lower(renoise.song():instrument(i).name) == target then return i - 1 end
  end
  return -1
end

local function json_string(value)
  return '"' .. string.gsub(string.gsub(value or "", "\\", "\\\\"), '"', '\\"') .. '"'
end

local function build_msg()
  local song = renoise.song()
  if not song then return nil end
  local t = song.transport

  local tracks = {}
  for i = 1, #song.tracks do
    local tr = song:track(i)
    local expected = _config and _config.track_instruments and _config.track_instruments[i]
    local index = instrument_index(expected)
    if expected then
      tracks[i] = string.format(
        "{\"v\":%.4f,\"m\":%d,\"s\":%d,\"in\":%s,\"ii\":%d,\"io\":%d}",
        tr.postfx_volume.value,
        tr.mute_state == renoise.Track.MUTE_STATE_MUTED and 1 or 0,
        (tr.solo_state == true) and 1 or 0,
        json_string(expected), index, index >= 0 and 1 or 0)
    else
      tracks[i] = string.format(
        "{\"v\":%.4f,\"m\":%d,\"s\":%d}",
        tr.postfx_volume.value,
        tr.mute_state == renoise.Track.MUTE_STATE_MUTED and 1 or 0,
        (tr.solo_state == true) and 1 or 0)
    end
  end
  local tracks_str = "[" .. table.concat(tracks, ",") .. "]"

  -- 停止中の playback_pos は古い位置のままなので、停止中は edit_pos(カーソル)を
  -- active_scene として送る(シーンを arm した状態が session.json に反映される)。
  local seq = t.playing and t.playback_pos.sequence or t.edit_pos.sequence

  return osc_protocol.encode_message("/ai/status", "iiis", {
    math.floor(t.bpm * 10),
    seq,
    t.playing and 1 or 0,
    tracks_str,
  })
end

function M.init(config, ctx)
  M.deinit()
  _config = config
  _host = config.osc_send_host
  _port = config.osc_send_port

  local client, err = renoise.Socket.create_client(
    _host, _port, renoise.Socket.PROTOCOL_UDP)
  if not client then
    renoise.app():show_warning("AIDJ: failed to create OSC status client: " ..
      tostring(err))
    return nil, tostring(err)
  end
  _client = client
  _running = true
  _timer_fn = function()
    if not _running or not _client then return end
    local payload = build_msg()
    if payload then
      local ok, sErr = _client:send(payload)
      if not ok then
        print("[AIDJ status_publisher] send err:", tostring(sErr))
      end
    end
    if _grid then
      local song = renoise.song()
      if song then
        _grid.update_playback_position(song.transport.playback_pos.line, song.transport.playing)
      end
    end
  end
  if not renoise.tool():has_timer(_timer_fn) then
    renoise.tool():add_timer(_timer_fn, STATUS_INTERVAL_MS)
  end
  return true
end

function M.deinit()
  _running = false
  if _timer_fn and renoise.tool():has_timer(_timer_fn) then
    renoise.tool():remove_timer(_timer_fn)
  end
  _timer_fn = nil
  if _client then _client:close() end
  _client = nil
  _config = nil
end

function M.set_grid(grid)
  _grid = grid
end

return M
