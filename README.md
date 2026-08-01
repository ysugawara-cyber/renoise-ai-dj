# AIDJ Live Performance System

Renoise、OpenCode、OSC、APC mini mk2、AKAI MIDImixを組み合わせた、ブレイクコア / ハードコア・テクノ向けAIライブコーディング環境です。

## 公開版の範囲

- 公開リポジトリにはOpenCodeの4ロール、Renoise Lua Tool、bridge、設定、テストを含みます。
- **サンプル入りXRNSは同梱しません**。代わりにToolが数式から8個の簡易fallback音源を生成します。利用者は後から権利を持つサンプルへ差し替えられます。
- `opencode.json`、4 TUIのagent定義、commands、共有rulesを同梱します。OAuthトークン/APIキーはリポジトリへ保存しません。

## 必要環境

- Windows + WSL2
- Renoise 3.5.x (Lua API 6.2)
- Python 3.10+
- Lua 5.4 (Renoise外の構文テスト用)
- OpenCode
- 任意: APC mini mk2 / AKAI MIDImix / Zoom H4essential

ハードウェアなしでも、OpenCodeエージェント、outbox、bridge、OSC送受信、Renoise GUIでのパターン書込は利用できます。MIDI操作、LED、実CUE/Main出力は実機が必要です。

Renoiseは`setup.sh`より先に一度起動し、Windows data directoryを作成してください。

## 初回セットアップ

```sh
git clone https://github.com/ysugawara-cyber/renoise-ai-dj.git
cd renoise-ai-dj

./setup.sh
```

`setup.sh`はvenv、固定Python依存、runtime directory、Renoise Tool、テストを一括準備します。詳細は`docs/fresh_install.md`を参照してください。

### OpenCode / ChatGPT OAuth

1. リポジトリルートで`opencode`を起動します。
2. `/connect`を実行し、OpenAIを選択してブラウザのChatGPT OAuth認証を完了します。
3. tracked `opencode.json`の各modelを利用できない場合は、`/models`で利用可能なtool-calling対応モデルを確認し、model IDを変更します。
4. modelまたは設定を変更した後は、4つのOpenCode TUIを再起動します。

認証情報はOpenCodeのユーザーデータ領域に保存されます。`opencode.json`や`.opencode/`へtoken/API keyを記載しないでください。設定変更後はOpenCodeを再起動してください。

## Renoise Toolのインストール

Renoiseのdata directory配下にToolをコピーします。

```sh
# 推奨: 明示指定
export AIDJ_RENOISE_TOOL_DIR="/mnt/c/Users/<WindowsUser>/AppData/Roaming/Renoise/V3.5.4/Scripts/Tools/com.aidj.live.xrnx"
./tools/install.sh
```

`AIDJ_RENOISE_TOOL_DIR`を省略した場合、`/mnt/c/Users/*/AppData/Roaming/Renoise/V*/Scripts/Tools/`から最新候補を自動検出します。コピー後、RenoiseでTools -> Scripting -> Reload Toolsを実行します。

### ターンキーSongの作成

1. Renoiseで新規ソングを開きます。
2. `Tools -> AIDJ -> Setup -> Build Turnkey Song (Fresh Song Only)`を実行します。
3. `Tools -> AIDJ -> Setup -> Validate Current Song`が成功することを確認します。

8 sequencer track、16 scene、各256 line、必須名instrument、簡易fallback音源、CUE/#Send、native FXを作成します。instrument名はruntime契約のため変更せず、任意の名前でXRNSを保存してください。

既存の5-scene XRNSを拡張する場合は先に別名保存し、
`Build or Extend 16-Scene Skeleton`を実行します。既存TrackとPattern 1–5は保持し、
不足するPattern 6–16だけを追加します。

## 環境変数

