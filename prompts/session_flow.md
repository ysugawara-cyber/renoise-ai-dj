# AIDJ 16-Scene Session Flow

現行16 Sceneを安全に事前生成し、ライブで順番にlaunchするためのコピペ手順。

## Scene Map

| Scene | Name | BPM | Tracks | Character |
|---:|---|---:|---|---|
| 1 | intro_amen_loop | 174 | 1,2,5 | amen intro |
| 2 | drop1_breakcore_full | 180 | 1,2,3,4,7,8 | full breakcore drop |
| 3 | hardcore_kick_run | 210 | 1,3,4,5,7 | hardcore run |
| 4 | breakdown_ambient | 140 | 2,5,7,8 | half-time breakdown |
| 5 | outro_distorted | 220 | 1,2,3,7,8 | distorted exit |
| 6 | jungle_switch | 176 | 2,3,7,8 | chopped jungle |
| 7 | gabber_pressure | 210 | 1,3,4,7 | dense gabber |
| 8 | vox_break | 174 | 2,5,8 | sparse vox break |
| 9 | crossbreed_drive | 190 | 1,2,3,7 | crossbreed drive |
| 10 | amen_overload | 180 | 1,2,3,7,8 | maximum amen edits |
| 11 | industrial_halfstep | 145 | 1,2,5,7 | industrial bridge |
| 12 | rave_stab_run | 200 | 1,3,4,6,8 | rave stab run |
| 13 | noise_transition | 180 | 5,7,8 | 16-bar transition |
| 14 | hardcore_peak | 220 | 1,2,3,4,7,8 | peak section |
| 15 | final_break | 174 | 2,5,7,8 | 16-bar decompression |
| 16 | encore | 200 | 1–8 | full-stack encore |

256行PatternはLPB=4で16小節。32小節Sceneは同じPatternを2周して使う。

## Safe Preparation Rule

`/ai/pattern/write`はScene IDを持たず、停止中はRenoiseのedit positionへ書く。
別Sceneを仕込むときは、必ず次の順番を守る。

1. TUI#4へ「停止して対象Sceneへ切り替え、現在選択中のSceneを仕込んで」と貼る。
2. TUI#4がScene切替とdirective発行を完了するまで待つ。
3. TUI#1、TUI#2、TUI#3で`/d`を1回ずつ実行する。
4. 生成結果を確認してから次のSceneを仕込む。

演奏中に非アクティブSceneを裏で生成しない。ライブ中の修正は現在再生中のSceneだけに行う。

## Scene Preparation Prompts: TUI#4

### Scene 1

```text
停止してScene 1へ切り替え、現在選択中のScene 1を仕込んで。tui3はTrack 1,2で疎なamen introを作りkickは後半から、tui1はTrack 5のdark pad、tui2は休止。174 BPM、256行で作って
```

### Scene 2

```text
停止してScene 2へ切り替え、現在選択中のScene 2を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。180 BPMのfull breakcore dropを256行で作って
```

### Scene 3

```text
停止してScene 3へ切り替え、現在選択中のScene 3を仕込んで。tui3はTrack 1のhardcore kick run、tui2はTrack 3,4,7、tui1はTrack 5の薄いpadを担当。210 BPM、256行で作って
```

### Scene 4

```text
停止してScene 4へ切り替え、現在選択中のScene 4を仕込んで。tui3はTrack 2を疎に、tui2はTrack 7、tui1はTrack 5,8を担当。140 BPM half-timeでnegative spaceを大きくして
```

### Scene 5

```text
停止してScene 5へ切り替え、現在選択中のScene 5を仕込んで。tui3はTrack 1,2、tui2はTrack 3,7、tui1はTrack 8を担当。220 BPMのdistorted exitを作り、後半8小節でbreakとFXを減らして
```

### Scene 6

```text
停止してScene 6へ切り替え、現在選択中のScene 6を仕込んで。tui3はTrack 2、tui2はTrack 3,7、tui1はTrack 8を担当。176 BPMのchopped jungleを256行で作って
```

### Scene 7

