-- config.lua
-- Lua-side config loader for the AIDJ Tool. main.lua requires this.
-- Removed manifest.lua (Renoise only reads manifest.xml); keep config here.

local M = {
  osc_listen_port = 8080,  -- Tool Lua opens this UDP server (NOT Renoise built-in OSC)
  osc_status_port = 8088,
  osc_send_host = "172.26.144.70",  -- WSL IP (Windows -> WSL bridge)
  osc_send_port = 8088,    -- status_publisher sends to osc_bridge.py here
  session_state_path = "host/state/session.json",
  log_path = "logs/aidj.log",
  cue_bus_track_index = 9,
  dry_run_default = true,
}

return M