| 変数 | 用途 | 既定 |
|---|---|---|
| `AIDJ_RENOISE_TOOL_DIR` | インストール済みTool directory | 自動検出 |
| `AIDJ_RENOISE_DATA_DIR` | Renoise data directory | `/mnt/c/Users/*/AppData/Roaming/Renoise`を探索 |
| `AIDJ_RENOISE_HOST` | WSLから見たWindows host | default gatewayを検出 |
| `AIDJ_RENOISE_PORT` | Renoise側OSC port | `8080` |
| `AIDJ_STATUS_BIND_HOST` | bridge status待受 | WSL IP (loopback環境では`127.0.0.1`) |
| `AIDJ_STATUS_PORT` | status port | `8088` |
| `AIDJ_RENOISE_OSC_BIND_HOST` | Renoise ToolのOSC待受 | `127.0.0.1` |

Renoiseとbridgeを同じOSで動かす場合はloopbackのまま使えます。標準的なWindows Renoise + WSL2 bridge構成では、Windows FirewallでRenoiseを許可した上で、bridge起動前に次を設定します。

```sh
export AIDJ_RENOISE_OSC_BIND_HOST=0.0.0.0
```

これによりbridgeがTool directoryへ`osc_bind_host.txt`を書きます。以後、環境変数を省略しても既存ファイルの値を保持します。`0.0.0.0`はLANから到達可能になるため、信頼できるネットワークでのみ使用してください。bridgeのstatus serverは`0.0.0.0`ではなく検出したWSL IPへbindします。

複数のWindowsユーザーにRenoiseが見つかる場合、自動検出は安全のため停止します。`AIDJ_RENOISE_TOOL_DIR`を明示してください。

Firewall helperは`tools/windows_firewall.ps1`です。管理者PowerShellで実行します。詳細は`docs/windows_firewall.md`を参照してください。

## PC再起動後の起動順

```sh
# 1. bridge。WSL IPを検出してToolへ渡すためRenoiseより先に起動
./start.sh

# 2. Renoise起動 -> 自作XRNSを開く -> Tools -> AIDJ -> Start Session

# 3. Go/No-Go再確認
./start.sh

# 4. 4 TUI
opencode --agent dj_conductor
opencode --agent dj_live_drums
opencode --agent dj_live_bass_fx
opencode --agent dj_live_pads
```

2回目の`start.sh`で`Renoise セッション アクティブ`を確認します。詳細は`docs/operator_manual.md`を参照してください。

診断・停止・再起動:

```sh
./tools/preflight.sh --live
./tools/stop.sh
./tools/restart.sh
```

## データ経路

```text
OpenCode agent
  -> host/osc/message_queue.py (atomic JSON publish)
  -> host/osc/outbox/*.json
  -> host/osc/osc_bridge.py
  -> OSC UDP -> Renoise Lua Tool :8080
  -> /ai/status -> bridge :8088
  -> host/state/session.json
```

outbox producerは最終`.json`へ直接書かず、`message_queue.queue_message()`を使用します。bridgeはint32/string以外のOSC引数を拒否します。

## OpenCodeロール

| ロール | 担当 |
|---|---|
| `dj_live_drums` | tracks 1, 2 |
| `dj_live_bass_fx` | tracks 3, 4, 7 |
| `dj_live_pads` | tracks 5, 6, 8 |
| `dj_conductor` | scene / tempo / transport / directives |

agentは`.opencode/agents/`、commandsは`.opencode/commands/`、共有ルールは`.opencode/rules/`にあります。tracked `opencode.json`はライブ操作向けに書込を許可します。保守的な権限例は`opencode.example.json`です。

## MIDI (Renoise Luaが唯一の標準入力経路)

Renoise MIDI Mapping XMLは使用しません。Lua Toolがデバイスを直接開くため、APC/MIDImixをRenoise Preferencesの通常MIDI Inputへ設定しないでください。

