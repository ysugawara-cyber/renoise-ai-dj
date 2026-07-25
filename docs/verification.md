# docs/verification.md — 実機検証手順

本ドキュメントはコード修正(T1: int×1000 化、T2: macro 解決、T2-b: knob 自動発火)が
実機で正しく動くことを確認する手順。Renoise + ハードウェア必須。

## 0. 前提

- `osc_bridge.py` が起動済み（`host/.venv/bin/python host/osc/osc_bridge.py`）
- Renoise で AIDJ Tool が `Tools -> AIDJ -> Start Session` で起動済み
  （`/ai/status` が ~10 Hz で broadcast され `host/state/session.json` が更新される状態）
- AIDJ テンプレート XRNS が読み込まれている（8 sequencer track + CUE bus）

## 1. 自動 roundtrip 検証（bpm / volume / mute / solo）

```sh
host/.venv/bin/python host/osc/verify_roundtrip.py
```

`session.json` を通じて 4 項目を自動チェック:
- `/ai/bpm i:<X>` → `state.bpm == X`
- `/ai/mixer/mute "1" 1` → `tracks.1.mute == true`
- `/ai/mixer/solo "1" 1` → `tracks.1.solo == true`
- `/ai/mixer/volume "1" 500` → `tracks.1.volume` が 0.49..0.51
  （`pattern_writer.lua` が `v/1000 * 1.41253` で postfx_volume を設定→
  `status_publisher` が生値をブロードキャスト→`osc_bridge.py` が `/1.41253` で正規化→
  net `500/1000 = 0.5`）

全 4 / 4 で PASS なら ok。1 つでも FAIL の場合は該当 OSC handler の
`/1000` 復元ミスを疑う（`tools/AIDJ/osc_server.lua`, `pattern_writer.lua`）。

## 2. 手動検証（broadcast 対象外、Renoise GUI で目視）

`/ai/swing` `/ai/mixer/pan` `/ai/fx/param` `/ai/fx/macro` は
`status_publisher.lua` が broadcast しないため `session.json` から確認不可。
Renoise 側で目視確認する。

### 2.1 swing
```
host/.venv/bin/python host/osc/send.py /ai/swing 500
```
Renoise の Transport パネルで swing が **0.5** になるはず。
（修正前は 1.0 に钳られていた）

### 2.2 pan
```
host/.venv/bin/python host/osc/send.py /ai/mixer/pan 1 -500
```
Track 1 の panner が **-0.5 (左 50%)** になるはず。

### 2.3 fx param
```
host/.venv/bin/python host/osc/send.py /ai/fx/param 1 0 0 250
```
Track 1 の FX #0 / param #0 が **0.25** になるはず。

### 2.4 fx macro（T2 展開）
```
host/.venv/bin/python host/osc/send.py /ai/fx/macro swing 500
```
`osc_bridge.py` のログに `-> /ai/swing 500 (macro swing)` が出るはず。
Renoise 側の swing が 0.5 に（2.1 と同効果）。
```
host/.venv/bin/python host/osc/send.py /ai/fx/macro bpm_coarse 500
```
`-> /ai/bpm 180 (macro bpm_coarse)` が bridge ログに出るはず
（range 120..240 の 50% 地点）。
```
host/.venv/bin/python host/osc/send.py /ai/fx/macro send_reverb 250
```
`-> /ai/fx/param [track "7", 0, 0, 250]` が bridge ログに出るはず。

## 3. APC mini mk2 検証（V4 / V5 前半）

### 3.1 Hybrid pad grid
- Step modeでpadを押すと、選択Track/64-line bankの対応noteがtoggleされLEDが緑になる。
- SHIFT+最上段でTrack 1..8、SHIFT+2段目左4padでbank 1..4を選ぶ。
- 再生中にFADER CTRL 8でPerform modeへ切替し、各columnがTrack 1..8のone-shotになる。
  note column 2以降へ一時書込され、通過後に自動消去されることを確認する。
