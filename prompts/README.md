# AIDJ Prompt Library

ライブ中にそのまま各OpenCode TUIへ貼り付ける日本語prompt集。

| File | Purpose |
|---|---|
| `prompts/live_quickref.md` | 演奏中に短文を即座に貼る |
| `prompts/library.md` | Track生成、修正、FX、転換を用途から選ぶ |
| `prompts/session_flow.md` | 16 Sceneを使ったセット全体の進行例 |

## Paste Destination

| TUI | Agent | Ownership |
|---|---|---|
| TUI#1 | `dj_live_pads` | Track 5 pads、6 stabs、8 vox |
| TUI#2 | `dj_live_bass_fx` | Track 3 bass、4 lead、7 fx |
| TUI#3 | `dj_live_drums` | Track 1 drums、2 breaks |
| TUI#4 | `dj_conductor` | Scene、transport、BPM、global指揮 |

見出しのTUIへ、code block内の1行だけを貼る。所有Trackをまたぐ指示はTUI#4へ貼る。

## Generation Rules

- 空Sceneの標準生成は0–255行、16小節を最後まで展開する。
- 256行Patternを32小節使う場合は同じPatternを2周する。17小節目以降へ直接書かない。
- 短区間編集では`行64〜95`のように0–255内の範囲を明示する。
- TUI#4が仕込みdirectiveを発行した後、TUI#1–3で`/d`を1回ずつ実行する。
- `/ai/pattern/write`はScene IDを持たない。別Sceneの事前仕込みは必ず停止中に対象Sceneへ切り替えてから行う。
- 演奏中は現在再生中のSceneだけを修正する。非アクティブSceneを裏で生成しない。
- Scene/BPM/muteの即時操作はTUI#4へ直接指示する。
- Instrument名を指定する場合はRenoise上の実名を使用する。

## Instrument Map

| Track | Instrument |
|---|---|
| 1 | `Kick Generator` |
| 2 | `Break - Bangy Bangy` |
| 3 | `Diode 03` |
| 4 | `Tension` |
| 5 | `Lucid Dream` |
| 6 | `Arp Saw Square` |
| 7 | `Harsh Noise` |
| 8 | `tv_set_mono` |
