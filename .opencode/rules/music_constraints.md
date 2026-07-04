# Music Constraints

## Genre
- **Primary**: breakcore, hardcore techno, gabber, mainstream hardcore
- **Allowed accents**: amen break edits, rave stabs, distorted kick, reese bass, breakcore snare rushes, offbeat fx
- **Avoid**: melodic EDM drops, tropical house, lo-fi hip-hop drum patterns, four-on-the-floor-only patterns without variation

## Tempo
- Range: **120–240 BPM** (free, may change mid-set)
- Common anchors:
  - 174–180 (typical breakcore / jungle-leaning)
  - 200–220 (hardcore / gabber)
  - 140–145 (half-time hardcore / crossbreed break section)
- Tempo changes should ramp (10 BPM/s max) rather than jump, unless a hard cut is requested.

## Pattern length & time signature
- Pattern resolution: prefer **256 lines** (16 steps × 16 lines) per pattern, or **192 lines** when LPB=4.
- Time signature: 4/4 unless explicitly told otherwise.
- Do not use 3/4 or 7/8 unless the human asks.

## Drum constraints
- Kicks: must have a punchy/exciting body; hardcore sub-bass around 50–80 Hz typical.
- Snares / breaks: amens, "Tramen" edits, snare rushes at offbeats OK.
- Hi-hats: 16th or 32nd; rolls can velocity-shape but not simply fill every line.
- No sustain kicks unless intentionally a half-time section.

## Bass constraints
- Reese / sub-bass recommended for hardcore sections.
- Offbeat bass acceptable but breaks should pair with staggered shifts.
- Avoid trance supersaw progressions.

## Arrangement feel
- Each "scene" should feel like a 1–2 minute section; transitions should feel continuous, not abrupt.
- Breakdown + drop structure is OK but not mandatory; breakcore tradition favors constant energy.

## Velocity & accent rules
- Snares on 2nd/4th beats of a bar should be accented.
- Kicks on 1st/3rd should be loudest.
- Do not fill every pattern line; negative space matters.

## Instrument naming convention (for generated samples/xdls)
- `KCK01` (kick), `SNR01`, `HH01`, `BRK_amen01`, `BAS_reese01`, `LEAD_stab01`, `PAD01`
- Append `_n` for variations.

## Forbidden patterns
- Don't emit automatically generated "clicks" or 1-line notes without sustain context.
- Don't stack KCK on every line (that's an audible click train, not a kick pattern).
- Don't use pitch value 0 (C-0) for melodic content unless intentionally.