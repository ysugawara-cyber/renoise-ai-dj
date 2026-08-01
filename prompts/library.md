# AIDJ Copy-Paste Prompt Library

各code blockの1行を、見出しに指定されたTUIへそのまま貼る。
Track ownershipとInstrument一覧は`prompts/README.md`を参照する。

## Transport And Scene: TUI#4

```text
再生して
停止して
現在のSceneをキープしてPattern Loopをオンにして。16小節後の解除は別指示で行う
Pattern Loopを解除して次のSceneへ切り替えて。現在がScene 16ならScene 1へ戻って
Scene 6 jungle_switchへ切り替え、BPM 176へランプして
Scene 9 crossbreed_driveへ切り替え、BPM 190へランプして
Scene 11 industrial_halfstepへハードカットして、BPM 145にして
Scene 16 encoreへ切り替え、BPM 200にして
```

## Tempo And Groove: TUI#4

```text
BPMを174から210へ10 BPM/秒以下でランプして
BPMを220から180へ10 BPM/秒以下で下げて
ハードカットでBPMを140にして
テンポを倍にした感覚へ寄せて。ただし240 BPMを超えないで
ハーフタイム感へ切り替えて。ただし120 BPM未満にはしないで
Swingを0.25にして
Swingを0へ戻して
```

## Full Scene Generation: TUI#3

```text
空SceneならTrack 1と2を0〜255行まで作って。4小節ごとにkick、snare、break editを変化させ、全行埋めは避けて
Track 1は50〜80 Hzのbodyを感じるhardcore kick、Track 2はamen editで256行を展開して
174 BPM向けのjungle寄りbreakcore drumsを256行で作って。後半ほど細かいeditを増やして
220 BPM向けのgabber drumsを256行で作って。sustain kickは避け、8小節ごとにfillを変えて
145 BPMのindustrial halfstepを256行で作って。kickの間隔とnegative spaceを大きくして
```

## Drum Corrections: TUI#3

```text
Track 1の行0〜63だけ4つ打ちへ変更して
Track 1の行64〜127をキック抜きにして
Track 1の行128〜191をoffbeat kick中心へ変更して
Track 2の2拍目と4拍目のsnareを強くして
Track 2の行224〜255だけ32分snare rushを追加して
Track 2のbreakを半分の密度にしてghost noteを弱くして
Track 1と2のvelocityを機械的に揃えず、主accentだけ110以上にして
Track 1の行64から64行をクリアして
```

## Full Scene Generation: TUI#2

```text
空SceneならTrack 3,4,7を0〜255行まで作って。Reese、短いlead、4〜8発の転換FXで構成して
Track 3をC-2中心のdark Reeseにして、Track 4は短いrave stab、Track 7は節目だけnoiseを入れて
190 BPMのcrossbreed bass/lead/FXを256行で作って。bassはstaggered、FXは後半へ集中して
220 BPMのhardcore peak用にTrack 3,4,7を作って。Track 7は主役を隠さないで
145 BPMのhalfstep向けにTrack 3を疎にし、Track 7へ低いindustrial noiseを4発だけ配置して
```

## Bass / Lead Corrections: TUI#2

```text
Track 3をC-2とG-1中心のoffbeat Reeseへ変更して
Track 3のnoteをkick直後へ2行ずらして衝突を避けて
Track 3の行96〜127をクリアしてbreakdownの余白を作って
Track 4にC-4、D#4、G-4の短いrave stabを裏拍だけへ配置して
Track 4のstabを半分に減らしてvelocityも15下げて
Track 7にriser 2発、impact 2発、noise cut 2発だけ追加して
Track 7の持続音は2〜12行後にOFFを入れて
```

## FX Macros: TUI#2

```text
send_reverbを0.6にして
send_reverbを0.2へ戻して
send_delayを今0.7にして
send_delayを今0.2へ戻して
Track 7のbitcrushを0.6にして
Track 7のbitcrushを0へ戻して
```

`send_reverb`と`send_delay`はTrack 7、`bitcrush`はTrack 7 Cabinet Distortionの互換名。

## Full Scene Generation: TUI#1

```text
空SceneならTrack 5,6,8を0〜255行まで作って。long pad、短いstab、2〜6発のvoxで余白を残して
Track 5をC minorのdark ambient pad、Track 6を短いrave stab、Track 8をspoken chopにして
140 BPM breakdown向けにTrack 5と8を256行で作って。voxは低密度、padは長くして
200 BPM encore向けにTrack 5,6,8を256行で作って。voxとstabを同時に重ねすぎないで
```

## Pads / Stabs / Vox Corrections: TUI#1

```text
Track 5のchordをC minorに統一し、8小節ごとにvoicingだけ変えて
Track 5の密度を半分にして長い余韻を残して
Track 6のstabを裏拍へ移動し、同じpitchの連打を避けて
Track 8にvox chopを4発だけ配置し、各4〜12行後にOFFを入れて
Track 8の行96〜127へspoken chopを2発だけ追加して
Track 8のvelocityを55〜95へ抑えて主役を隠さないで
Track 8の行128から64行をクリアして
```

## Global Macros: TUI#4

```text
Master volumeを0.8にして
Master volumeを0.5までゆっくり下げて
filter_cutoffを0.3から0.9へスイープして
filter_cutoffを0.7へ戻して
distortion macroを0.6にして。対象はTrack 2
distortion macroを0.2へ戻して
```

## Mixer And Emergency: TUI#4

```text
Track 1と2を今すぐミュートして
Track 1と2のミュートを解除して
Track 3をミュートして
全Trackのミュートを解除して
Track 7をsoloにして
soloをすべて解除して
今すぐ停止してMaster volumeを0にして
```

## Multi-TUI Scene Preparation: TUI#4

```text
停止してScene 2へ切り替え、現在選択中のScene 2を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。180 BPM、256行で作って
停止してScene 4へ切り替え、現在選択中のScene 4を仕込んで。tui3はTrack 2、tui2はTrack 7、tui1はTrack 5,8を担当。140 BPM half-timeで余白を残して
停止してScene 10へ切り替え、現在選択中のScene 10を仕込んで。tui3はamen edit、tui2はTrack 3,7、tui1はTrack 8を担当。180 BPMで後半ほど密度を上げて
停止してScene 13へ切り替え、現在選択中のScene 13を仕込んで。tui2はTrack 7、tui1はTrack 5,8、tui3は休止。16小節の転換専用にして
停止してScene 14へ切り替え、現在選択中のScene 14を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。220 BPM、256行で作って
停止してScene 16へ切り替え、現在選択中のScene 16を仕込んで。全TUIが所有Trackだけを担当し、200 BPM、256行で作って
```

directive発行後、TUI#1–3へ順番に貼る。

```text
/d
```

## Vague But Safe DJ Requests: TUI#4

```text
停止して使用するSceneへ切り替えた後、現在選択中のSceneに次のdropを仕込んで。主役、support、negative spaceを決めて各TUIへdirectiveを出して
breakdownへ移行して。BPMは10 BPM/秒以下で下げ、drumsとbassを落としてpad/FX/voxを疎に残して
hardcoreへ連続的に移行して。Track 7のriser、Track 8の短いshout、Track 1,2の密度上昇を各TUIへ依頼して
今のSceneを保ったままエネルギーを一段上げて。各TUIは所有Trackだけを変更して
音数を3割減らして余白を増やして。主accentは維持して
```
