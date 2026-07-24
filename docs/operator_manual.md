# docs/operator_manual.md

# AIDJ Live — Operator Manual

## 0. One-time setup (WSL side)

```sh
# from repo root (inside WSL)
python3 -m venv host/.venv
host/.venv/bin/pip install --upgrade pip
host/.venv/bin/pip install -r requirements.txt
cp opencode.example.json opencode.json
export AIDJ_RENOISE_TOOL_DIR="/mnt/c/Users/<WindowsUser>/AppData/Roaming/Renoise/V3.5.4/Scripts/Tools/com.aidj.live.xrnx"
export AIDJ_RENOISE_OSC_BIND_HOST=0.0.0.0  # Windows Renoise + WSL bridgeの場合のみ
./tools/install.sh
./start.sh  # bind設定をTool directoryへ永続化
```

This creates `host/.venv/` with `python-osc` installed. All `host/osc/*` scripts
MUST be invoked with `host/.venv/bin/python` (not system `python3`) so they find
the `pythonosc` package.
`osc_bind_host.txt`作成後は、再起動時に上記のbind環境変数を再exportする必要はない。

## 1. Pre-flight / PC 再起動後の起動手順 (~5 minutes before doors)

PC 再起動時はこの順序で起動する。**bridge → Renoise の順が重要**
(bridge が起動時に WSL IP を自動検出して `wsl_ip.txt` をツール dir に書き込み、
Renoise ツールはロード時にそれを読む。逆順で Renoise が先に走っていると
古い IP に broadcast し続け、heartbeat が更新されない)。

1. **Power up / connect hardware** (Renoise 起動前に接続すること。
   MIDI デバイスは Start Session 時に掴みに行く)
   - APC mini mk2: USB 接続(デフォルトの Ableton Live 互換モード)。
   - AKAI MIDImix: standard USB power, no mode switch.
   - Zoom H4essential via USB; mode = "Audio Interface".
   - Plug DJ headphones into **PC headphone jack** (this is the CUE bus).
   - Plug H4essential headphone out into SR system (this is Main).
2. **Launch OSC bridge** (WSL, from repo root)
   ```sh
   ./start.sh
   ```
   - bridge は `setsid` でデタッチ起動される(ターミナルを閉じても死なない)。
     ログは `host/state/bridge.log`、PID は `host/state/bridge.pid`。
   - この時点で `[!] Renoise セッション未検出` が出ても正常(Renoise 未起動のため)。
3. **Launch Renoise**
   - 公開版はサンプル入りXRNSを同梱しない。初回のみ`docs/verification.md` §5の手順で
     `tools/AIDJ/setup/build_track_skeleton.lua`を実行し、権利を持つ音源を割り当てて保存する。
   - Tools -> AIDJ -> **Start Session**.
     これで UDP **8080** の `/ai/*` 受信と **8088** への status broadcast (~10 Hz) が始まる。
     Renoise's built-in OSC server (port 8000) is NOT used by AIDJ and can stay off.
   - MIDI panel: Renoise の MIDI Mapping XML は**ロードしない**。
     全 MIDI 入出力は Lua Tool (`tools/AIDJ/midi_router.lua`) が直接ハンドルする。
     APC mini mk2 / MIDImix を Renoise の MIDI Input デバイスに設定してはいけない
     (Lua tool と競合しノートが発音される)。
   - Audio panel: confirm Main Bus -> H4essential, CUE Bus -> PC headphone.
4. **Go / No-Go 確認** (WSL)
   ```sh
   ./start.sh   # 2 回目は bridge 既起動のまま heartbeat チェックだけ行う
   ```
   - `[✓] osc_bridge.py は既に起動中` と
     `[✓] Renoise セッション アクティブ (heartbeat: 0s ago)` の 2 つを確認。
   - 任意: `host/.venv/bin/python host/osc/verify_roundtrip.py` が `4/4 passed` なら
     疎通は完全(track1 の mute/solo/volume と BPM が一瞬変わるので**本番中は実行しない**)。
5. **Launch opencode TUIs** (one per terminal, 4 fixed roles)
   ```sh
   # terminal 1 - グローバル指揮
   opencode --agent dj_conductor
   # terminal 2 - パーカッション / ドラム
   opencode --agent dj_live_drums
   # terminal 3 - ベース / FX
   opencode --agent dj_live_bass_fx
   # terminal 4 - パッド / SE
   opencode --agent dj_live_pads
   ```
   TUI は起動しただけでは動かない。重要なのは bridge と Renoise セッションが
   先に生きていること(bridge 未起動だと outbox の JSON が静かに滞留する)。
   All TUIs accept **Japanese natural language** prompts (日本語で入力してください)。

## 2. Projection setup

- **Main projector**: capture Renoise window (window-capture source in OBS,
  or NDI Scan Converter `Renoise`).
- **Sub projector**: capture the opencode TUI terminal window(s) (window-capture
  in OBS). High-contrast terminal theme is recommended (`tui.json`は同梱しない)。
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
  - **APC** row 0 pads: launch pattern slots 1-5 (6-8は追加slot用)。
  - **APC** sliders: adjust Track 1-8 volume.
  - **MIDImix** faders: Track 1-8 volume、master fader: Master volume。
  - **MIDImix** knobs 1-8: global macros (bpm, swing, sends, etc).
  - **MIDImix** MUTE/SOLO buttons: track mute / solo.

## 4. Fallback procedures

| Situation | Response |
|---|---|
| One opencode TUI frozen | Kill that terminal only. Other TUIs + Renoise keep running. Restart that TUI when convenient. |
| Renoise unresponsive | File -> Save As (if possible); otherwise `kill` only Renoise, then reopen and resume from `session.json`. |
| MIDI controller disconnected | Unplug/replug USB; Renoise で Tools -> AIDJ -> Stop Session -> Start Session でデバイスを再取得(MIDI map XML は使わない)。 |
| Hard panic | MIDImix master to -inf; APC stop pad; resolve smoke before resume. |
| Sound lost completely | Check PC headphone still routed; check H4essential blue "AUDIO I/F" indicator. |

## 5. End of set

1. opencode TUIs: send `/ai/transport stop`.
2. osc_bridge: `kill $(cat host/state/bridge.pid)` (デタッチされているため Ctrl-C は効かない)。
3. Renoise: Tools -> AIDJ -> **Stop Session**.
4. Save the XRNS with a timestamped name for archive.
5. Backup `host/state/session.json` to docs/set-archive/<date>.json.
