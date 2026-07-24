-- osc_server.lua
-- Receives OSC messages via UDP (port from config.osc_listen_port) and dispatches.
-- Renoise's built-in OSC only handles /renoise/song/... standard paths; to
-- accept custom /ai/* paths we run our own UDP listener via renoise.Socket.

local M = {}
local _server, _handlers = nil, {}
local osc_protocol = require "osc_protocol"
local SIGNATURES = {
  ["/ai/transport"] = "s", ["/ai/bpm"] = "i", ["/ai/swing"] = "i",
  ["/ai/scene"] = "i", ["/ai/pattern/write"] = "ssssis",
  ["/ai/pattern/clear"] = "sii", ["/ai/pattern/lock"] = "ssi",
  ["/ai/note"] = "ssii", ["/ai/mixer/volume"] = "si",
  ["/ai/mixer/pan"] = "si", ["/ai/mixer/mute"] = "si",
  ["/ai/mixer/solo"] = "si", ["/ai/mixer/cue"] = "si",
  ["/ai/fx/param"] = "siii", ["/ai/fx/macro"] = "si",
}

local function register(path, fn)
  _handlers[path] = fn
end

local function validate_values(path, args)
  if path == "/ai/bpm" and (args[1] < 120 or args[1] > 240) then
    error("bpm out of range")
  elseif path == "/ai/swing" and (args[1] < 0 or args[1] > 1000) then
    error("swing out of range")
  elseif path == "/ai/scene" and args[1] < 1 then
    error("scene out of range")
  elseif path == "/ai/transport" and
         args[1] ~= "play" and args[1] ~= "stop" and
         args[1] ~= "loop_on" and args[1] ~= "loop_off" then
    error("invalid transport state")
  end
end

function M.dispatch(path, args, types)
  local h = _handlers[path]
  if h then
    if types ~= SIGNATURES[path] then
      error("invalid OSC signature for " .. path .. ": " .. tostring(types))
    end
    validate_values(path, args)
    h(args)
  else
    print("AIDJ: no handler for " .. tostring(path))
  end
end

function M.init(config, ctx)
  local pw = require "pattern_writer"
  local sl = require "scene_launcher"
  local cr = require "cue_router"

  register("/ai/transport", function(a)
    local state = a[1]
    local t = renoise.song().transport
    if state == "play" then
      t:start(1)
    elseif state == "stop" then
      t:stop()
    elseif state == "loop_on" then
      t.loop_pattern = true
    elseif state == "loop_off" then
      t.loop_pattern = false
    end
  end)

  register("/ai/bpm", function(a)
    renoise.song().transport.bpm = math.max(120, math.min(240, tonumber(a[1]) or 174))
  end)

  register("/ai/swing", function(a)
    local v = math.max(0, math.min(1, (tonumber(a[1]) or 0) / 1000))
    local t = renoise.song().transport
    t.groove_enabled = true
    t.groove_amounts = {v, v, v, v}
  end)

  register("/ai/scene", function(a) sl.launch(a[1]) end)

  register("/ai/pattern/write", function(a)
    pw.write_row(a[1], a[2], a[3], a[4], a[5], a[6])
  end)
  register("/ai/pattern/clear", function(a) pw.clear_range(a[1], a[2], a[3]) end)
  register("/ai/pattern/lock",  function(a) pw.lock_row(a[1], a[2], a[3]) end)

  register("/ai/note", function(a)
    pw.one_shot(a[1], a[2], a[3], a[4])
  end)

  register("/ai/mixer/volume", function(a) pw.set_volume(a[1], a[2]) end)
  register("/ai/mixer/pan",    function(a) pw.set_pan(a[1], a[2]) end)
  register("/ai/mixer/mute",   function(a) pw.set_mute(a[1], a[2]) end)
  register("/ai/mixer/solo",   function(a) pw.set_solo(a[1], a[2]) end)
  register("/ai/mixer/cue",    function(a) cr.set_cue(a[1], a[2]) end)

  register("/ai/fx/param", function(a) pw.set_fx_param(a[1], a[2], a[3], a[4]) end)
  register("/ai/fx/macro", function(a) pw.set_macro(a[1], a[2]) end)

  local server, err = renoise.Socket.create_server(
    config.osc_listen_host, config.osc_listen_port, renoise.Socket.PROTOCOL_UDP)
  if not server then
    renoise.app():show_warning("AIDJ: failed to open OSC server on port " ..
      config.osc_listen_host .. ":" .. config.osc_listen_port .. ": " .. tostring(err))
    return nil, tostring(err)
  end

  server:run({
    socket_message = function(socket, data)
      local ok, path, types, args = pcall(osc_protocol.decode_message, data)
      if ok and path then
        local dispatched, dispatch_err = pcall(M.dispatch, path, args, types)
        if not dispatched then
          print("AIDJ: OSC handler error " .. tostring(path) .. ": " .. tostring(dispatch_err))
        end
      elseif not ok then
        print("AIDJ: OSC decode error: " .. tostring(path))
      end
    end,
    socket_error = function(error_message)
      renoise.app():show_warning("AIDJ: socket err: " .. tostring(error_message))
    end,
  })

  _server = server
  ctx.osc_server = server
  renoise.app():show_status("AIDJ OSC server listening on " ..
    config.osc_listen_host .. ":" .. config.osc_listen_port)
  return true
end

function M.deinit()
  if _server then
    _server:stop()
    _server:close()
    _server = nil
  end
end

return M
