for index = 1, #arg do
  local chunk, err = loadfile(arg[index])
  assert(chunk, arg[index] .. ": " .. tostring(err))
end
print("OK: syntax")
