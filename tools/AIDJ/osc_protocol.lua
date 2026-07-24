-- osc_protocol.lua
-- Minimal OSC 1.0 encoder/decoder supporting only "i" (int32) and "s" (string).
-- No external dependencies (no bit library) for max portability.

local M = {}

local function pad4(s)
  local n = #s % 4
  if n == 0 then return s end
  return s .. string.rep("\0", 4 - n)
end

local function encode_int32(v)
  if type(v) ~= "number" or v ~= math.floor(v) or
     v < -2147483648 or v > 2147483647 then
    error("OSC int32 must be an integer in int32 range")
  end
  -- wrap to unsigned 32-bit
  if v < 0 then v = v + 4294967296 end
  local b3 = math.floor(v / 16777216) % 256
  local b2 = math.floor(v / 65536) % 256
  local b1 = math.floor(v / 256) % 256
  local b0 = v % 256
  return string.char(b3, b2, b1, b0)
end

local function decode_int32(s, offset)
  if offset + 3 > #s then error("truncated OSC int32") end
  local b3, b2, b1, b0 = string.byte(s, offset, offset + 3)
  local v = b3 * 16777216 + b2 * 65536 + b1 * 256 + b0
  if v >= 2147483648 then v = v - 4294967296 end
  return v, offset + 4
end

local function decode_string(s, offset)
  if offset < 1 or offset > #s then error("missing OSC string") end
  local nul = string.find(s, "\0", offset, true)
  if not nul then error("unterminated OSC string") end
  local str = string.sub(s, offset, nul - 1)
  offset = nul + 1
  while (offset - 1) % 4 ~= 0 do
    offset = offset + 1
  end
  if offset > #s + 1 then error("truncated OSC string padding") end
  return str, offset
end

local function encode_string(s)
  if type(s) ~= "string" then error("OSC string must be a string") end
  if string.find(s, "\0", 1, true) then error("OSC string contains NUL") end
  return pad4(s .. "\0")
end

function M.encode_message(path, types, args)
  if type(path) ~= "string" or string.sub(path, 1, 1) ~= "/" then
    error("OSC path must start with /")
  end
  local body = encode_string(path) .. encode_string("," .. types)
  for i = 1, #types do
    local t = types:sub(i, i)
    if t == "i" then
      body = body .. encode_int32(args[i])
    elseif t == "s" then
      body = body .. encode_string(args[i])
    else
      error("unsupported OSC type tag: " .. tostring(t))
    end
  end
  return body
end

function M.decode_message(data)
  local offset = 1
  local path, off2 = decode_string(data, offset)
  if string.sub(path, 1, 1) ~= "/" then error("invalid OSC path") end
  offset = off2
  local typesig, off3 = decode_string(data, offset)
  if string.sub(typesig, 1, 1) ~= "," then error("invalid OSC type tag string") end
  offset = off3
  local types = typesig:sub(2, -1)
  local args = {}
  for i = 1, #types do
    local t = types:sub(i, i)
    if t == "i" then
      local v, off = decode_int32(data, offset)
      table.insert(args, v)
      offset = off
    elseif t == "s" then
      local v, off = decode_string(data, offset)
      table.insert(args, v)
      offset = off
    else
      error("unsupported OSC type tag: " .. tostring(t))
    end
  end
  return path, types, args
end

return M