- SHIFT+FADER CTRL 8を3秒以内に2回押すと、選択bankのnote column 1だけをclearする。
  1回目では警告だけになり、effect/他note columnを保持することを確認する。

### 3.2 Scene / sliders
- 右側Sceneボタンは通常Scene 1..8、SHIFT併用でScene 9..16。
- Slider 1 を動かす → Track 1 の postfx_volume が 0..1.41253 で変化。
- Slider 9 (CC56)を動かす → Master volumeが変化。
- `tools/AIDJ/midi_router.lua:29` が int×1000 に正規化済み、`pattern_writer.set_volume`
  が `/1000` 復元するため、可聴範囲全域が効くはず。

### 3.3 Transport buttons
- FADER CTRL 左 2 つ (Note 100 / 101) → Play / Stop。
- Note 102..107 → Loop / Previous Scene / Next Scene / Previous Bank / Next Bank / Mode。
  `tools/AIDJ/midi_router.lua` の `handle_apc` が直接処理する
  (Renoise MIDI Mapping XML は廃止済み。旧 `host/midi_maps/AIDJ_APC_MIDImix.xml` は
  誤ったマッピングを含んでいたため削除)。
- LED の色（velocity palette）も実機で確認し、必要なら
  `tools/AIDJ/midi_router.lua` の LED 送信箇所を調整。

## 4. AKAI MIDImix 検証（V4 / T2-b）

### 4.1 MUTE / SOLO ボタン（MUTE: Note 1,4,7,…,22 / SOLO: Note 3,6,9,…,24）
- MUTE button 1 (Note 1) を押す → Track 1 mute toggle。
- SOLO button 1 (Note 3) を押す → Track 1 solo toggle。
- mute時はMUTE LED、solo時はREC/ARM LEDが点灯し、Renoise GUIやTUIからの変更にも追従する。
- 割当の詳細は `.opencode/rules/midi_mapping.md` と
  `tools/AIDJ/midi_router.lua` の `handle_mix` を参照。

### 4.2 Knobs (Renoise Lua直接処理)
- 上段`16,20,24,28,46,50,54,58` → Track 1..8 Pan。
- 中段`17,21,25,29,47,51,55,59` → Track 1..8 CUE Level。
- 下段`18,22,26,30,48,52,56,60` → BPM / Swing / Master Pan / Reverb /
  Delay / Master Filter / Distortion / Bitcrush。
- CUEとFXは現在のXRNS device構成と照合して手動確認する。
- bridge側MIDI listenerは標準で無効。WSLからUSB MIDIへアクセスしない。

### 4.3 Faders
- Track 1-8: CC `19,23,27,31,49,53,57,61` → Track Volume。
- Master: CC `62` → Master Volume。
- Renoise MIDI Mapping XMLは使用しない。

## 5. テンプレート XRNS 作成手順（C.6）

### 5.1 Renoise で新規 Song を開く
- File -> New（空の Song、初期 Pattern 1 つ + Master Track のみ想定）。

### 5.2 Track skeleton ヘルパを実行
- `Tools -> AIDJ -> Setup -> Build or Extend 16-Scene Skeleton`を実行する。
- Scripting TerminalはToolと別sandboxで`renoise.tool()`が存在しないため、Terminalから
  `dofile(renoise.tool().bundle_path ...)`を実行しない。
- ステータスバーに "AIDJ skeleton built." と表示される。
- 8 sequencer track (drums / breaks / bass / lead / pads / stabs / fx / vox) +
  16 個の256-line Patternが生成される。

### 5.3 CUE bus + #Send + FX 一括セットアップ（Lua Console）

skeleton 実行後、Lua Console で以下を順に実行:

