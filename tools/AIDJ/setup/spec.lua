local M = {}

M.tracks = {"drums", "breaks", "bass", "lead", "pads", "stabs", "fx", "vox"}
M.instruments = {
  "Kick Generator",
  "Break - Bangy Bangy",
  "Diode 03",
  "Tension",
  "Lucid Dream",
  "Arp Saw Square",
  "Harsh Noise",
  "tv_set_mono",
}
M.scenes = {
  "intro_amen_loop", "drop1_breakcore_full", "hardcore_kick_run", "breakdown_ambient",
  "outro_distorted", "jungle_switch", "gabber_pressure", "vox_break",
  "crossbreed_drive", "amen_overload", "industrial_halfstep", "rave_stab_run",
  "noise_transition", "hardcore_peak", "final_break", "encore",
}
M.fx = {
  [1] = {"Audio/Effects/Native/Compressor", "Audio/Effects/Native/Reverb"},
  [2] = {"Audio/Effects/Native/Distortion 2", "Audio/Effects/Native/Delay"},
  [3] = {"Audio/Effects/Native/Digital Filter"},
  [5] = {"Audio/Effects/Native/Reverb"},
  [7] = {
    "Audio/Effects/Native/Reverb",
    "Audio/Effects/Native/Delay",
    "Audio/Effects/Native/Cabinet Simulator",
  },
}
M.master_fx = {"Audio/Effects/Native/Digital Filter"}
M.send_device = "Audio/Effects/Native/#Send"

return M
