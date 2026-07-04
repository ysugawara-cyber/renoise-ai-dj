# docs/operator_manual.md

# AIDJ Live — Operator Manual

## 0. One-time setup (WSL side)

```sh
# from repo root (inside WSL)
python3 -m venv host/.venv
host/.venv/bin/pip install --upgrade pip
host/.venv/bin/pip install python-osc pyyaml mido python-rtmidi
```

This creates `host/.venv/` with `python-osc` installed. All `host/osc/*` scripts
MUST be invoked with `host/.venv/bin/python` (not system `python3`) so they find
the `pythonosc` package.

## 1. Pre-flight (~5 minutes before doors)

1. **Power up MIDI hardware**
   - APC mini mk2: hold Generic-MIDI-mode key combo at power-on (stop+pad per
     current Akai manual; verify against installed firmware).
   - AKAI MIDImix: standard USB power, no mode switch.
2. **Connect audio**
   - Zoom H4essential via USB; mode = "Audio Interface".
   - Plug DJ headphones into **PC headphone jack** (this is the CUE bus).
   - Plug H4essential headphone out into SR system (this is Main).
3. **Launch Renoise**
   - Load AIDJ template XRNS. (初回のみ `docs/verification.md` §5 の手順で
     `tools/AIDJ/setup/build_track_skeleton.lua` を実行して骨格を生成・保存)
   - Tools -> AIDJ -> **Start Session**.
     This opens a Luasocket UDP server on **127.0.0.1:8080** for custom `/ai/*` OSC.
     Renoise's built-in OSC server (port 8000) is NOT used by AIDJ and can stay off.
   - MIDI panel: load `AIDJ_APC_MIDImix.xml` from `~/.renoise/MIDI Maps/`.
   - Audio panel: confirm Main Bus -> H4essential, CUE Bus -> PC headphone.
4. **Launch OSC bridge** (run in WSL, from repo root)
   ```sh
   host/.venv/bin/python host/osc/osc_bridge.py
   ```
   Verify "osc_bridge started -- target 127.0.0.1:8080" prints.
5. **Launch opencode TUIs** (one per terminal, 4 fixed roles)
   ```sh
   # terminal 1 - パッド / SE
   opencode --agent dj_live_pads
   # terminal 2 - ベース / FX
   opencode --agent dj_live_bass_fx
   # terminal 3 - パーカッション / ドラム
   opencode --agent dj_live_drums
   # terminal 4 - グローバル指揮
   opencode --agent dj_conductor
   ```
   Each TUI should announce itself in `host/state/session.json` as
   `tui1`..`tui4` (matches its role file).
   All TUIs accept **Japanese natural language** prompts (日本語で入力してください)。

## 2. Projection setup

- **Main projector**: capture Renoise window (window-capture source in OBS,
  or NDI Scan Converter `Renoise`).
- **Sub projector**: capture the opencode TUI terminal window(s) (window-capture
  in OBS). Use high-contrast syntax themes (`tokyonight` is in `tui.json`).
- **HUD overlay (optional)**: add a Text source in OBS reading
  `host/state/session.json` via a tiny Node script or a `tail -F` shell command.

## 3. Live operation

- Type **Japanese** natural-language prompts into opencode TUIs. Examples:
  - 「次の 8 小節: レイヤーした amen + サブベース」
  - 「BPM を 16 小節かけて 180 から 210 までランプ」(conductor へ)
  - 「ここで 4 小節ドラムをカット」(drums へ)
  - 「リードにフィルタースイープ 0 -> 1 を 4 小節」(bass_fx へ)
  - 「パッドにリバーブを 60%」(pads へ)
- Physical control:
  - **APC** row 0 pads: launch pattern slots 1-8 (matches scenes.yaml).
  - **APC** sliders: adjust Track 1-8 volume.
  - **MIDImix** faders: per-track FX (macro bank B is FX row 2).
  - **MIDImix** knobs 1-8: global macros (bpm, swing, sends, etc).
  - **MIDImix** MUTE/SOLO buttons: track mute / solo.

## 4. Fallback procedures

| Situation | Response |
|---|---|
| One opencode TUI frozen | Kill that terminal only. Other TUIs + Renoise keep running. Restart that TUI when convenient. |
| Renoise unresponsive | File -> Save As (if possible); otherwise `kill` only Renoise, then reopen and resume from `session.json`. |
| MIDI controller disconnected | Unplug/replug USB; reload MIDI map from Renoise MIDI Mapping panel. |
| Hard panic | MIDImix master to -inf; APC stop pad; resolve smoke before resume. |
| Sound lost completely | Check PC headphone still routed; check H4essential blue "AUDIO I/F" indicator. |

## 5. End of set

1. opencode TUIs: send `/ai/transport stop`.
2. esc_bridge: Ctrl-C.
3. Renoise: Tools -> AIDJ -> **Stop Session**.
4. Save the XRNS with a timestamped name for archive.
5. Backup `host/state/session.json` to docs/set-archive/<date>.json.