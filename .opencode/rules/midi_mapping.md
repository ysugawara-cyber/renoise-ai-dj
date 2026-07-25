# MIDI Mapping

Renoise Lua Tool (`midi_router.lua`) が全 MIDI 入出力を直接ハンドルする。
Renoise の MIDI Map XML は使用しない（Lua 側で完結）。

## APC mini mk2

- USB MIDI bus: `APC mini mk2`
- モード: デフォルト（Ableton Live 互換モード）。特別な電源投入キーコンボ不要。
- 全コントロールは Port 0, MIDI CH 0。

### パッドグリッド (8×8)

- **Step mode (既定)**: 64 pad = 選択Trackの64 line。押下でnoteをtoggle。
- 4 bankで256 lineをカバー: bank 1=0–63、2=64–127、3=128–191、4=192–255。
- **Perform mode**: 再生中のみ有効。column 1–8 = Track 1–8、row = pitch。
  空きnote column 2–12へ短いone-shotを書き、通過後に自動消去する。
- MODE切替はFADER CTRL 8 (note 107)。
- SHIFT中は最上段で編集Track 1–8、2段目左4padでbank 1–4を選択する。

- 計算式: `note = (7 - row) * 8 + col`
- パッド押下時: Note On (0x90), note 0–63, vel 127
- パッド解放時: Note Off (0x80)

### SCENE LAUNCH ボタン (右側縦 8 個)

| ボタン | ノート | 用途 |
|--------|--------|------|
| 1 (上) | 112 | Scene 1 / SHIFT: Scene 9 |
| 2 | 113 | Scene 2 / SHIFT: Scene 10 |
| 3 | 114 | Scene 3 / SHIFT: Scene 11 |
| 4 | 115 | Scene 4 / SHIFT: Scene 12 |
| 5 | 116 | Scene 5 / SHIFT: Scene 13 |
| 6 | 117 | Scene 6 / SHIFT: Scene 14 |
| 7 | 118 | Scene 7 / SHIFT: Scene 15 |
| 8 (下) | 119 | Scene 8 / SHIFT: Scene 16 |

### FADER CTRL ボタン (パッド下横 8 個)

| ボタン | ノート | 用途 |
|--------|--------|------|
| 1 (左) | 100 | **Transport Play** |
| 2 | 101 | **Transport Stop** |
| 3 | 102 | Pattern Loop toggle |
| 4 | 103 | Previous Scene |
| 5 | 104 | Next Scene |
| 6 | 105 | Previous 64-line bank |
| 7 | 106 | Next 64-line bank |
| 8 | 107 | Step/Perform mode / SHIFT: clear selected bank (3秒以内に2回) |

### SHIFT ボタン

| ノート | 用途 |
|--------|------|
| 122 | Track/bank選択、Scene 9–16、bank clearのmodifier |

### フェーダー (右側縦 9 本)

| フェーダー | CC | 用途 |
|-----------|-----|------|
| 1 (上) | 48 | Track 1 Volume |
| 2 | 49 | Track 2 Volume |
| 3 | 50 | Track 3 Volume |
| 4 | 51 | Track 4 Volume |
| 5 | 52 | Track 5 Volume |
| 6 | 53 | Track 6 Volume |
| 7 | 54 | Track 7 Volume |
| 8 | 55 | Track 8 Volume |
| 9 (マスター/下) | 56 | Master Volume |

- 値域: 0–127 (絶対位置)
- 内部変換: `msg.value * 1000 / 127` (int×1000 規約)

### LED フィードバック

APC mini mk2 公式プロトコル (v1.0) 準拠:

- **RGB パッド**: `0x96, pad_index(0–63), color_velocity`
  - `0x96` = MIDI CH 6 = ソリッド点灯 100% 輝度
  - `pad_index` = ノート番号 (0–63)
  - 色は velocity で指定（規定パレット、変更不可）
  - `0x15` (21) = 緑 (#00FF00)
  - `0x00` = 消灯
  - その他の色: プロトコル文書の Velocity to RGB Color Chart 参照
- Step mode: 緑=note、赤=`OFF`/playhead。Perform mode: amber、押下中=赤。
- SHIFT overlay: 最上段の赤=選択Track、2段目の赤=選択bank。
- **単色 LED (SCENE LAUNCH 等)**: `0x90, button_value, behavior`
  - `0x00` = 消灯, `0x01`/`0x03–0x7F` = 点灯, `0x02` = 点滅
- **SysEx RGB**: 任意色指定可能（プロトコル文書 §RGB LED Color Lighting）

## AKAI MIDImix

- USB MIDI bus: `MIDI Mix`
- 全コントロールは Port 0, MIDI CH 0。

### MUTE ボタン (下段横 8 個)

| ボタン | ノート | Track |
|--------|--------|-------|
| 1 (左) | 1 | 1 (drums) |
| 2 | 4 | 2 (breaks) |
| 3 | 7 | 3 (bass) |
| 4 | 10 | 4 (lead) |
| 5 | 13 | 5 (pads) |
| 6 | 16 | 6 (stabs) |
| 7 | 19 | 7 (fx) |
| 8 (右) | 22 | 8 (vox) |

- 計算式: `track = floor((note - 1) / 3) + 1`
- 動作: 押下ごとに mute トグル

### 上段ノブ: Track Pan

| Track | CC |
|-------|----|
| 1–8 | `16,20,24,28,46,50,54,58` |

### 中段ノブ: Track CUE Level

| Track | CC |
|-------|----|
| 1–8 | `17,21,25,29,47,51,55,59` |

### 下段ノブ: Global/FX Macro

| ノブ | CC | 効果 |
|------|----|------|
| 1 | 18 | BPM 120–240 |
| 2 | 22 | Swing 0–1 |
| 3 | 26 | Master Pan |
| 4 | 30 | Track 7 Reverb |
| 5 | 48 | Track 7 Delay |
| 6 | 52 | Master Filter |
| 7 | 56 | Track 2 Distortion |
| 8 | 60 | Track 7 Bitcrush |

- 値域: 0–127
- 内部変換: `msg.value * 1000 / 127` (int×1000 規約)

### REC/ARM (SOLO) ボタン

- Note: `3,6,9,12,15,18,21,24`
- 計算式: `track = floor((note - 1) / 3) + 1`
- 動作: 押下ごとに solo トグル

### フェーダー

- Track 1-8: CC `19,23,27,31,49,53,57,61`
- Master: CC `62`
- 値域: 0-127。Lua側でint×1000へ変換。

### 注意事項

- MIDImix を Renoise の **MIDI Input デバイスとして設定しない**こと（Edit → Preferences → MIDI）。
  Lua tool が直接ハンドルするため、Renoise ネイティブ MIDI 入力と競合しノートが発音される。
- MIDImix のノブ CC 番号は機体によって異なる可能性あり。上記と異なる場合は
  Outputタブで実CCを確認し`midi_router.lua`の`pan_cc`/`cue_cc`/`macro_cc`を修正する。
