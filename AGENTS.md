# AIDJ Live — エージェントガイド

本リポジトリで動作する全 opencode TUI 向けの共有ルール(簡潔版)。
`opencode.json` の `instructions` により、以下のファイルと一緒に自動ロードされる:
- `.opencode/rules/osc_protocol.md`   — OSC パス一覧 / outbox 形式 / dry-run バリデータ / レイテンシ契約
- `.opencode/rules/midi_mapping.md`   — APC mini mk2 / MIDImix の CC/Note 割当
- `.opencode/rules/music_constraints.md` — ジャンル / テンポ / ドラム・ベース・アレンジ制約
- `.opencode/agents/<role>.md`        — 各 TUI のトラック所有権とロールプロンプト

セットアップ手順・プリフライト・フェイルバック・投影構成は `README.md` と `docs/` を参照のこと。

## 言語
- 全 TUI は日本語の自然言語入力を受け付ける。
- 返答は必ず日本語で行うこと。

## トラック所有権(固定 4-TUI 構成)
| TUI | role | tracks |
|-----|------|--------|
| tui1 | `dj_live_pads`    | 5, 6, 8 |
| tui2 | `dj_live_bass_fx` | 3, 4, 7 |
| tui3 | `dj_live_drums`   | 1, 2    |
| tui4 | `dj_conductor`    | -       |

自分のロール外のトラックに書き込んではいけない。他 TUI への要望は `tui4` (conductor) 経由、
もしくは `host/osc/outbox/` に OSC JSON を置くことで振る。

## ディスパッチモデル(バイパス禁止)
- 全 OSC は `host/osc/outbox/<ts>_<hash>.json` に `tui_id` を付与した JSON を書くことで送出する。
  `host/osc/osc_bridge.py` が消費して Renoise Lua Tool (127.0.0.1:8080) へ送る。
  Renoise ビルトイン OSC(8000) は使わない。
  エージェントからソケットを直接開いてはいけない。
- 1 発ノート(`/ai/note`)も outbox 経由。ファイル書込まで 50 ms 以内を目指す。
- `host/osc/send.py` は人間用デバッグヘルパー(`tui_id` を書かない)。TUI は直接 outbox に JSON を書くこと。

## 稼働前提
- `osc_bridge.py` が未起動の場合 outbox JSON は Renoise に届かず静かに滞留する（最大の footgun）。
- 初回セットアップ: `python3 -m venv host/.venv && host/.venv/bin/pip install python-osc pyyaml mido python-rtmidi`
- 起動: `host/.venv/bin/python host/osc/osc_bridge.py`（repo root から）

## 行ロック調停
- パターン行を書き込む前に `host/state/session.json` の
  `tracks.<id>.locked_rows` に自分の `tui_id` で行ロックを取得すること。
- `session.json` は `osc_bridge.py` が Renoise のステータス broadcast で約 10 Hz で更新する。
  編集する場合は `host/state/session.lock` に対して `fcntl` 排他ロックを取得すること
  (`host/osc/osc_bridge.py` 参照)。ロックなしで上書きするとステータス更新と競合して消える。
- フィールド所有権(README の「直接編集禁止」と整合):
  - bridge が所有(agents は触らない): `bpm` / `active_scene` / `play_state` /
    `tracks.<id>.{volume,mute,solo}`(10 Hz 上書き)
  - agents が編集してよい: `tracks.<id>.locked_rows` と `tui_instances` のみ
  - いずれの書込も `session.lock` の `fcntl` 排他ロックを取得してから行うこと。

## 生成 Lua
- 生成した全 Lua はディスパッチ前に必ず
  `lua tools/AIDJ/validate_dryrun.lua <file>` を通すこと。
  非 0 終了時: 1 庠だけ修正リトライし、それでも失敗したらバリデータ出力を表示して停止。
- 生成ファイルは `tools/AIDJ/generated/` へ。
  禁止パターン(`validate_dryrun.lua` 準拠): `os.execute` / `io.popen` / `io.read` /
  `io.open` / `os.remove` / `os.rename` / 非 http の `require`。

## ステータス行(サブ投影用)
- 各アクション後に 1 行を出力: `## <tui_id> <動詞> <トラック|-> <詳細>` (80 桁以内)。
  サブプロジェクターがこれを解析する。複数行や `## ` プレフィックス欠落は投影を壊す。

## 環境上の注意点
- `opencode.json` で `permission: bash/edit/write/read = allow` を全局設定済み。
  意図なく各ロールでダウングレードしないこと。
- `watcher.ignore` に `host/state/**` / `host/osc/outbox/**` / `tools/AIDJ/generated/**` / `*.xrns` が含まれる。
  これらへのファイル書込はリロードをトリガーしない。
- `default_agent` は `dj_live_pads`。`--agent` 指定なしで起動すると TUI#1 になる。

## 記述規約
- コード言及時は `file_path:line_number` 形式で参照すること。
- 生成 Lua に指示された場合を除きコメントを追加しないこと。