**a) CUE bus (Send Track) 追加**: Master の後ろに Send Track を挿入。
```lua
local song = renoise.song()
local master_idx
for i, tr in ipairs(song.tracks) do
  if tr.type == renoise.Track.TRACK_TYPE_MASTER then master_idx = i end
end
song:insert_track_at(master_idx + 1)
local cue = song:track(master_idx + 1)
cue.name = "cue"
cue.color = {0x00, 0xCC, 0xFF}
print("CUE bus at track", master_idx + 1)
```

**b) #Send + FX デバイス一括挿入**:
```lua
local song = renoise.song()
local master_idx
for i, tr in ipairs(song.tracks) do
  if tr.type == renoise.Track.TRACK_TYPE_MASTER then master_idx = i end
end
local SEND = "Audio/Effects/Native/#Send"
local FX = {
  [1] = {"Audio/Effects/Native/Compressor", "Audio/Effects/Native/Reverb"},
  [2] = {"Audio/Effects/Native/Distortion 2", "Audio/Effects/Native/Delay"},
  [3] = {"Audio/Effects/Native/Digital Filter"},
  [5] = {"Audio/Effects/Native/Reverb"},
  [7] = {"Audio/Effects/Native/Reverb", "Audio/Effects/Native/Delay", "Audio/Effects/Native/Cabinet Simulator"},
}
for ti = 1, 8 do
  local tr = song:track(ti)
  tr:insert_device_at(SEND, #tr.devices + 1)
  if FX[ti] then
    for _, path in ipairs(FX[ti]) do
      tr:insert_device_at(path, #tr.devices + 1)
    end
  end
end
local master = song:track(master_idx)
master:insert_device_at("Audio/Effects/Native/Digital Filter", #master.devices + 1)
print("FX + #Send inserted")
```

**c) #Send の送信先を CUE に設定**: Receiver=0 が CUE bus。
```lua
local song = renoise.song()
for ti = 1, 8 do
  local dev = song:track(ti):device(2)  -- #Send は TrackVolPan の次
  dev.parameters[3].value = 0  -- Receiver 0 = CUE
  dev.parameters[1].value = 0.8  -- Amount 80%
end
print("#Send -> CUE, Amount=0.8")
```

### 5.4 手動で残す作業
1. 各トラックに楽器(Sampler または VSTi)を挿入し、サンプル/プリセットを割当。
   楽器命名は `music_constraints.md` の `KCK01` / `SNR01` / `BAS_reese01` 等に従う。
2. Pattern Sequence のslot 1..16に16個のPatternが対応済み
   （skeletonがslot追加済み、必要ならslot順をドラッグで調整）。
3. File -> Save As で `AIDJ-TEMPLATE.<date>.xrns` として保存。
   `~/.renoise/Templates/` に配置すれば Renoise の File -> New から選べる。

### 5.5 fx_mapping.yaml / macros.yaml の index 照合（A.2）
- 手順 5.3 で挿入したカスタムFXの順と `fx_mapping.yaml` の `fx_index`（0-based）、
  `macros.yaml` の `fx_index` / `param_index` を照合。
- `fx_index: 0` は最初のカスタムFXを表す。TrackVolPanと先頭の`#Send`はruntimeが除外する。
- Renoise Lua Console で以下を実行してインデックスを確認:
  ```lua
  for i, d in ipairs(renoise.song():track(7).devices) do
    print(i, d.name)
    for j, p in ipairs(d.parameters) do
      print("  ", j, p.name)
    end
  end
  ```
  `param_index`は表示されたparameter番号から1を引く。`fx_index`はカスタムFX内の順番で、
  最初を0とする（GUI全体のdevice番号から単純に1を引かない）。

## 6. 検証失敗時の問い合わせ先

- OSC 系（手順 1, 2）→ `osc_protocol.lua` / `osc_server.lua` /
  `pattern_writer.lua` / `osc_bridge.py`
- MIDI 系（手順 3, 4）→ `midi_router.lua`
- 検証スクリプト自体 → `host/osc/verify_roundtrip.py`
- テンプレート作成（手順 5）→ `tools/AIDJ/setup/build_track_skeleton.lua`
