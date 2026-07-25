# AIDJ Controller Tutorial

APC mini mk2とAKAI MIDImixの操作を、既存パターンを壊さず段階的に確認する。
最初にXRNSを`AIDJ-controller-practice.xrns`として別名保存すること。

## 0. Preparation

1. APC mini mk2とMIDImixをUSB接続する。
2. Renoise Preferencesの通常MIDI Inputから両デバイスを外す。
3. `Tools -> AIDJ -> Start Session`を実行する。
4. Master volumeを低めにする。
5. Scene 16など、練習用の空パターンへ移動する。

## 1. MIDImix Mixer And LEDs

目的: volume、mute、solo、LED feedbackを理解する。

1. Track 1 faderを上下し、RenoiseのTrack 1 volumeが追従することを確認する。
2. Track 1 MUTEを押す。Track 1がmuteされ、MUTE LEDが点灯する。
3. もう一度押す。muteが解除され、LEDが消灯する。
4. Track 1 REC/ARMを押す。Track 1がsoloになり、REC/ARM LEDが点灯する。
5. Renoise GUIからsoloを解除する。REC/ARM LEDも自動消灯する。
6. Master faderを動かし、全体音量を安全な位置へ戻す。

MUTE LEDは「音を止めているTrack」、REC/ARM LEDは「solo中のTrack」を示す。

## 2. MIDImix Pan And CUE

目的: 上段Panと中段CUE Levelを理解する。

1. Track 6だけsoloにする。
2. 上段ノブ6を左、中央、右へ動かし、stabの定位を確認する。
3. CUE用ヘッドフォンを接続する。
4. 中段ノブ6を上げ、Track 6がCUE busへ送られることを確認する。
5. ノブを0へ戻し、CUEから消えることを確認する。

CUEが動かない場合は、名前に`cue`を含むSend Trackと各Trackの`#Send`を確認する。

## 3. MIDImix Global And FX Macros

目的: 下段8ノブの役割を理解する。

| Knob | Function | Practice |
|---:|---|---|
| 1 | BPM | 174付近から少しだけ動かす |
| 2 | Swing | 0から少し上げてbreakの跳ねを聴く |
| 3 | Master Pan | 中央から左右へ小さく動かす |
| 4 | Track 7 Reverb | noise tailを伸ばす |
| 5 | Track 7 Delay | transitionだけ反復させる |
| 6 | Master Filter | breakdownで閉じ、drop前に開く |
| 7 | Track 2 Distortion | breakを荒くする |
| 8 | Track 7 Bitcrush | drop直前だけdigitalに崩す |

テスト後はBPM、Pan、Filterを通常位置へ戻す。

## 4. APC Step Mode

目的: 64 padでpatternを直接編集する。

1. SHIFTを押しながら最上段左端を押し、Track 1を選択する。
2. SHIFTを押しながら2段目左端を押し、bank 1を選択する。
3. SHIFTを離す。GridはTrack 1のline 0–63を表示する。
4. 左上padを押す。line 0へKick GeneratorのC-4が追加され、LEDが緑になる。
5. 同じpadをもう一度押す。noteが消え、LEDも消灯する。
6. FADER CTRL 7でbank 2へ進み、line 64–127へ切り替わることを確認する。

Step modeはAI生成後のkick追加、fill削除、vox位置修正に使う。

## 5. APC Scene And Transport

目的: 演奏を止めずにSceneを切り替える。

1. FADER CTRL 1で再生する。
2. 右側Scene 1–8を押し、sequence slotが切り替わることを確認する。
3. SHIFTを押しながら右側Sceneを押し、Scene 9–16へ切り替える。
4. FADER CTRL 3でPattern LoopをONにする。現在Sceneが繰り返される。
5. FADER CTRL 4/5で前後Sceneへ移動する。
6. FADER CTRL 2で停止する。

右側LEDは通常時Scene 1–8、SHIFT中Scene 9–16の現在位置を示す。

## 6. APC Perform Mode

目的: patternを壊さずone-shotを追加する。

1. 再生を開始する。
2. FADER CTRL 8を押し、GridをamberのPerform modeへ切り替える。
3. Track 7のcolumnにあるpadを押し、Harsh Noiseを鳴らす。
4. Track 8のcolumnにあるpadを押し、voxを鳴らす。
5. Renoiseのnote column 2以降へ一時note/OFFが入り、通過後に消えることを確認する。
6. FADER CTRL 8を押し、Step modeへ戻る。

Perform modeは再生中のみ有効。停止中に押してもpatternへ書かない。

## 7. Safe Bank Clear

目的: 誤操作防止付きclearを理解する。

1. 練習用SceneとTrackを選択する。
2. SHIFT+FADER CTRL 8を1回押す。警告だけで何も消えない。
3. 同じ操作を3秒以内にもう一度行う。
4. 選択bankのnote column 1だけが消えることを確認する。

他のnote columnとeffect columnは保持される。ライブ本番前のコピーXRNSでのみ練習する。

## 8. Recommended Live Flow

1. TUI4で次Sceneのdirectiveを発行する。
2. 各TUIで`/d`を実行する。
3. APC Step modeで生成patternを微修正する。
4. MIDImixでvolume、pan、CUEを調整する。
5. APC Sceneボタンで展開する。
6. APC Perform modeでFX/voxを追加する。
7. MIDImix下段macroでtransitionを演出する。
