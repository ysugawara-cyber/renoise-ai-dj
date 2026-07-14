# AIDJ Live セッションフロー

## シーン構成

| Scene | 名前 | 用途 | BPM |
|-------|------|------|-----|
| 1 | intro_amen_loop | 導入 / amen break ループ | 174 |
| 2 | drop1_breakcore_full | メインドロップ / 全トラック全力 | 200 |
| 3 | hardcore_kick_run | ハードコアセクション / キック疾走 | 210 |
| 4 | breakdown_ambient | ブレイクダウン / アンビエント | 140 |
| 5 | outro_distorted | アウトロ / 歪み崩壊 | 120 |

## セット進行

### 0. プリセット (Start Session 直後)
- Conductor: BPM 174 に設定
- Conductor: シーン 1 に設定
- APC: Row 0 (Scene Launch) の Scene 1 パッド押下で開始準備
- MIDImix: 全トラック MUTE 解除、volume 中程度

### 1. イントロ (0:00 - 1:30)
```
conductor: BPMを174に設定して
conductor: シーン1に切り替えて
drums:   トラック2にアーメンブレイクを書いて
bass:    トラック3にC-2のリースベースを控えめに
```
- 雰囲気を作る。キックはまだ入れない
- amen break だけを 174 BPM でループ
- ベースは控えめ (vel 70)

### 2. ビルドアップ (1:30 - 2:30)
```
conductor: BPMを174から195まで上げて
drums:   トラック1にC-4のキック4つ打ちを入れて
drums:   トラック2にハイハットを16分で追加して
bass:    トラック3のリースベースを強くして (vel 110)
pads:    トラック5に暗いパッドを伸ばして
```
- BPM を 3-4 小節かけてランプアップ
- キックが入り、エネルギーが上がる
- ハイハットがテンションを上げる

### 3. ドロップ 1 (2:30 - 4:00)
```
conductor: BPM200でシーン2に切り替えて
drums:   トラック1にC-4キックを高速で。ベロシティMAX
drums:   トラック2にスネアラッシュを入れて
bass:    トラック3に歪んだリースベースを。distortion ON
pads:    トラック6にC-5のレイヴスタブを入れて
```
- フルパワー。全トラック稼働
- APC: 行 5-7 のエフェクトをポン出しで遊ぶ
- MIDImix: ノブで distortion/フィルターを操作

### 4. ハードコアラン (4:00 - 5:30)
```
conductor: BPM210でシーン3に切り替えて
drums:   トラック1に超高速キック連打
bass:    トラック3にオフビートベース
```
- BPM 最大。キックが疾走する
- ベースはオフビートで跳ねる

### 5. ブレイクダウン (5:30 - 7:00)
```
conductor: BPMを140まで落としてシーン4に切り替え
drums:   トラック1のキックを削除/ミュート
bass:    トラック3をミュート
pads:    トラック5にアトモスフェリックパッド
```
- 急激に落とす。空間を作る
- パッドだけが残る
- 緊張感を保つ

### 6. ドロップ 2 (7:00 - 8:30)
```
conductor: BPM200でシーン2に切り替え
drums:   全トラック最大で書いて
bass:    ディストーションベース戻し
```
- 再ドロップ。1回目より激しく

### 7. アウトロ (8:30 - 10:00)
```
conductor: BPMを120までゆっくり下げてシーン5に切り替え
drums:   トラック1,2をミュート
pads:    トラック5だけ残す。徐々にvolume下げて
conductor: 停止して
```
- BPM をゆっくり下げる
- トラックを順にミュート
- 最後はパッドだけの余韻で終了

## APC 操作ガイド（演奏中）

| 操作 | 効果 |
|------|------|
| 行 0 (最上段) パッド | シーン切替 |
| 行 1-4 パッド | パターンシーケンスジャンプ |
| 行 5 押下中 | ループ (stutter) |
| 行 6 押下中 | Distortion ON |
| 行 7 押下中 | トラック Mute |
| SCENE LAUNCH ボタン | シーン切替 |
| FADER CTRL 1/2 | Play / Stop |
| フェーダー | Track Volume |

## MIDImix 操作ガイド（演奏中）

| 操作 | 効果 |
|------|------|
| MUTE ボタン | トラック Mute トグル |
| REC/ARM ボタン | トラック Solo トグル |
| フェーダー | Track Volume |
| ノブ 1 | BPM |
| ノブ 2 | Swing |
| ノブ 3 | Master Pan |
| ノブ 4 | Send Reverb |
| ノブ 5 | Send Delay |
| ノブ 6 | Filter Cutoff |
| ノブ 7 | Distortion |
| ノブ 8 | Bitcrush |
| マスターフェーダー | Master Volume |
