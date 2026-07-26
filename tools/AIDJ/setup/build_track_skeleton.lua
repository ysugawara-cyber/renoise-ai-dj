-- build_track_skeleton.lua
-- Renoise 上で dofile するセットアップヘルパー。Tools -> Show Script Editor &
-- Run で実行、または Development Tools の Lua Console から:
--   dofile(renoise.tool().bundle_path .. "/setup/build_track_skeleton.lua")
--
-- 生成するもの:
--   1) 8 つの Sequencer Track(drums / breaks / bass / lead / pads / stabs / fx / vox)
--   2) 16 個の Pattern + Pattern Sequence slot(scenes.yaml と対応)
--   3) 各 Pattern の行数を 256 (16 steps x 16 lines) に設定
--
-- 手動で残す作業:
--   - 楽器 / サンプルを各トラックに割当
--   - CUE bus(Send Track) を Master 後(通常 track 10)に追加し、各トラックをルーティング
--   - FX デバイス(#Compressor / #Reverb / #Distortion 等)を fx_mapping.yaml の順に挿入
--   - テンプレートを .xrns として File -> Save As で保存

local spec = dofile(renoise.tool().bundle_path .. "setup/spec.lua")
local COLORS = {
  {0xFF, 0x88, 0x44}, {0xCC, 0xCC, 0xAA}, {0x22, 0xCC, 0xCC}, {0xEE, 0x33, 0x66},
  {0x88, 0x66, 0xFF}, {0xAA, 0x22, 0xFF}, {0x66, 0xEE, 0xAA}, {0xEE, 0xEE, 0x88},
}

local PATTERN_LINES = 256

local function log(msg)
  print("[AIDJ skeleton] " .. msg)
end

local function count_seq_tracks()
  local n = 0
  for _, tr in ipairs(renoise.song().tracks) do
    if tr.type == renoise.Track.TRACK_TYPE_SEQUENCER then
      n = n + 1
    end
  end
  return n
end

local function is_blank_song()
  local song = renoise.song()
  local sequence = song.sequencer.pattern_sequence
  if #sequence ~= 1 or count_seq_tracks() > 8 then return false end
  local pattern_index = song.sequencer:pattern(1)
  return pattern_index ~= nil and song:pattern(pattern_index).is_empty
end

local function ensure_tracks()
  local have = count_seq_tracks()
  if have >= 8 then
    log("sequencer tracks already " .. have .. ", skip insert")
    return
  end
  local song = renoise.song()
  while count_seq_tracks() < 8 do
    local master_idx = nil
    for index, track in ipairs(song.tracks) do
      if track.type == renoise.Track.TRACK_TYPE_MASTER then master_idx = index end
    end
    if not master_idx or master_idx < 2 then error("invalid Master Track position") end
    local inserted = song:insert_track_at(master_idx - 1)
    if inserted.type ~= renoise.Track.TRACK_TYPE_SEQUENCER then
      error("failed to insert Sequencer Track")
    end
  end
  log("inserted up to 8 sequencer tracks")
end

local function name_and_color_tracks()
  local song = renoise.song()
  for i, name in ipairs(spec.tracks) do
    local ok, tr = pcall(function() return song:track(i) end)
    if not ok or not tr then
      log("track " .. i .. " not found, naming skipped")
    else
      tr.name = name
      if tr.color then
        tr.color = COLORS[i]
      end
    end
  end
  log("track names + colors set")
end

local function ensure_scenes(initialize_existing)
  local song = renoise.song()
  local seq = song.sequencer
  local pat_seq = seq.pattern_sequence
  local original_count = #pat_seq
  local need = math.max(0, #spec.scenes - #pat_seq)
  local inserted_patterns = {}
  for _ = 1, need do
    local slot = #seq.pattern_sequence + 1
    local new_pattern_index = seq:insert_new_pattern_at(slot)
    inserted_patterns[slot] = new_pattern_index
    local pat = song:pattern(new_pattern_index)
    if pat and pat.number_of_lines ~= PATTERN_LINES then
      pat.number_of_lines = PATTERN_LINES
    end
  end
  pat_seq = seq.pattern_sequence
  for slot = 1, math.min(#pat_seq, #spec.scenes) do
    local pattern_index = inserted_patterns[slot] or seq:pattern(slot)
    local pat = pattern_index and song:pattern(pattern_index) or nil
    local recover_partial = slot > 5 and pat and pat.is_empty and (pat.name or "") == ""
    if pat and (initialize_existing or slot > original_count or recover_partial) then
      pat.number_of_lines = PATTERN_LINES
      pat.name = spec.scenes[slot]
    end
  end
  log("added " .. need .. " scenes; existing patterns preserved=" .. tostring(not initialize_existing))
end

local function main()
  if not renoise or not renoise.song() then
    print("AIDJ skeleton: no renoise.song() available; run inside Renoise")
    return
  end
  log("start")
  local initialize_existing = is_blank_song()
  ensure_tracks()
  if initialize_existing then name_and_color_tracks() end
  ensure_scenes(initialize_existing)
  log("done -- manual steps: instruments, CUE bus (normally #10), FX devices, save as .xrns")
  renoise.app():show_status(
    "AIDJ skeleton built. See log for manual steps (instruments, CUE bus, FX).")
end

local ok, err = pcall(main)
if not ok then
  renoise.app():show_warning("AIDJ skeleton failed: " .. tostring(err))
  error(err, 0)
end
