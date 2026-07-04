# MIDI Mapping (Renoise native MIDI Map XML)

Renoise's MIDI Mapping maps incoming MIDI to internal parameters via `Target -> MIDI binding`
entries in `~/.renoise/MIDI Maps/` (or via the MIDI Mapping panel). We autogenerate the XML.

## APC mini mk2 (Generic MIDI mode)
- Mode: Generic MIDI (manual switch on power-on, see APC manual — hold STOP+PAD combo)
- USB MIDI bus: `APC MINI mk2`
- Pad grid: 8 rows × 8 cols, indexed **row major**, MIDI ch 1 Note numbers:
  - Top-left  = note 56  (row 0, col 0)  (APC v2 native layout, 56-119 range)
  - Bottom-right = note 119 (row 7, col 7)
  - Formula: note = 56 + (row * 8) + col
- Sliders (right side, vertical 8): CC 48..55 on ch 1
- Top knobs (if present): N/A — APC mini has none by default
- Transport buttons: notes are mapped to dedicated Note numbers; will confirm live via Renoise
  MIDI Mapping panel.

### APC mapping (default)
| Control            | MIDI              | Renoise target                                |
|--------------------|-------------------|-----------------------------------------------|
| Pad (row 0..7)     | Note 56..63       | Sequence Pattern slot 1..8 launch (R-03 OSC)  |
| Pad (row 1..7)     | Note 64..119      | Reserved for cue-arm / scene bank select       |
| Slider 1..8        | CC 48..55         | Track 1..8 Volume (R-04)                       |
| Stop (transport)   | Note (TBD)        | Transport Stop                                 |
| Play               | Note (TBD)        | Transport Play                                 |
| Rec                | Note (TBD)        | (unused, reserved)                             |

### LED feedback (Renoise -> APC)
- Pad LEDs are driven by Renoise sending Note On (ch 1) back to the APC.
- Velocity value encodes color/appearance:
  - 0   = LED off
  - 1   = green
  - 3   = green blink
  - 4   = red
  - 6   = red blink
  - see APC Generic MIDI chart in docs for full palette
- Pad-to-LED mapping uses the same Note number: pad Note 56 -> LED Note 56.

## AKAI MIDImix
- USB MIDI bus: `MIDI Mix`
- 4 banks × 8 faders = 24 horizontal faders (CC 7..30, ch 1, per-bank channel offsets apply)
- 8 macro knobs (top row): CC 10..17 on ch 1 (leftmost=10)
- MUTE buttons (8): Note 1..8 on ch 1
- SOLO buttons (8): Note 16..23 on ch 1
- BANK L/R shift: CC 22, CC 25 (on ch 1) — used to scope current bank
- Master slider: CC 7 on ch 1 (or per-bank master)

### MIDImix mapping
| Control               | MIDI              | Renoise target                                  |
|-----------------------|-------------------|-------------------------------------------------|
| Fader bank 1 (1..8)  | CC 7..14, ch 1    | Track volume 1..8                                |
| Fader bank 2 (1..8)  | CC 15..22, ch 1   | FX device param rows (one row per track)        |
| Fader bank 3 (1..8)  | CC 23..30, ch 1   | Linear FX params 9..16 (reverbs/delays)         |
| Macro knobs (1..8)   | CC 10..17, ch 1   | Named global macros (see config/macros.yaml)    |
| MUTE buttons (1..8)  | Note 1..8, ch 1   | Track mute toggle (R-04)                        |
| SOLO buttons (1..8)  | Note 16..23, ch 1 | Track solo toggle (R-04)                        |
| Master slider         | CC 7, ch 1        | Master output (avoid; use APC transport area)    |

### Bank scoping logic
Because the MIDImix surfaces 8 faders per bank but a track usually has 4-8 FX devices with many params,
we use the BANK L/R buttons to "scope" the 24 faders to logical banks:

- BANK A (default): 8 track volumes + 8 FX row 1 + 8 FX row 2
- BANK B:           8 sends + 8 FX row 3 + 8 FX row 4 (future)
- BANK C:           per-track device param page 2 (future)

`osc_bridge.py` watches BANK L/R CC and recalculates the mapping bank state in
`host/state/session.json.active_midimix_bank`.

## XML generation
- Renoise MIDI Mapping uses `MIDI Map.xml` files in:
  - Linux: `~/.renoise/3.4.2/MIDI Maps/`
  - Windows: `%APPDATA%\Renoise\3.4.2\MIDI Maps\`
- The opencode agent (or a python helper) regenerates `AIDJ_APC_MIDImix.xml` on demand.
- Load via Renoise's MIDI Mapping panel before each session.

## Notes
- APC mini mk2 LED palette depends on firmware version; verify the velocity palette
  list on the actual hardware before finalizing `midi_router.lua` color mapping.
- MIDImix has limited factory CC customizability; we trust factory defaults and adjust
  on the Renoise/receive side `notes-by-CC` interpretation.