# AIDJ Controller Map

APC mini mk2とAKAI MIDImixの現在の割当を、実機の配置に沿って確認するための
クイックリファレンス。操作練習は`docs/controller_tutorial.md`、MIDI Note/CCの詳細は
`.opencode/rules/midi_mapping.md`を参照する。

## Track Legend

| Track | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|---|---|---|---|---|---|---|---|---|
| Role | drums | breaks | bass | lead | pads | stabs | fx | vox |

## APC mini mk2

### Physical Overview

Gridは左からTrack/step 1–8、右端はSCENE LAUNCH。表の上段が実機の上側。

| Grid row | Column 1 | Column 2 | Column 3 | Column 4 | Column 5 | Column 6 | Column 7 | Column 8 | Right button |
|---:|---|---|---|---|---|---|---|---|---|
| 1 top | Step +0 | +1 | +2 | +3 | +4 | +5 | +6 | +7 | Scene 1 / SHIFT: 9 |
| 2 | Step +8 | +9 | +10 | +11 | +12 | +13 | +14 | +15 | Scene 2 / SHIFT: 10 |
| 3 | Step +16 | +17 | +18 | +19 | +20 | +21 | +22 | +23 | Scene 3 / SHIFT: 11 |
| 4 | Step +24 | +25 | +26 | +27 | +28 | +29 | +30 | +31 | Scene 4 / SHIFT: 12 |
| 5 | Step +32 | +33 | +34 | +35 | +36 | +37 | +38 | +39 | Scene 5 / SHIFT: 13 |
| 6 | Step +40 | +41 | +42 | +43 | +44 | +45 | +46 | +47 | Scene 6 / SHIFT: 14 |
| 7 | Step +48 | +49 | +50 | +51 | +52 | +53 | +54 | +55 | Scene 7 / SHIFT: 15 |
| 8 bottom | Step +56 | +57 | +58 | +59 | +60 | +61 | +62 | +63 | Scene 8 / SHIFT: 16 |

Stepの実lineは`bank start + Step`。bank startは0、64、128、192。

### Grid Modes

| Mode | Columns | Rows top to bottom | Pad action |
|---|---|---|---|
| Step | 8 steps per row | 64 consecutive pattern lines | Note column 1のnoteをtoggle |
| Perform | Track 1–8 | `C-6, B-5, A-5, G-5, F-5, D#5, D-5, C-5` | 再生中だけ一時one-shot |
| SHIFT overlay | Top row: Track 1–8 | Second row left: bank 1–4 | 編集Track/bankを選択 |

Perform modeの一時noteは空きnote column 2–12へ入り、再生通過後に消える。

### FADER CTRL And SHIFT

| Physical button left to right | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 MODE | SHIFT |
|---|---|---|---|---|---|---|---|---|---|
| Action | Play | Stop | Pattern Loop | Previous Scene | Next Scene | Previous Bank | Next Bank | Step/Perform | Modifier |
| SHIFT action | - | - | - | - | - | - | - | Bank Clear | Track/bank overlay |
| MIDI Note | 100 | 101 | 102 | 103 | 104 | 105 | 106 | 107 | 122 |

Bank Clearは`SHIFT + MODE`を3秒以内に2回押した場合だけ実行される。

### Faders

| Fader left to right | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | Master |
|---|---|---|---|---|---|---|---|---|---|
| Target | Track 1 | Track 2 | Track 3 | Track 4 | Track 5 | Track 6 | Track 7 | Track 8 | Master |
| CC | 48 | 49 | 50 | 51 | 52 | 53 | 54 | 55 | 56 |

### APC LED Legend

| State | LED |
|---|---|
| Step note | Green |
| Step `OFF` / playback position | Red |
| Perform available pad | Amber |
| Perform pad pressed | Red |
| SHIFT selected Track/bank | Red |

## AKAI MIDImix

各列は同じTrack stripを操作する。Master列はMaster faderだけを使用する。

| Physical control | Strip 1 | Strip 2 | Strip 3 | Strip 4 | Strip 5 | Strip 6 | Strip 7 | Strip 8 | Master |
|---|---|---|---|---|---|---|---|---|---|
| Track | drums | breaks | bass | lead | pads | stabs | fx | vox | Master |
| Top knob | Pan CC16 | Pan CC20 | Pan CC24 | Pan CC28 | Pan CC46 | Pan CC50 | Pan CC54 | Pan CC58 | - |
| Middle knob | CUE CC17 | CUE CC21 | CUE CC25 | CUE CC29 | CUE CC47 | CUE CC51 | CUE CC55 | CUE CC59 | - |
| Bottom knob | BPM CC18 | Swing CC22 | Master Pan CC26 | T7 Reverb Send CC30 | T7 Delay Send CC48 | Master Filter Cutoff CC52 | T2 Distortion Drive CC56 | T7 Cabinet Distortion CC60 (`bitcrush`) | - |
| REC/ARM | Solo N3 | Solo N6 | Solo N9 | Solo N12 | Solo N15 | Solo N18 | Solo N21 | Solo N24 | - |
| MUTE | Mute N1 | Mute N4 | Mute N7 | Mute N10 | Mute N13 | Mute N16 | Mute N19 | Mute N22 | - |
| Fader | Volume CC19 | Volume CC23 | Volume CC27 | Volume CC31 | Volume CC49 | Volume CC53 | Volume CC57 | Volume CC61 | Volume CC62 |

### MIDImix LED Legend

| LED | Meaning |
|---|---|
| MUTE on | 対象Trackがmute中 |
| REC/ARM on | 対象Trackがsolo中 |

## Safety

- APC mini mk2とMIDImixをRenoise Preferencesの通常MIDI Inputへ設定しない。
- CUE knobは左端0から上げる。
- BPM、Master Filter、Distortion系macroは小さく動かして確認する。
- APC Bank ClearはコピーしたXRNSで練習する。
