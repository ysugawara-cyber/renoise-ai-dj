local SEQUENCER, MASTER, SEND = 1, 2, 3

local patterns = {{is_empty = true, number_of_lines = 64, name = ""}}
local tracks = {
  {type = SEQUENCER, name = "", color = {}},
  {type = SEQUENCER, name = "", color = {}},
  {type = SEQUENCER, name = "", color = {}},
  {type = SEQUENCER, name = "", color = {}},
  {type = MASTER, name = "Master", color = {}},
}
local sequence = {1}
local sequencer = {pattern_sequence = sequence}

function sequencer:pattern(slot)
  return self.pattern_sequence[slot]
end

function sequencer:insert_new_pattern_at(slot)
  table.insert(patterns, {is_empty = true, number_of_lines = 64, name = ""})
  local index = #patterns
  table.insert(self.pattern_sequence, slot, index)
  return index
end

local song = {tracks = tracks, sequencer = sequencer}

function song:track(index)
  return self.tracks[index]
end

function song:pattern(index)
  assert(patterns[index], "invalid pattern " .. tostring(index))
  return patterns[index]
end

function song:insert_track_at(index)
  local master_index = nil
  for i, track in ipairs(self.tracks) do
    if track.type == MASTER then master_index = i end
  end
  local kind = index >= master_index and SEND or SEQUENCER
  local track = {type = kind, name = "", color = {}}
  table.insert(self.tracks, index, track)
  return track
end

renoise = {
  Track = {
    TRACK_TYPE_SEQUENCER = SEQUENCER,
    TRACK_TYPE_MASTER = MASTER,
    TRACK_TYPE_SEND = SEND,
  },
  song = function() return song end,
  tool = function() return {bundle_path = "tools/AIDJ/"} end,
  app = function()
    return {
      show_status = function() end,
      show_warning = function(_, message) error(message) end,
    }
  end,
}

dofile("tools/AIDJ/setup/build_track_skeleton.lua")
local spec = dofile("tools/AIDJ/setup/spec.lua")

local sequencer_tracks = 0
for _, track in ipairs(song.tracks) do
  if track.type == SEQUENCER then sequencer_tracks = sequencer_tracks + 1 end
end
assert(sequencer_tracks == 8, "expected 8 sequencer tracks")
assert(#song.sequencer.pattern_sequence == 16, "expected 16 sequence slots")
for slot = 1, 16 do
  local pattern = song:pattern(song.sequencer:pattern(slot))
  assert(pattern.number_of_lines == 256, "pattern length mismatch")
  assert(pattern.name == spec.scenes[slot], "pattern name mismatch")
end
for index, name in ipairs(spec.tracks) do
  assert(song.tracks[index].name == name, "track name mismatch")
end
assert(#song.tracks == 9 and song.tracks[9].type == MASTER, "track structure mismatch")
assert(#patterns == 16, "expected 16 patterns")
print("OK: skeleton")
