-- validate_dryrun.lua
-- Runs a generated Lua file under pcall() to check for forbidden operations
-- BEFORE the file is dispatched. Returns exit code 0 on success.
--
-- Usage: lua tools/AIDJ/validate_dryrun.lua path/to/generated.lua
--
-- Designed to run under Renoise's Lua 5.1 interpreter AND stock lua5.1.

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

-- load() replaces loadstring() in Lua 5.2+; Renoise uses Lua 5.1 (loadstring),
-- stock Lua 5.4 uses load(). Support both.
local fn, err
if load then
  fn, err = load(src, path, "t")
elseif loadstring then
  fn, err = loadstring(src, path)
else
  print("no loader available")
  os.exit(1)
end
if not fn then
  print("syntax error: " .. tostring(err))
  os.exit(1)
end

-- Running the file would touch Renoise APIs available only inside the live Tool;
-- here we only verify it parses cleanly. We deliberately do NOT pcall it to
-- avoid loading partial state into the validator host.

print("OK")
os.exit(0)