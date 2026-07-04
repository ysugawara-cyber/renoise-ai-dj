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
  v = math.floor(tonumber(v) or 0)
  -- wrap to unsigned 32-bit
  if v < 0 then v = v + 4294967296 end
  local b3 = math.floor(v / 16777216) % 256
  local b2 = math.floor(v / 65536) % 256
  local b1 = math.floor(v / 256) % 256
  local b0 = v % 256
  return string.char(b3, b2, b1, b0)
end

local function decode_int32(s, offset)
  local b3, b2, b1, b0 = string.byte(s, offset, offset + 3)
  local v = b3 * 16777216 + b2 * 65536 + b1 * 256 + b0
  if v >= 2147483648 then v = v - 4294967296 end
  return v, offset + 4
end

local function decode_string(s, offset)
  local start = offset
  while string.byte(s, offset) ~= 0 do
    offset = offset + 1
  end
  local str = string.sub(s, start, offset - 1)
  offset = offset + 1
  while (offset - 1) % 4 ~= 0 do
    offset = offset + 1
  end
  return str, offset
end

local function encode_string(s)
  return pad4(s .. "\0")
end

function M.encode_message(path, types, args)
  local body = encode_string(path) .. encode_string("," .. types)
  for i = 1, #types do
    local t = types:sub(i, i)
    if t == "i" then
      body = body .. encode_int32(args[i])
    elseif t == "s" then
      body = body .. encode_string(tostring(args[i] or ""))
    end
  end
  return body
end

function M.decode_message(data)
  local offset = 1
  local path, off2 = decode_string(data, offset)
  offset = off2
  local typesig, off3 = decode_string(data, offset)
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
    end
  end
  return path, types, args
end

return M