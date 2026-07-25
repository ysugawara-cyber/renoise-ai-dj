-- config.lua
-- Lua-side config loader for the AIDJ Tool. main.lua requires this.

local M = {
  osc_listen_host = "127.0.0.1",
  osc_listen_port = 8080,
  osc_send_port    = 8088,
  track_instruments = {
    [1] = "Kick Generator",
    [2] = "Break - Bangy Bangy",
    [3] = "Diode 03",
    [4] = "Tension",
    [5] = "Lucid Dream",
    [6] = "Arp Saw Square",
    [7] = "Harsh Noise",
    [8] = "tv_set_mono",
  },
}

local function valid_ipv4(value)
  local a, b, c, d = string.match(value or "", "^(%d+)%.(%d+)%.(%d+)%.(%d+)$")
  if not a then return false end
  for _, octet in ipairs({a, b, c, d}) do
    local n = tonumber(octet)
    if not n or n < 0 or n > 255 then return false end
  end
  return true
end

-- osc_bridge.py writes wsl_ip.txt into the tool directory on startup.
-- Read it from our own bundle_path if available.
local function detect_wsl_ip(tool_root)
  local f = io.open(tool_root .. "/wsl_ip.txt", "r")
  if f then
    local ip = f:read("*l")
    f:close()
    ip = ip and string.match(ip, "^%s*(.-)%s*$") or nil
    if ip and valid_ipv4(ip) then
      renoise.app():show_status("[AIDJ config] detected WSL IP: " .. ip)
      return ip
    end
    renoise.app():show_warning("[AIDJ config] invalid wsl_ip.txt")
  end
  renoise.app():show_status("[AIDJ config] wsl_ip.txt not found, using 127.0.0.1")
  return "127.0.0.1"
end

function M.init(tool_root)
  M.osc_send_host = detect_wsl_ip(tool_root)
  local f = io.open(tool_root .. "/osc_bind_host.txt", "r")
  if f then
    local host = f:read("*l")
    f:close()
    if host == "127.0.0.1" or host == "0.0.0.0" then
      M.osc_listen_host = host
    else
      renoise.app():show_warning("AIDJ: invalid osc_bind_host.txt; using 127.0.0.1")
    end
  end
end

return M
