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

-- WSL IP auto-detection:
-- osc_bridge.py writes host/state/wsl_ip.txt on startup. If that file is
-- accessible from the Renoise tool's bundle_path (../../../), use it.
-- Falls back to 127.0.0.1 for non-WSL setups.
local function detect_wsl_ip(tool_root)
  local f = io.open(tool_root .. "/../../../host/state/wsl_ip.txt", "r")
  if f then
    local ip = f:read("*l")
    f:close()
    if ip and #ip > 0 then
      print("[AIDJ config] detected WSL IP: " .. ip)
      return ip
    end
  end
  print("[AIDJ config] WSL IP file not found, using 127.0.0.1")
  return "127.0.0.1"
end

function M.init(tool_root)
  M.osc_send_host = detect_wsl_ip(tool_root)
end

return M