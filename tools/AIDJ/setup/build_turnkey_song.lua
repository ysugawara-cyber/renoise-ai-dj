local spec = dofile(renoise.tool().bundle_path .. "setup/spec.lua")

local function blank_song_issue(song)
  if song.file_name ~= "" then return "song has already been saved" end
  if #song.sequencer.pattern_sequence ~= 1 then return "sequence slot count is not 1" end
  if #song.patterns ~= 1 then return "pattern count is not 1" end
  if #song.instruments == 0 then return "song has no instrument slots" end
  if song.sequencer_track_count < 1 or song.sequencer_track_count > 8 then
    return "sequencer track count must be between 1 and 8"
  end
  local pattern_index = song.sequencer:pattern(1)
  for index = 1, song.sequencer_track_count do
    local track = song.tracks[index]
    if track.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then return "unexpected Track type" end
    if #track.devices ~= 1 then return "Track " .. index .. " already has devices" end
  end
  local master_count = 0
  for index = song.sequencer_track_count + 1, #song.tracks do
    local track = song.tracks[index]
    if track.type == renoise.Track.TRACK_TYPE_MASTER then
      master_count = master_count + 1
      if #track.devices ~= 1 then return "Master Track already has devices" end
    elseif track.type == renoise.Track.TRACK_TYPE_SEND then
      if #track.devices ~= 1 then return "Send Track " .. index .. " already has devices" end
    else
      return "non-empty Group or unsupported Track exists at " .. index
    end
  end
  if master_count ~= 1 then return "expected exactly one Master Track" end
  local pattern = song:pattern(pattern_index)
  if not pattern.is_empty then return "pattern contains data" end
  for _, pattern_track in ipairs(pattern.tracks) do
    if #pattern_track.automation > 0 then return "pattern contains automation" end
  end
  for index, instrument in ipairs(song.instruments) do
    for _, sample in ipairs(instrument.samples) do
      if sample.sample_buffer.has_sample_data then
        return "instrument " .. index .. " contains sample data"
      end
    end
    if #instrument.phrases ~= 0 then return "instrument " .. index .. " contains phrases" end
    if instrument.plugin_properties.plugin_loaded then
      return "instrument " .. index .. " plugin is loaded"
    end
    if (instrument.midi_output_properties.device_name or "") ~= "" then
      return "instrument " .. index .. " has a MIDI output device"
    end
  end
  return nil
end

local function find_device_path(track, wanted)
  for _, info in ipairs(track.available_device_infos) do
    if info.path == wanted then return wanted end
  end
  return nil
end

