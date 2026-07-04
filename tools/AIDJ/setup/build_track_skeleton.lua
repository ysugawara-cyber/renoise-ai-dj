-- build_track_skeleton.lua
-- Renoise 上で dofile するセットアップヘルパー。Tools -> Show Script Editor &
-- Run で実行、または Development Tools の Lua Console から:
--   dofile(renoise.tool().bundle_path .. "/setup/build_track_skeleton.lua")
--
-- 生成するもの:
--   1) 8 つの Sequencer Track(drums / breaks / bass / lead / pads / stabs / fx / vox)
--   2) 5 つの Pattern + Pattern Sequence slot(scenes.yaml と対応)
--   3) 各 Pattern の行数を 256 (16 steps x 16 lines) に設定
--
-- 手動で残す作業:
--   - 楽器 / サンプルを各トラックに割当
--   - CUE bus(Send Track) を 9 番に追加し、各トラックの #Send デバイスでルーティング
--   - FX デバイス(#Compressor / #Reverb / #Distortion 等)を fx_mapping.yaml の順に挿入
--   - テンプレートを .xrns として File -> Save As で保存

local TRACKS = {
  {name = "drums",  color = {0xFF, 0x88, 0x44}},
  {name = "breaks", color = {0xCC, 0xCC, 0xAA}},
  {name = "bass",   color = {0x22, 0xCC, 0xCC}},
  {name = "lead",   color = {0xEE, 0x33, 0x66}},
  {name = "pads",   color = {0x88, 0x66, 0xFF}},
  {name = "stabs",  color = {0xAA, 0x22, 0xFF}},
  {name = "fx",     color = {0x66, 0xEE, 0xAA}},
  {name = "vox",    color = {0xEE, 0xEE, 0x88}},
}

local SCENES = {
  {name = "intro_amen_loop",      pattern_lines = 256},
  {name = "drop1_breakcore_full", pattern_lines = 256},
  {name = "hardcore_kick_run",    pattern_lines = 256},
  {name = "breakdown_ambient",    pattern_lines = 256},
  {name = "outro_distorted",      pattern_lines = 256},
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

local function ensure_tracks()
  local have = count_seq_tracks()
  if have >= 8 then
    log("sequencer tracks already " .. have .. ", skip insert")
    return
  end
  local song = renoise.song()
  local master_idx = #song.tracks
  while count_seq_tracks() < 8 do
    song:insert_track_at(master_idx)
  end
  log("inserted up to 8 sequencer tracks")
end

local function name_and_color_tracks()
  local song = renoise.song()
  for i, t in ipairs(TRACKS) do
    local ok, tr = pcall(function() return song:track(i) end)
    if not ok or not tr then
      log("track " .. i .. " not found, naming skipped")
    else
      tr.name = t.name
      if tr.color then
        tr.color = t.color
      end
    end
  end
  log("track names + colors set")
end

local function ensure_scenes()
  local song = renoise.song()
  local seq = song.sequencer
  local pat_seq = seq.pattern_sequence
  if #pat_seq >= #SCENES then
    log("pattern_sequence has " .. #pat_seq .. " slots, skip")
    return
  end
  local need = #SCENES - #pat_seq
  for _ = 1, need do
    local new_idx = seq:insert_new_pattern_at(#pat_seq + 1)
    local pat = song:pattern(new_idx)
    if pat and pat.number_of_lines ~= PATTERN_LINES then
      pcall(function() pat.number_of_lines = PATTERN_LINES end)
    end
  end
  log("added " .. need .. " scenes (256-line patterns) to pattern_sequence")
end

local function main()
  if not renoise or not renoise.song() then
    print("AIDJ skeleton: no renoise.song() available; run inside Renoise")
    return
  end
  log("start")
  ensure_tracks()
  name_and_color_tracks()
  ensure_scenes()
  log("done -- manual steps: instruments, CUE bus (#9), FX devices, save as .xrns")
  renoise.app():show_status(
    "AIDJ skeleton built. See log for manual steps (instruments, CUE bus, FX).")
end

local ok, err = pcall(main)
if not ok then
  renoise.app():show_warning("AIDJ skeleton failed: " .. tostring(err))
end