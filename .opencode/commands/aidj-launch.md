---
description: Atomically queue a Renoise scene launch through the OSC bridge
agent: dj_conductor
---

# /aidj-launch

Send a "scene launch" OSC message to Renoise via the bridge's outbox.

Template:
Send `/ai/scene` through `host.osc.message_queue.queue_message()` with integer argument `$ARGUMENTS` (1..N as declared in config/scenes.yaml).
After dispatching, report a single status line `## tui4 launched - scene $ARGUMENTS`.

If `$ARGUMENTS` is empty, ask the user "scene id?".
If `$ARGUMENTS` is "next", increment `session.json.active_scene` by 1 and use that.
