# docs/projection_setup.md

# Projection Setup — AIDJ Live (2 system: Main + Sub)

## Hardware routing overview

- **Main projector** displays Renoise (the user interface of the DAW).
- **Sub projector** displays the opencode TUI(s) (the AI live coder windows).
- These are two separate physical video outputs on the performance machine.
  Recommended: dedicated GPU with 2+ HDMI/DP outputs.

## Output map

| Output | Source | Content |
|---|---|---|
| HDMI/DP #1 -> Main projector | Renoise window | Pattern editor + Disk Browser panels |
| HDMI/DP #2 -> Sub projector | opencode TUI terminal(s) | AI agent activity, command input, code diffs |

## Capture options

### Option A: OBS Studio (recommended, free)

1. Open OBS Studio.
2. Create a scene "Main" and add a **Window Capture** source -> select Renoise window.
3. Create a scene "Sub" and add another **Window Capture** source -> select the opencode TUI terminal.
4. Set OBS outputs: main to Fullscreen Projector on Monitor #1; sub to Fullscreen Projector on Monitor #2.
5. Resolution: match projector native (e.g., 1920x1080 or 1280x800).
6. Frame rate: 30 fps is sufficient; performance over motion smoothness.

### Option B: NDI Scan Converter (lower latency for HD-SDI setups)

1. Install NDI Tools.
2. Run NDI Scan Converter.
3. In Renoise: keep window title unique (e.g., set skin name); ensure the
   scan converter picks it up.
4. Repeat for each opencode TUI terminal window.
5. On the vision mixer / projector feed: pick NDI sources by name.

### Option C: Single machine, hardware display clone

- Skip OBS / NDI. Just drag Renoise to projector #1 and opencode TUIs to projector #2.
- Lower complexity; not capture-based; simpler for smaller venues.

## HUD overlay (optional comparison)

If you want to show audience-facing overlay (BPM, current scene, TUI role):

1. In OBS, add a Text (GDI+) source in "Main" scene.
2. Configure it from a file: `host/state/hud.txt` (suggested 2-3 lines).
3. Refresh every 200 ms via a small script that writes hud.txt from session.json:
   ```sh
   while true; do
     python3 -c "import json, sys; s=json.load(open('host/state/session.json'));
     open('host/state/hud.txt','w').write(f\"BPM {s['bpm']}  |  Scene {s['active_scene']}  |  {s['play_state']}\")"
     sleep 0.2
   done
   ```
4. Style the text with a high-contrast outline (white text, black outline, 28 pt).

## Tips for the audience experience

- The sub projector is the more "interesting" AI output: as the AI types out
  generated Lua and Edit/Write tool calls, the audience sees the process.
- Use a high-contrast TUI theme (e.g., tokyonight). Configure in `tui.json`.
- Disable dropdown of menus (set `mouse: false` and `attention.notifications: false`)
  to reduce UI jitter during the set.

## Checklist for showtime

1. Projectors powered, warm.
2. Resolution matches native (so no scaling blur).
3. OBS scene collections `AIDJ_Main.json` and `AIDJ_Sub.json` saved in repo.
4. HUD script (if used) running in tmux.
5. Do a 3-minute tech run: launch bridge, Renoise, opencode; verify both projections
   show expected sources; press a pad and watch APC LED light on Renoise view.