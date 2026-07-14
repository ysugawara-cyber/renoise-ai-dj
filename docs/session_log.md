# セッションログ 2026-07-04〜09

## 完了した検証

### OSC 通信 (§1-2)
- roundtrip (bpm/mute/solo/volume): OK, volume 期待値は 0.5 (session.json 上)
- swing: transport.groove_amounts に反映、GUI には Groove として表示
- pan: -500 → 25L 表示で合致
- fx_param/fx_macro: ブリッジ側は正常、Renoise GUI 確認は FX デバイス挿入が必要

### APC mini mk2 (§3)
- パッドグリッド: notes 0-63, 上下反転 (bottom=0-7, top=56-63)
- LED 公式プロトコル: 0x96=100%輝度, pad_idx=note, vel=0x15=緑, 0x09=オレンジ, 0x05=赤
- SCENE LAUNCH ボタン: notes 112-119
- FADER CTRL: notes 100-107 (100=Play, 101=Stop)
- フェーダー: CC 48-55 (Track 1-8 Volume)
- 3層構造実装済み:
  - Row 0: Scene Launch (緑LED)
  - Row 1-4: パターンシーケンスジャンプ (オレンジLED)
  - Row 5: loop_pattern モメンタリ (赤LED)
  - Row 6: Distortion device active トグル (赤LED)
  - Row 7: track mute モメンタリ (赤LED)

### AKAI MIDImix (§4)
- MUTE: notes 1,4,7,10,13,16,19,22 → track=(note-1)/3+1
- REC/ARM (Solo): notes 3,6,9,12,15,18,21,24 → note%3==0
- ノブ: CC 16,20,24,28,46,50,54,58
  - 割当: BPM, Swing, MasterPan, SendReverb, SendDelay, FilterCutoff, Distortion, Bitcrush
- フェーダー: CC 19,23,27,31,49,53,57,61 → Track 1-8 Volume
- マスターフェーダー: CC 62 → Master Volume

### テンプレート XRNS (§5)
- 8 sequencer tracks + CUE bus (track 10)
- 楽器: Kick Generator, Break - Bangy Bangy, Diode 03, Tension, String Thing, Lucid Dream, Arp Saw Square, Harsh Noise, tv_set_mono
- 5 patterns (256 lines), 5 pattern sequence slots
- FX devices per fx_mapping.yaml

## 修正したバグ

### クリティカル
- `pattern_writer.lua`: postfx_volume 最大値 1.415→1.41253 (Renoise 3.5.4 の制限)
- `pattern_writer.lua`: PatternTrack に number_of_lines が無い → Pattern から取得
- `pattern_writer.lua`: 楽器名解決 (tonumber 失敗時に名前検索)
- `pattern_writer.lua`: EffectColumn API (effect_value/effect_string 非対応 → number_string)
- `osc_bridge.py`: outbox consumer スレッドクラッシュ (shutil.move race condition)
- `midi_router.lua`: APC 入力/出力デバイス名の不一致、create_output_device pcall 化

### Renoise API 注意点
- `EffectColumn`: effect_value/effect_string/value_string は read only
  - 書き込めるのは number_string (値部分2桁のみ) と amount_value
- `Transport`: loop_block は存在しない → loop_pattern を使用
  - transport:start(1) で起動 (start_song/start_pattern 定数は 3.5.4 で利用不可)
- `InstrumentList`: #renoise.song().instruments で個数取得可

### モデル/速度
- 全エージェント: opencode-go/deepseek-v4-flash 推奨
- TUI レスポンス: ~35-60s (モデル思考時間が支配的)
- 速度最適化ルールを全エージェントに適用済み

### TUI パターン書き込み
- OSC /ai/pattern/write で直接書き込み。Lua 生成不要。
- 絶対パス outbox を使用。python3 -c ワンライナー推奨。
- 書き込み後検証禁止。session.json 読取不要。

## 既知の制限
- Zxx エフェクト: Renoise Lua API からエフェクト種別変更不可 → パターンシーケンスジャンプで代用
- MIDImix macro auto-fire: WSL から USB MIDI アクセス不可 → Lua 側で直接処理
- APC LED 色: ファームウェアのパレットに依存
- python-rtmidi: ソースビルド必要なため Python 3.12 の venv を使用
