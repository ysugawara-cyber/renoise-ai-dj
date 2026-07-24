-- validate_dryrun.lua
-- Scans forbidden tokens and checks Lua syntax without executing the target.
-- Returns exit code 0 on success. Kept under the historical dry-run name.
--
-- Usage: lua tools/AIDJ/validate_dryrun.lua path/to/generated.lua
--
-- Supports Lua 5.1 (loadstring) and Lua 5.2+ (load).

local FORBIDDEN = {
  "os%.execute", "io%.popen", "io%.read",
  "require%s*%(?%s*['\"]http",
  "os%.remove", "os%.rename", "io%.open",
}

if #arg < 1 then
  print("usage: validate_dryrun.lua <file.lua>")
  os.exit(2)
end

local path = arg[1]
local f = io.open(path, "r")
if not f then
  print("cannot read " .. path)
  os.exit(2)
end
local src = f:read("*a")
f:close()

for _, pat in ipairs(FORBIDDEN) do
  if string.find(src, pat) then
    print("forbidden pattern found: " .. pat)
    os.exit(1)
  end
end

local function check_syntax(source, chunk_name)
  if loadstring then
    return loadstring(source, chunk_name)
  end
  if load then
    return load(source, chunk_name, "t")
  end
  return nil, "no loader available"
end

local fn, err = check_syntax(src, path)
if not fn then
  print("syntax error: " .. tostring(err))
  os.exit(1)
end

-- Never call fn: generated code is not executed by this validator.

print("OK")
os.exit(0)
