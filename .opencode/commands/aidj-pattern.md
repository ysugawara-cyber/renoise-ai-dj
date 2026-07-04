# /aidj-pattern

Generate a pattern payload for the current owned track and dispatch it.

Template:
1. Identify the user's owned track from `.opencode/agents/dj_live.md`.
2. Parse the user's `$ARGUMENTS` for:
   - duration in bars (default 4)
   - instrument column (default the first owned track)
   - description (free text music instruction)
3. Compose a Lua snippet in `tools/AIDJ/generated/<timestamp>_<hash>.lua`
   that calls pattern_writer.write_row() for each line of the desired pattern.
4. Dry-run validate via `lua tools/AIDJ/validate_dryrun.lua <file>`; if it fails,
   fix and retry once. If it still fails, print the validator output and stop.
5. Generate one OSC payload file to `host/osc/outbox/` per pattern row with
   path `/ai/pattern/write` and arguments `[track, instrument, note_index, note, velocity, fx_cmds]`.
6. Print a single status line `## $SESSION_TUI_ID wrote <bars>-bar pattern on track <n>`.

Examples the user might say:
- /aidj-pattern 4 bars of layered amen with snare at beat 4
- /aidj-pattern 8 bars of offbeat reese in C, sidechain to kick