```text
停止してScene 7へ切り替え、現在選択中のScene 7を仕込んで。tui3はTrack 1、tui2はTrack 3,4,7、tui1は休止。210 BPMのdense gabber pressureを256行で作って
```

### Scene 8

```text
停止してScene 8へ切り替え、現在選択中のScene 8を仕込んで。tui3はTrack 2を疎に、tui1はTrack 5,8、tui2は休止。174 BPMのvox-led breakを256行で作って
```

### Scene 9

```text
停止してScene 9へ切り替え、現在選択中のScene 9を仕込んで。tui3はTrack 1,2、tui2はTrack 3,7、tui1は休止。190 BPMのcrossbreed driveを作り、後半8小節で密度を上げて
```

### Scene 10

```text
停止してScene 10へ切り替え、現在選択中のScene 10を仕込んで。tui3はTrack 1,2のamen edit、tui2はTrack 3,7、tui1はTrack 8を担当。180 BPM、後半ほどeditを細かくして
```

### Scene 11

```text
停止してScene 11へ切り替え、現在選択中のScene 11を仕込んで。tui3はTrack 1,2、tui2はTrack 7、tui1はTrack 5を担当。145 BPMの重く疎なindustrial halfstepにして
```

### Scene 12

```text
停止してScene 12へ切り替え、現在選択中のScene 12を仕込んで。tui3はTrack 1、tui2はTrack 3,4、tui1はTrack 6,8を担当。200 BPMのrave stab runを256行で作って
```

### Scene 13

```text
停止してScene 13へ切り替え、現在選択中のScene 13を仕込んで。tui2はTrack 7のriser/impact、tui1はTrack 5,8、tui3は休止。180 BPM、16小節のnoise transitionにして
```

### Scene 14

```text
停止してScene 14へ切り替え、現在選択中のScene 14を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。220 BPMのhardcore peakを256行で作って
```

### Scene 15

```text
停止してScene 15へ切り替え、現在選択中のScene 15を仕込んで。tui3はTrack 2、tui2はTrack 7、tui1はTrack 5,8を担当。174 BPM、16小節のdecompression breakにして
```

### Scene 16

```text
停止してScene 16へ切り替え、現在選択中のScene 16を仕込んで。全TUIが所有Trackだけを担当し、200 BPMのfull-stack encoreを256行で作って
```

各Scene promptの後、TUI#1–3で実行する。

```text
/d
```

## Performance Launch Order: TUI#4

事前生成後の一例。以下はScene launchとtempoだけを操作し、Pattern生成は行わない。

```text
Scene 1へ切り替え、BPM 174にして再生して
Scene 6へ切り替え、BPM 176へランプして
Scene 2へ切り替え、BPM 180にして
Scene 3へ切り替え、BPM 210へ10 BPM/秒以下でランプして
Scene 4へハードカットし、BPM 140にして
Scene 9へ切り替え、BPM 190へランプして
Scene 11へハードカットし、BPM 145にして
Scene 12へ切り替え、BPM 200へランプして
Scene 13へ切り替え、filter_cutoffを0.3から0.9へスイープして
Scene 14へ切り替え、BPM 220へランプして
Scene 15へ切り替え、BPM 174へランプして
Scene 16へ切り替え、BPM 200へランプして
Scene 5へ切り替え、BPM 220にして
Master volumeを0.8から0へゆっくり下げて、最後に停止して
```

## Current Scene Live Corrections

演奏中は現在Sceneだけを対象に、担当TUIへ短い修正を貼る。

```text
[TUI#3] 現在SceneのTrack 2だけ密度を半分にして
[TUI#2] 現在SceneのTrack 7にimpactを1発だけ追加して
[TUI#1] 現在SceneのTrack 8に短いvox chopを1発だけ追加して
[TUI#4] 現在SceneをキープしてPattern Loopをオンにして。16小節後の解除は別指示で行う
```

## Controller Reference

APC mini mk2とMIDImixの現行割当は`docs/controller_map.md`を参照する。Scene 9–16はAPCのSHIFTと右側SCENE LAUNCHを併用する。
