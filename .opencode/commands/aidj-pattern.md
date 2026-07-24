---
description: Generate and atomically queue a pattern for the active role's owned track
---

# /aidj-pattern

Generate a pattern payload for the current owned track and dispatch it.

Template:
1. Identify the owned track from the active role definition in `.opencode/agents/`.
2. Parse the user's `$ARGUMENTS` for:
   - duration in bars (default 4)
   - instrument column (default the first owned track)
   - description (free text music instruction)
3. Build one `/ai/pattern/write` message per row with arguments
   `[track, instrument, note_index, note, velocity, fx_cmds]`.
4. Publish through `host.osc.message_queue.queue_message()` so every outbox file is atomic.
5. Resolve the fixed `tui_id` from the active role and print one line: `## <tui_id> wrote <track_id> <bars>-bar pattern`.

Examples the user might say:
- /aidj-pattern 4 bars of layered amen with snare at beat 4
- /aidj-pattern 8 bars of offbeat reese in C, sidechain to kick
