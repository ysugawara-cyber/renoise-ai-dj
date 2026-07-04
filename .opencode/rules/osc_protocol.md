# OSC Protocol

opencode <-> osc_bridge.py <-> Renoise Lua Tool (UDP at 127.0.0.1:8080).
Renoise's built-in OSC server (port 8000) handles only `/renoise/song/...` standard paths; we run our own Luasocket-based receiver inside the Tool on port **8080** to accept custom `/ai/*` paths.

> **Type constraint**: `tools/AIDJ/osc_protocol.lua` decodes **only `i` (int32) and `s` (string)** (OSC 1.0). Any `f:` path below receives an empty arg on the Renoise side and falls back to the handler default. Send continuous values as scaled integers (e.g. `swing*1000`) until float support is added.

## Transport control
| OSC path              | args            | purpose                          |
|-----------------------|-----------------|----------------------------------|
| `/ai/transport`        | s: "play"\|"stop"\|"loop_on"\|"loop_off" | transport            |
| `/ai/bpm`             | i: int (bpm*1)  | set tempo (120..240)            |
| `/ai/swing`           | i: int (swing*1000, 0..1000)  | global groove amount (Renoise: groove_amounts, all 4 sub)             |

## Scene / pattern
| OSC path              | args            | purpose                          |
|-----------------------|-----------------|----------------------------------|
| `/ai/scene`           | i: int (1..N)   | sequence block / scene launch    |
| `/ai/pattern/write`   | s: track_id, s: instrument, s: note_index, s: note, i: vel, s: fx_cmds | write one row to a pattern |
| `/ai/pattern/clear`   | s: track_id, i: start_row, i: row_count | clear range of rows         |
| `/ai/pattern/lock`    | s: track_id, s: tui_id, i: row        | acquire a row lock (requests tui coordination) |

## Note injection
| OSC path              | args                                | purpose                       |
|-----------------------|-------------------------------------|-------------------------------|
| `/ai/note`            | s: track_id, s: note("C-4"), i: velocity, i: length_lines | one-shot pattern-line write at current playback pos |

## Mixer
| OSC path              | args            | purpose                          |
|-----------------------|-----------------|----------------------------------|
| `/ai/mixer/volume`    | s: track_id, i: int (vol*1000, 0..1000)   | set track volume                |
| `/ai/mixer/pan`       | s: track_id, i: int (pan*1000, -1000..1000)  | set track pan                   |
| `/ai/mixer/mute`      | s: track_id, i: 0\|1   | mute / unmute                   |
| `/ai/mixer/solo`      | s: track_id, i: 0\|1   | solo / unsolo                   |
| `/ai/mixer/cue`       | s: track_id, i: 0\|1   | route to CUE bus (R-06)         |

## FX
| OSC path                | args                                 | purpose                       |
|-------------------------|--------------------------------------|-------------------------------|
| `/ai/fx/param`          | s: track_id, i: fx_index, i: param_index, i: int (value*1000, 0..1000) | set FX parameter value |
| `/ai/fx/macro`          | s: macro_name, i: int (value*1000, 0..1000)              | named macro (see config/macros.yaml) |

## LED feedback (Renoise -> APC)
| OSC path              | args                      | purpose                          |
|-----------------------|---------------------------|----------------------------------|
| `/ai/led`             | i: pad_index(0..63), i: velocity(0..127), i: color_mode (0..3) | drive APC pad LED via Note On |

## Status broadcast (Renoise Tool -> osc_bridge.py, ONE bundle, ~10 Hz)
| OSC path                | args                                                   |
|-------------------------|--------------------------------------------------------|
| `/ai/status`            | i: bpm_x10, i: active_scene, i: play_state(0/1), s: tracks_json |

`osc_bridge.py` listens on `127.0.0.1:8088` for these broadcasts and updates
`host/state/session.json`.

## Latency contract
- Code generation -> file dispatch: < 2 s end-to-end (LLM response + Lua reload).
- One-shot `/ai/note`: < 50 ms from opencode intent to OSC packet on the wire.

## Dry-run validation
- Every generated Lua file MUST be passed to `tools/AIDJ/validate_dryrun.lua` before loading.
- The validator performs only a string-pattern scan for forbidden tokens and a `loadstring` syntax check. It does NOT detect deprecated Renoise APIs or guard `session.json` writes — those are enforced by convention elsewhere.
- The validator returns non-zero on any of:
  - syntax error (caught by `loadstring`)
  - references to `os.execute` / `io.popen` / `io.read` / `io.open` / `os.remove` / `os.rename`
  - `require` of a non-`http` module (string-match only)
- On non-zero exit, the agent MUST NOT send the OSC dispatch; it should fix and retry once.

## Payload format for `osc_bridge.py`
opencode writes JSON files to `host/osc/outbox/*.json`, one per OSC message:
```jsonc
{
  "id": "uuid",
  "ts": 1719344400123,
  "tui_id": "tui1",
  "path": "/ai/pattern/write",
  "args": ["1", "KCK01", "00", "C-4", 120, "0Cxx"]
}
```
`osc_bridge.py` consumes outbox files in alphabetical order, sends via python-osc, then moves them to `host/osc/sent/`.