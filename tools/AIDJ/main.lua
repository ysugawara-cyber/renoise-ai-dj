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
  name = "Main Menu:Tools:AIDJ:Reload Generated Lua",
  invoke = function() reload_generated() end,
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

  pattern_writer.init(config, package.aidj)
  scene_launcher.init(config, package.aidj)
  cue_router.init(config, package.aidj)
  midi_router.init(config, package.aidj)
  status_pub.init(config, package.aidj)
  status_pub.set_grid(grid_ctl)
  osc_server.init(config, package.aidj)

  renoise.app():show_status("AIDJ session started (OSC 127.0.0.1:" ..
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

function reload_generated()
  local path = tool_dir .. "/generated"
  local cmd
  if package.config:sub(1, 1) == "\\" then
    cmd = 'dir /b "' .. path .. '\\*.lua"'
  else
    cmd = 'ls "' .. path .. '/*.lua" 2>/dev/null'
  end
  local pipe = io.popen(cmd)
  if not pipe then return end
  local lines = {}
  for line in pipe:lines() do
    local full = path .. "/" .. line
    local ok, err = pcall(dofile, full)
    if not ok then
      renoise.app():show_warning("Reload failed: " .. full .. ": " .. tostring(err))
    end
  end
  pipe:close()
end

renoise.tool().app_release_document_observable:add_notifier(function()
  stop_session()
end)