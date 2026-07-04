-- status_publisher.lua
-- Broadcasts BPM/scene/play via OSC to osc_bridge.py at ~10 Hz.
-- Uses renoise.Socket.SocketClient + local osc_protocol encoder.

local M = {}
local _client, _host, _port, _running = nil, "", 0, false
local osc_protocol = require "osc_protocol"

local function build_msg()
  local song = renoise.song()
  if not song then return nil end
  local t = song.transport

  local tracks = {}
  for i = 1, #song.tracks do
    local tr = song:track(i)
    tracks[i] = string.format(
      "{\"v\":%.4f,\"m\":%d,\"s\":%d}",
      tr.postfx_volume.value,
      tr.mute_state == renoise.Track.MUTE_STATE_MUTED and 1 or 0,
      (tr.solo_state == true) and 1 or 0
    )
  end
  local tracks_str = "[" .. table.concat(tracks, ",") .. "]"

  return osc_protocol.encode_message("/ai/status", "iiis", {
    math.floor(t.bpm * 10),
    t.playback_pos.sequence,
    t.playing and 1 or 0,
    tracks_str,
  })
end

function M.init(config, ctx)
  _host = config.osc_send_host
  _port = config.osc_send_port

  local client, err = renoise.Socket.create_client(
    _host, _port, renoise.Socket.PROTOCOL_UDP)
  if not client then
    renoise.app():show_warning("AIDJ: failed to create OSC status client: " ..
      tostring(err))
    return
  end
  _client = client
  _running = true
  print("[AIDJ status_publisher] init: client created, adding idle notifier")

  local _tick = 0
  renoise.tool().app_idle_observable:add_notifier(function()
    if not _running or not _client then return end
    _tick = _tick + 1
    if _tick % 60 == 1 then
      print("[AIDJ status_publisher] idle tick", _tick, "running:", _running)
    end
    local payload = build_msg()
    if payload then
      local ok, sErr = _client:send(payload)
      if not ok and _tick % 120 == 1 then
        print("[AIDJ status_publisher] send err:", tostring(sErr))
      end
    end
  end)
end

function M.deinit()
  _running = false
  if _client then _client:close() end
  _client = nil
end

return M