# AIDJ Live Quick Reference

1行を指定されたTUIへそのまま貼る。詳細版は`prompts/library.md`を参照する。

## TUI#4 Conductor

```text
再生して
停止して
Pattern Loopをオンにして
Pattern Loopを解除して
BPMを174へ10 BPM/秒以下でランプして
ハードカットでBPMを140にして
Scene 1へ切り替えて
Scene 2へ切り替え、標準BPM 180へランプして
Scene 14へ切り替え、標準BPM 220へランプして
Master volumeを0.8にして
Track 1と2を今すぐミュートして
全Trackのミュートを解除して
```

## TUI#4 Scene Preparation

```text
停止してScene 2へ切り替え、現在選択中のScene 2を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。180 BPM、256行で作って
停止してScene 4へ切り替え、現在選択中のScene 4を仕込んで。tui3はTrack 2、tui2はTrack 7、tui1はTrack 5,8を担当。140 BPM half-timeで余白を残して
停止してScene 14へ切り替え、現在選択中のScene 14を仕込んで。tui3はTrack 1,2、tui2はTrack 3,4,7、tui1はTrack 8を担当。220 BPM、全行埋めは禁止
```

directive発行後、TUI#1、TUI#2、TUI#3で次を実行する。

```text
/d
```

## TUI#3 Drums / Breaks

```text
空SceneならTrack 1と2を256行で作って。Kick GeneratorとBreak - Bangy Bangyを使い、16小節で密度とvelocityを変化させて
Track 1をhardcore kick中心にして、1拍目と3拍目を最も強くして
Track 2をamen edit中心にして、2拍目と4拍目のsnareを強調して
Track 2の行224〜255だけsnare rushを追加して
Track 1の行64〜127をキック抜きにして、Track 2だけで緊張感を保って
Track 1の行128〜191をgabber kick runへ差し替えて
```

## TUI#2 Bass / Lead / FX

```text
空SceneならTrack 3,4,7を256行で作って。Diode 03のReese、Tensionの短いstab、Harsh Noiseの転換FXを使って
Track 3をC-2中心のoffbeat Reeseにして、キックとぶつからない位置へずらして
Track 4に短いrave stabを裏拍中心で配置して
Track 7にriser、impact、noise cutを合計6発だけ配置して
send_reverbを0.6にして
send_delayを0.7にして
Track 7のbitcrushを0.6にして
Track 3の行96〜127を一度クリアして余白を作って
```

## TUI#1 Pads / Stabs / Vox

```text
空SceneならTrack 5,6,8を256行で作って。padは長く、stabは短く、voxは2〜6発にして
Track 5にLucid Dreamで暗いC minorのlong padを作って
Track 6にArp Saw Squareで短いrave stabを裏拍へ配置して
Track 8にtv_set_monoのvox chopを4発だけ配置し、各4〜12行後にOFFを入れて
Track 8の行96〜127へvox chopを2発だけ追加して
Track 5の密度を半分にして余白を増やして
```

## Emergency

TUI#4:

```text
今すぐ停止して
Master volumeを0にして
全Trackをミュートして
```
