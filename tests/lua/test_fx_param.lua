local ranged = {value = 1, value_min = 1, value_max = 2000, value_quantum = 1}
local normalized = {value = 0, value_min = 0, value_max = 1, value_quantum = 0}
local send = {value = 127, value_min = 0, value_max = 255, value_quantum = 1}
local track = {
  type = 1,
  devices = {
    {name = "TrackVolPan", parameters = {}},
    {name = "#Send", parameters = {}},
    {name = "Reverb", parameters = {normalized}},
    {name = "Delay", parameters = {ranged, ranged, normalized, normalized, send}},
  },
}
local song = {tracks = {track}}
function song:track(index) return self.tracks[index] end

renoise = {
  Track = {TRACK_TYPE_MASTER = 2},
  song = function() return song end,
}

local writer = dofile("tools/AIDJ/pattern_writer.lua")
assert(writer.set_fx_param("1", 1, 0, 0) and ranged.value == 1)
assert(writer.set_fx_param("1", 1, 0, 1000) and ranged.value == 2000)
assert(writer.set_fx_param("1", 1, 0, 519) and ranged.value == 1038)
assert(writer.set_fx_param("1", 0, 0, 500) and normalized.value == 0.5)
assert(writer.set_fx_param("1", 1, 4, 1000) and send.value == 255)
print("OK: fx_param")
