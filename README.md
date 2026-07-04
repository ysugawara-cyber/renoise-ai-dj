# AIDJ Live Performance System

AI 駆動の DJ ライブパフォーマンスシステム: **Renoise**(トラッカー DAW) + **opencode**(複数 TUI の AI ライブコーダー) + **AKAI MIDImix** + **APC mini mk2**。

ジャンル: ブレイクコア / ハードコア・テクノ、120–240 BPM、デュアルプロジェクター(Renoise UI + opencode TUI)。

## クイックスタート

```sh
# 1. APC mini mk2 を Generic MIDI モードで電源オン(起動時キーコンボ手動切替)
# 2. AKAI MIDImix を電源オン
# 3. Zoom H4essential を USB 接続(オーディオインターフェースモード)

# 4. Renoise 起動:
#    - AIDJ テンプレート XRNS をロード
#    - ~/.renoise/MIDI Maps/AIDJ_APC_MIDImix.xml をコピーして読み込み
#    - Tools -> AIDJ -> Start Session

# 5. 初回のみ venv セットアップ + bridge 起動
python3 -m venv host/.venv
host/.venv/bin/pip install python-osc pyyaml mido python-rtmidi
host/.venv/bin/python host/osc/osc_bridge.py

# 6. 各ターミナルで TUI を 4 ロール起動
opencode --agent dj_live_pads      # TUI#1 パッド/SE
opencode --agent dj_live_bass_fx   # TUI#2 ベース/FX
opencode --agent dj_live_drums     # TUI#3 ドラム
opencode --agent dj_conductor      # TUI#4 指揮
```

詳細は `docs/`(操作マニュアル、投影セットアップ、検証手順)を参照してください。

## 構成

```
opencode.json              opencode ランタイム設定
AGENTS.md                  エージェントプロジェクトガイド
.opencode/
  agents/                  ロール定義(固定 4 TUI ロール)
    dj_live_pads.md         TUI#1 パッド / SE       (tracks 5,6,8)
    dj_live_bass_fx.md      TUI#2 ベース / FX        (tracks 3,4,7)
    dj_live_drums.md        TUI#3 パーカッション / ドラム (tracks 1,2)
    dj_conductor.md         TUI#4 グローバル指揮     (global)
  rules/                   music / OSC / MIDI 制約ルール
  commands/                /aidj-launch / /aidj-pattern TUI コマンド
host/
  osc/osc_bridge.py        opencode <-> Renoise OSC ブローカー
  osc/send.py              ワンショット送信ヘルパー
  state/session.json       共有セッション状態(ロック + ステータス)
  midi_maps/               Renoise MIDI Mapping XML
tools/AIDJ/                Renoise Lua Tool
  main.lua / osc_server.lua / pattern_writer.lua ...
  validate_dryrun.lua      生成 Lua のガード
  setup/                   セットアップヘルパー
config/                    YAML 設定(macros / scenes / fx_mapping)
prompts/                   自然言語プロンプトライブラリ
docs/                      操作マニュアル / 投影 / フェイルバック / 検証
```

## TUI 起動方法

- 全 TUI は **日本語自然言語** プロンプトを受け付けます。必ず日本語で返答すること。
- 各 TUI は `opencode --agent <role>` で起動(起動後 `/<role>` で切替も可能):

  | ターミナル | ロール | tracks | 担当 |
  |------------|--------|--------|------|
  | 1 | `dj_live_pads`    | 5, 6, 8 | パッド / SE |
  | 2 | `dj_live_bass_fx` | 3, 4, 7 | ベース / FX |
  | 3 | `dj_live_drums`   | 1, 2    | ドラム / パーカッション |
  | 4 | `dj_conductor`    | -       | グローバル指揮 |

## ステータス

本リポジトリは **P1** 初期スキャフォールド。ライブ上演前に要確認の項目は
`docs/verification.md` にまとめている。主なもの:

- AIDJ Renoise テンプレート XRNS(`tools/AIDJ/setup/build_track_skeleton.lua` で
  8 sequencer track + 5 scene の骨格を自動生成、楽器/CUE bus/FX は手動)
- APC トランスポートボタンの Note 番号(ファーム依存; Renoise の MIDI Mapping パネル "Learn" で確認)
- APC LED のベロシティパレットを実機検証
- int×1000 OSC 通信路(swing / pan / fx_param / fx_macro)の roundtrip 検証

## 運用ルール

- コード言及時は常に `file_path:line_number` を添える。
- `session.json` は bridge が所有し agents は直接編集禁止。行ロックのみ `fcntl` 排他ロック経由で編集可。
- WSL 再起動後は `osc_bridge.py` を再起動すれば IP 自動検出される（`tools/AIDJ/config.lua` も `host/state/wsl_ip.txt` から自動読み込み）。