local function insert_device(track, path, index)
  local resolved = find_device_path(track, path)
  if not resolved then error("native device unavailable: " .. path) end
  track:insert_device_at(resolved, index or (#track.devices + 1))
end

local function waveform(kind, t, frame)
  local tau = math.pi * 2
  if kind == 1 then
    local frequency = 45 + 110 * math.exp(-t * 24)
    return math.sin(tau * frequency * t) * math.exp(-t * 9)
  elseif kind == 2 then
    local noise = ((frame * 1103515245 + 12345) % 65536) / 32768 - 1
    local pulse = math.exp(-((t % 0.125) * 55))
    return (noise * 0.55 + math.sin(tau * 95 * t) * 0.45) * pulse
  elseif kind == 3 then
    return (2 * ((t * 55) % 1) - 1) * math.exp(-t * 1.8)
  elseif kind == 4 then
    return (2 * ((t * 220) % 1) - 1) * math.exp(-t * 4)
  elseif kind == 5 then
    return (math.sin(tau * 110 * t) + math.sin(tau * 165 * t) * 0.6 +
      math.sin(tau * 220 * t) * 0.35) * 0.45 * math.exp(-t * 0.8)
  elseif kind == 6 then
    return (math.sin(tau * 261.63 * t) + math.sin(tau * 329.63 * t) * 0.7 +
      math.sin(tau * 392 * t) * 0.6) * 0.38 * math.exp(-t * 7)
  elseif kind == 7 then
    local noise = ((frame * 1664525 + 1013904223) % 65536) / 32768 - 1
    return noise * math.exp(-t * 5)
  end
  return (math.sin(tau * 180 * t) * 0.5 + math.sin(tau * 720 * t) * 0.3 +
    math.sin(tau * 1100 * t) * 0.2) * math.exp(-t * 5)
end

local function create_fallback_sample(instrument, kind)
  if #instrument.samples == 0 then instrument:insert_sample_at(1) end
  while #instrument.samples > 1 do instrument:delete_sample_at(#instrument.samples) end
  local sample = instrument.samples[1]
  if sample.sample_buffer.has_sample_data then return end
  local sample_rate = 44100
  local duration = kind == 5 and 1 or 0.25
  local frames = sample_rate * duration
  if not sample.sample_buffer:create_sample_data(sample_rate, 16, 1, frames) then
    error("failed to allocate fallback sample: " .. instrument.name)
  end
  sample.sample_buffer:prepare_sample_data_changes(true)
  local ok, err = pcall(function()
    for frame = 1, frames do
      local value = waveform(kind, (frame - 1) / sample_rate, frame)
      sample.sample_buffer:set_sample_data(1, frame, math.max(-1, math.min(1, value)))
    end
  end)
  sample.sample_buffer:finalize_sample_data_changes()
  if not ok then error(err) end
  sample.name = instrument.name .. " fallback"
  sample.sample_mapping.base_note = 48
  sample.oneshot = true
end

local function ensure_instruments(song)
  while #song.instruments < #spec.instruments do
    song:insert_instrument_at(#song.instruments + 1)
  end
  while #song.instruments > #spec.instruments do
    song:delete_instrument_at(#song.instruments)
  end
  for index, name in ipairs(spec.instruments) do
    local instrument = song.instruments[index]
    instrument.name = name
    create_fallback_sample(instrument, index)
  end
end

local function master_index(song)
  for index, track in ipairs(song.tracks) do
    if track.type == renoise.Track.TRACK_TYPE_MASTER then return index end
  end
  return nil
end

local function ensure_cue_and_fx(song)
  local master = master_index(song)
  if not master then error("master track not found") end
  song:insert_track_at(master + 1)
  local cue = song:track(master + 1)
  if cue.type ~= renoise.Track.TRACK_TYPE_SEND then error("failed to create CUE Send Track") end
  cue.name = "cue"
  cue.color = {0x00, 0xCC, 0xFF}
  for index = 1, 8 do
    local track = song:track(index)
    insert_device(track, spec.send_device, 2)
    local send = track:device(2)
    send.active_preset_data = string.gsub(send.active_preset_data,
      "<MuteSource>true</MuteSource>", "<MuteSource>false</MuteSource>")
    send.parameters[1].value = 0
    send.parameters[3].value = 0
    for _, path in ipairs(spec.fx[index] or {}) do insert_device(track, path) end
  end
  master = master_index(song)
  local master_track = song:track(master)
  for _, path in ipairs(spec.master_fx) do insert_device(master_track, path) end
end

local function remove_initial_send_tracks(song)
  for index = #song.tracks, 1, -1 do
    if song.tracks[index].type == renoise.Track.TRACK_TYPE_SEND then
      song:delete_track_at(index)
    end
  end
end

local function preflight_devices(song)
  local sequencer = song.tracks[1]
  local master = song.tracks[master_index(song)]
  local required = {[spec.send_device] = sequencer}
  for _, paths in pairs(spec.fx) do
    for _, path in ipairs(paths) do required[path] = sequencer end
  end
  for _, path in ipairs(spec.master_fx) do required[path] = master end
  for path, track in pairs(required) do
    if not find_device_path(track, path) then error("native device unavailable: " .. path) end
  end
end

local function main()
  local song = renoise.song()
  local blank_issue = blank_song_issue(song)
  if blank_issue then
    renoise.app():show_warning("AIDJ turnkey build requires a new blank song: " .. blank_issue)
    return
  end
  local choice = renoise.app():show_prompt(
    "Build AIDJ Turnkey Song",
    "Creates 8 tracks, 16 scenes, fallback instruments, CUE and native FX. Continue?",
    {"Build", "Cancel"})
  if choice ~= "Build" then return end
  preflight_devices(song)
  song:describe_undo("AIDJ: Build turnkey song")
  remove_initial_send_tracks(song)
  dofile(renoise.tool().bundle_path .. "setup/build_track_skeleton.lua")
  ensure_instruments(song)
  ensure_cue_and_fx(song)
  if not dofile(renoise.tool().bundle_path .. "setup/validate_song.lua").run() then
    error("turnkey validation failed; use Undo and see Scripting Terminal")
  end
end

main()
