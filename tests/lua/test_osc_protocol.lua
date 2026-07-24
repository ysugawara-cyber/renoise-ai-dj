package.path = "tools/AIDJ/?.lua;" .. package.path

local osc = require "osc_protocol"

local function expect_error(label, fn)
  local ok = pcall(fn)
  if ok then error(label .. " did not fail") end
end

local payload = osc.encode_message("/test", "isi", {2147483647, "ok", -2147483648})
local path, types, args = osc.decode_message(payload)
assert(path == "/test")
assert(types == "isi")
assert(args[1] == 2147483647 and args[2] == "ok" and args[3] == -2147483648)

expect_error("unterminated string", function() osc.decode_message("/bad") end)
expect_error("bad typetag", function()
  osc.decode_message(osc.encode_message("/test", "s", {"not-a-tag"}):sub(1, 8) .. "bad\0")
end)
expect_error("unsupported encode type", function() osc.encode_message("/test", "f", {1}) end)
expect_error("truncated int32", function()
  osc.decode_message("/x\0\0,i\0\0\1")
end)

print("OK: osc_protocol")
