-- config.lua
-- Lua-side config loader for the AIDJ Tool. main.lua requires this.

local M = {
  osc_listen_port = 8080,
  osc_status_port  = 8088,
  osc_send_port    = 8088,
  session_state_path = "host/state/session.json",
  log_path            = "logs/aidj.log",
  cue_bus_track_index = 9,
  dry_run_default     = true,
}

-- osc_bridge.py writes wsl_ip.txt into the tool directory on startup.
-- Read it from our own bundle_path if available.
local function detect_wsl_ip(tool_root)
  local f = io.open(tool_root .. "/wsl_ip.txt", "r")
  if f then
    local ip = f:read("*l")
    f:close()
    if ip and #ip > 0 then
      renoise.app():show_status("[AIDJ config] detected WSL IP: " .. ip)
      return ip
    end
  end
  renoise.app():show_status("[AIDJ config] wsl_ip.txt not found, using 127.0.0.1")
  return "127.0.0.1"
end

function M.init(tool_root)
  M.osc_send_host = detect_wsl_ip(tool_root)
end

return M