- MIDImix MUTE: Note `1,4,7,10,13,16,19,22`
- MIDImix REC/ARM/Solo: Note `3,6,9,12,15,18,21,24`
- MIDImix upper knobs (Pan): CC `16,20,24,28,46,50,54,58`
- MIDImix middle knobs (CUE): CC `17,21,25,29,47,51,55,59`
- MIDImix lower knobs (Macro): CC `18,22,26,30,48,52,56,60`
- MIDImix faders: CC `19,23,27,31,49,53,57,61`; master CC `62`
- APC pads: Note `0-63`; scene buttons `112-119`; FADER CTRL `100-107`; SHIFT `122`;
  Track faders CC `48-55`; Master CC `56`

16 scene構成が標準です。APC右側ボタンでScene 1–8、SHIFT併用でScene 9–16を起動します。

全割当の配置図は`docs/controller_map.md`、初回の操作練習は
`docs/controller_tutorial.md`を参照してください。

ライブ中に貼り付けるprompt集は`prompts/README.md`から選べます。

## 設定ファイルの役割

- `config/macros.yaml`: bridgeが`/ai/fx/macro`を展開する**実行設定**。ハードウェアCCは定義しません。
- `config/scenes.yaml`: operator/OpenCode向けsceneメタデータ。Lua runtimeは直接読みません。
- `config/fx_mapping.yaml`: XRNS構築時の設計資料。現状Lua runtimeは直接読みません。placeholderは実XRNSで確認が必要です。

## テスト

```sh
host/.venv/bin/python -m unittest discover -s tests/python -v
lua5.4 tests/lua/test_osc_protocol.lua
lua5.4 tools/AIDJ/validate_dryrun.lua tests/fixtures/valid.lua
bash -n start.sh tools/install.sh
```

Renoise実機roundtripはRenoise + AIDJ Session起動後のみ実行します。

```sh
host/.venv/bin/python host/osc/verify_roundtrip.py
```

テスト前のBPM/Mute/Solo/Volumeは`finally`で復元されます。ハードウェア検証項目は`docs/verification.md`を参照してください。

## トラブルシュート

- `host/state/bridge.log`: bridgeの起動・送信ログ。10 MiBを超えると`bridge.log.1`へローテートします。
- `host/osc/outbox/*.json`が残る: bridge停止またはproducer不具合。
- `host/osc/sent/*.err`: JSON/schema/型検証または送信に失敗した隔離メッセージ。内容を確認後、原因を直して再送してください。
- heartbeatが古い: RenoiseでAIDJ Sessionが停止、status bind/firewall、またはWSL IP設定を確認します。
- heartbeatは更新されるが操作が反映されない: `Tools → AIDJ → Diagnostics → OSC Internal Loopback (BPM 175)`を実行します。`OSC Status`が`received=1 last=/ai/bpm error=-`ならTool内部は正常です。
- Internal Loopbackが`received=0`のまま: Reload Tools前のUDP socketがRenoiseプロセス内に残っている可能性があります。XRNSを保存してRenoiseを完全終了し、PowerShellの`Get-NetUDPEndpoint -LocalPort 8080 -ErrorAction SilentlyContinue`が何も返さないことを確認してから再起動します。
- Internal Loopbackは通るがWSLから届かない: Windows Defender FirewallでRenoiseのUDP 8080を許可します。Windows 11のHyper-V Firewallが有効な環境ではWSL用規則も確認してください。

## License

コードと文書はMIT Licenseです。Renoise、controller資料、sample、preset、plugin等の権利は
含みません。`LICENSE`と`THIRD_PARTY_NOTICES.md`を参照してください。

## セキュリティ

- 公開設定にOAuth token/API key/個人パスを含めません。
- Renoise OSC serverは既定で`127.0.0.1` bindです。
- `validate_dryrun.lua`は生成Luaを**実行しません**。禁止文字列の検査と構文確認のみで、完全なsandboxではありません。
- `host/state/**`, outbox, sent, logs, XRNSはruntime/local dataとしてGit管理外です。
