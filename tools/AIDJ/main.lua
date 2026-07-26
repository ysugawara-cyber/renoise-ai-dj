-- main.lua
-- Entry point. Renoise loads this file from the tool root.
-- Tool registration via renoise.tool():add_menu_entry uses main.lua (not manifest).

-- Expose tool directory so submodules can require each other relatively.
local tool_dir = renoise.tool().bundle_path
package.path = package.path .. ";" .. tool_dir .. "/?.lua"

local config = require "config"
config.init(tool_dir)
package.aidj = package.aidj or {}
package.aidj.config = config

local osc_server     = require "osc_server"
local pattern_writer = require "pattern_writer"
local scene_launcher = require "scene_launcher"
local status_pub    = require "status_publisher"
local midi_router   = require "midi_router"
local cue_router    = require "cue_router"
local grid_ctl      = require "grid_controller"

local _running = false

--------------------------------------------------------------------------------
-- registration
--------------------------------------------------------------------------------

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Start Session",
  invoke = function() start_session() end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Stop Session",
  invoke = function() stop_session() end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Setup:Build Turnkey Song (Fresh Song Only)",
  invoke = function()
    local path = renoise.tool().bundle_path .. "setup/build_turnkey_song.lua"
    local ok, err = pcall(dofile, path)
    if not ok then
      renoise.app():show_warning("AIDJ turnkey build failed. Use Undo. " .. tostring(err))
    end
  end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Setup:Build or Extend 16-Scene Skeleton",
  invoke = function()
    local path = renoise.tool().bundle_path .. "setup/build_track_skeleton.lua"
    local ok, err = pcall(dofile, path)
    if not ok then
      renoise.app():show_warning("AIDJ skeleton failed: " .. tostring(err))
    end
  end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Setup:Validate Current Song",
  invoke = function()
    local ok, err = pcall(function()
      local validator = dofile(renoise.tool().bundle_path .. "setup/validate_song.lua")
      validator.run()
    end)
    if not ok then renoise.app():show_warning("AIDJ validation error: " .. tostring(err)) end
  end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Diagnostics:OSC Status",
  invoke = function()
    local status = osc_server.status()
    renoise.app():show_status(
      "AIDJ OSC running=" .. tostring(status.running) ..
      " " .. tostring(status.address) .. ":" .. tostring(status.port) ..
      " received=" .. tostring(status.received) ..
      " last=" .. tostring(status.last_path) ..
      " error=" .. tostring(status.last_error))
  end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Diagnostics:OSC Self Test (BPM 174)",
  invoke = function()
    local ok, err = osc_server.self_test()
    if ok then
      renoise.app():show_status("AIDJ OSC self-test passed: BPM 174")
    else
      renoise.app():show_warning("AIDJ OSC self-test failed: " .. tostring(err))
    end
  end,
}

renoise.tool():add_menu_entry {
  name = "Main Menu:Tools:AIDJ:Diagnostics:OSC Internal Loopback (BPM 175)",
  invoke = function()
    local ok, err = osc_server.loopback_test()
    if ok then
      renoise.app():show_status("AIDJ OSC internal loopback sent: BPM 175")
    else
      renoise.app():show_warning("AIDJ OSC internal loopback failed: " .. tostring(err))
    end
  end,
}

--------------------------------------------------------------------------------
-- lifecycle
--------------------------------------------------------------------------------

function start_session()
  if _running then
    renoise.app():show_status("AIDJ already running")
    return
  end
  _running = true

  local ok, err = pcall(function()
    pattern_writer.init(config, package.aidj)
    scene_launcher.init(config, package.aidj)
    cue_router.init(config, package.aidj)
    midi_router.init(config, package.aidj)
    local status_ok, status_err = status_pub.init(config, package.aidj)
    if not status_ok then error("status publisher: " .. tostring(status_err)) end
    status_pub.set_grid(grid_ctl)
    local osc_ok, osc_err = osc_server.init(config, package.aidj)
    if not osc_ok then error("OSC server: " .. tostring(osc_err)) end
  end)
  if not ok then
    stop_session()
    renoise.app():show_warning("AIDJ session start failed: " .. tostring(err))
    return
  end

  renoise.app():show_status("AIDJ session started (OSC " .. config.osc_listen_host .. ":" ..
    config.osc_listen_port .. ")")
end

function stop_session()
  if not _running then return end
  osc_server.deinit()
  status_pub.deinit()
  midi_router.deinit()
  cue_router.deinit()
  pattern_writer.deinit()
  scene_launcher.deinit()
  _running = false
  renoise.app():show_status("AIDJ session stopped")
end

renoise.tool().app_release_document_observable:add_notifier(function()
  stop_session()
end)
