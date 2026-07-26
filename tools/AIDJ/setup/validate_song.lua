local M = {}

local spec = dofile(renoise.tool().bundle_path .. "setup/spec.lua")

local function find_instrument(song, name)
  for _, instrument in ipairs(song.instruments) do
    if string.lower(instrument.name or "") == string.lower(name) then return instrument end
  end
  return nil
end

local function device_label(path)
  local label = string.lower(string.match(path, "([^/]+)$") or path)
  return string.gsub(label, " simulator$", "")
end

function M.check()
  local song = renoise.song()
  local errors = {}
  if song.sequencer_track_count ~= 8 then
    table.insert(errors, "Exactly 8 sequencer tracks are required")
  end
  if #song.tracks ~= 10 then table.insert(errors, "Exactly 10 total tracks are required") end
  if #song.patterns ~= 16 then table.insert(errors, "Exactly 16 patterns are required") end
  if #song.instruments ~= 8 then table.insert(errors, "Exactly 8 instruments are required") end
  for index, name in ipairs(spec.tracks) do
    local track = song.tracks[index]
    if not track or track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      table.insert(errors, "Track " .. index .. " is not a sequencer track")
    elseif string.lower(track.name or "") ~= name then
      table.insert(errors, "Track " .. index .. " name must be " .. name)
    end
  end
  if #song.sequencer.pattern_sequence ~= 16 then
    table.insert(errors, "Exactly 16 sequence slots are required")
  end
  local assigned_patterns = {}
  for slot = 1, math.min(16, #song.sequencer.pattern_sequence) do
    local pattern_index = song.sequencer:pattern(slot)
    local pattern = song:pattern(pattern_index)
    if assigned_patterns[pattern_index] then
      table.insert(errors, "Scene " .. slot .. " shares a pattern with Scene " .. assigned_patterns[pattern_index])
    end
    assigned_patterns[pattern_index] = slot
    if pattern.number_of_lines ~= 256 then
      table.insert(errors, "Scene " .. slot .. " pattern must have 256 lines")
    end
    if pattern.name ~= spec.scenes[slot] then
      table.insert(errors, "Scene " .. slot .. " pattern name must be " .. spec.scenes[slot])
    end
  end
  for expected_index, name in ipairs(spec.instruments) do
    local instrument = find_instrument(song, name)
    local duplicates = 0
    for _, candidate in ipairs(song.instruments) do
      if string.lower(candidate.name or "") == string.lower(name) then duplicates = duplicates + 1 end
    end
    if not instrument then
      table.insert(errors, "Missing instrument: " .. name)
    else
      local positioned = song.instruments[expected_index]
      if not positioned or string.lower(positioned.name or "") ~= string.lower(name) then
        table.insert(errors, "Instrument " .. expected_index .. " must be " .. name)
      end
      local audible = false
      for _, sample in ipairs(instrument.samples) do
        local mapping = sample.sample_mapping
        if sample.sample_buffer.has_sample_data and mapping.base_note == 48 and
           mapping.note_range[1] <= 48 and mapping.note_range[2] >= 48 and
           sample.volume > 0 and instrument.volume > 0 then
          audible = true
        end
      end
      if not audible then table.insert(errors, "Instrument has no sample data: " .. name) end
      if #instrument.samples ~= 1 or not instrument.samples[1].oneshot then
        table.insert(errors, "Instrument must have exactly one one-shot sample: " .. name)
      end
    end
    if duplicates > 1 then table.insert(errors, "Duplicate instrument name: " .. name) end
  end
  local cue = nil
  for _, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_SEND and string.lower(track.name or "") == "cue" then
      cue = track
      break
    end
  end
  if not cue then table.insert(errors, "Missing CUE Send Track") end
  if song.send_track_count ~= 1 then table.insert(errors, "Exactly one Send Track is required") end
  for index = 1, 8 do
    local track = song.tracks[index]
    local expected_devices = 2 + #(spec.fx[index] or {})
    if track and #track.devices ~= expected_devices then
      table.insert(errors, "Track " .. index .. " must have exactly " .. expected_devices .. " devices")
    end
    local device = track and track.devices[2]
    if not device or device.device_path ~= spec.send_device then
      table.insert(errors, "Track " .. index .. " device 2 must be #Send")
    elseif string.find(device.active_preset_data or "", "<MuteSource>true</MuteSource>", 1, true) then
      table.insert(errors, "Track " .. index .. " #Send must keep the source audible")
    elseif math.floor(device.parameters[3].value + 0.5) ~= 0 then
      table.insert(errors, "Track " .. index .. " #Send must target CUE")
    end
    for offset, path in ipairs(spec.fx[index] or {}) do
      local fx = track and track.devices[offset + 2]
      if not fx or fx.device_path ~= path then
        table.insert(errors, "Track " .. index .. " FX " .. offset .. " must be " .. device_label(path))
      end
    end
  end
  local master = nil
  for _, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_MASTER then master = track end
  end
  for offset, path in ipairs(spec.master_fx) do
    local fx = master and master.devices[offset + 1]
    if not fx or fx.device_path ~= path then
      table.insert(errors, "Master FX " .. offset .. " must be " .. device_label(path))
    end
  end
  if master and #master.devices ~= 1 + #spec.master_fx then
    table.insert(errors, "Master must have exactly " .. (1 + #spec.master_fx) .. " devices")
  end
  if cue and #cue.devices ~= 1 then table.insert(errors, "CUE must have exactly one device") end
  return errors
end

function M.run()
  local errors = M.check()
  if #errors == 0 then
    renoise.app():show_status("AIDJ validation passed: song is turnkey-ready")
    print("AIDJ validation passed")
    return true
  end
  print("AIDJ validation failed:")
  for _, message in ipairs(errors) do print("- " .. message) end
  renoise.app():show_warning("AIDJ validation failed. See Scripting Terminal for details.")
  return false
end

return M
