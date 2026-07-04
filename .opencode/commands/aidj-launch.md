# /aidj-launch

Send a "scene launch" OSC message to Renoise via the bridge's outbox.

Template:
Send `/ai/scene` with the integer argument `$ARGUMENTS` (1..N as declared in config/scenes.yaml).
After dispatching, report a single status line `## $SESSION_TUI_ID launched scene $ARGUMENTS`.

If `$ARGUMENTS` is empty, ask the user "scene id?".
If `$ARGUMENTS` is "next", increment `session.json.active_scene` by 1 and use that.

After sending, refresh `host/state/session.json` by reading it once more and printing
the new `active_scene` short line.