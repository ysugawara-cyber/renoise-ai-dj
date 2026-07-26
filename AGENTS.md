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
- 全 OSC は `message_queue.queue_message()` が`host/osc/outbox/<ts>_<hash>.json`へ
  `tui_id`付きJSONをatomic publishすることで送出する。
  `host/osc/osc_bridge.py` が消費して Renoise Lua Tool (127.0.0.1:8080) へ送る。
  Renoise ビルトイン OSC(8000) は使わない。
  エージェントからソケットを直接開いてはいけない。
- 1 発ノート(`/ai/note`)も outbox 経由。ファイル書込まで 50 ms 以内を目指す。
- `host/osc/send.py` は人間用デバッグヘルパー(`tui_id` を書かない)。TUI は
  `host.osc.message_queue.queue_message()` でatomic publishすること。最終`.json`への直接書込は禁止。

## 稼働前提
- `osc_bridge.py` が未起動の場合 outbox JSON は Renoise に届かず静かに滞留する（最大の footgun）。
- 初回セットアップ: `python3 -m venv host/.venv && host/.venv/bin/pip install -r requirements.txt`
- 起動: `./start.sh`（推奨。setsid デタッチ + `host/state/bridge.log` 出力）。
  手動の場合は `setsid -f host/.venv/bin/python -u host/osc/osc_bridge.py >> host/state/bridge.log 2>&1 < /dev/null`。
  素の `&` での起動はターミナル終了時に SIGHUP で bridge が死亡するため禁止。

## 行ロック調停
- パターン書込は必ず`message_queue.queue_message()`へ自分の`tui_id`を渡すこと。
  helperが固定トラック所有権を検証し、`tracks.<id>.locked_rows`へ行ロックを取得する。
- 固定4-TUI構成では同じ`tui_id`を二重起動しない。再生位置で行が決まる`/ai/note`は
  行ロックではなく固定トラック所有権のみで排他する。
- `session.json` は `osc_bridge.py` が Renoise のステータス broadcast (約 10 Hz 受信)
  を 0.5 s 間隔でマージ書き込みする。
  helper以外から編集する場合は `host/state/session.lock` に対して `fcntl` 排他ロックを取得すること
  (`host/osc/osc_bridge.py` 参照)。ロックなしで上書きするとステータス更新と競合して消える。
- フィールド所有権(README の「直接編集禁止」と整合):
  - bridge が所有(agents は触らない): `bpm` / `active_scene` / `play_state` /
    `tracks.<id>.{volume,mute,solo}`(0.5 s 間隔で上書き)
  - agents が編集してよい: `tracks.<id>.locked_rows` と `tui_instances` のみ
  - いずれの書込も `session.lock` の `fcntl` 排他ロックを取得してから行うこと。

## TUI 間指示 (directives)
- conductor (tui4) から各TUIへの音楽的指示は
  `host.osc.directive_queue.publish_directive()`でatomic FIFO発行する(OSCは経由しない)。
- 各TUIは全ユーザー入力の最初に`python3 host/osc/directive_queue.py consume <tui_id>`を
  実行し、全directiveをFIFO順に反映する。OSC queue成功後だけ、consumeが返したtokenを
  `python3 host/osc/directive_queue.py ack <tui_id> <token>`でackする。
  失敗時はackせず次ターンで再試行する(プッシュ通知ではなく次ターン消費)。
- 手動トリガーは各TUIで`/d`を入力する。
- 即時性が必要な操作 (mute / scene / bpm) は従来通り OSC outbox 経由で直接送る。

## 生成 Lua
- 生成した全 Lua はディスパッチ前に必ず
  `lua5.4 tools/AIDJ/validate_dryrun.lua <file>` を通すこと。
  WSL 環境には `/usr/bin/lua5.4` (Lua 5.4) がインストール済み。
  Renoise 内蔵 Lua (5.1) の `loadstring` と Lua 5.4 の `load` の差異は
  `validate_dryrun.lua` が吸収する。
- 生成ファイルは `tools/AIDJ/generated/` へ。
- **デプロイ(重要)**: `tools/AIDJ/*.lua` の編集は、`AIDJ_RENOISE_TOOL_DIR`
  (例: Renoise data dir 配下の `Scripts/Tools/com.aidj.live.xrnx/`)への
  **コピーが別途必要**(コピーデプロイのため、リポジトリの編集だけでは
  実行中ツールに反映されない)。コピー後は Renoise で Stop Session →
  Tools → Scripting → Reload Tools → Start Session。
- 禁止パターン(`validate_dryrun.lua` 準拠): `os.execute` / `io.popen` / `io.read` /
  `io.open` / `os.remove` / `os.rename` / `require` of http modules（ネットワーク呼出防止）。
  標準ライブラリの `require`（例: `require "osc_protocol"`）は許可。
- **パターン書き込み先**: `renoise.song():pattern(N)` はパターンプールの1-based インデックス。
  Renoise 3.5.4で現在のsequence slotに対応するpatternを書くには以下を使うこと:
  ```lua
  local seq_slot = renoise.song().transport.playback_pos.sequence
  local pattern_index = renoise.song().sequencer:pattern(seq_slot)
  local pat = renoise.song():pattern(pattern_index)
  ```
  実装は `tools/AIDJ/pattern_writer.lua` の `cur_pattern_track` を参照。
  **停止中は `playback_pos` の読み書きが Renoise に無視される**ため、シーン slot の取得・
  設定は停止中 `edit_pos` を使うこと(scene_launcher / status_publisher も同じ分岐)。

## ステータス行(サブ投影用)
- 各アクション後に 1 行を出力: `## <tui_id> <動詞> <トラック|-> <詳細>` (80 桁以内)。
  サブプロジェクターがこれを解析する。複数行や `## ` プレフィックス欠落は投影を壊す。

## 環境上の注意点
- tracked `opencode.json`は4 TUIのmodel/variantとライブ運用権限を定義する。
  `opencode.example.json`は`bash`/`edit`を`ask`にした保守的な代替例。いずれにも秘密情報を入れないこと。
- `watcher.ignore` に `host/state/**` / `host/osc/outbox/**` / `tools/AIDJ/generated/**` / `*.xrns` が含まれる。
  これらへのファイル書込はリロードをトリガーしない。
- `default_agent` は `dj_live_pads`。`--agent` 指定なしで起動すると TUI#1 になる。

## 記述規約
- コード言及時は `file_path:line_number` 形式で参照すること。
- 生成 Lua に指示された場合を除きコメントを追加しないこと。
