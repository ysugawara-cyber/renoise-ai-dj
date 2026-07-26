# Fresh Install

## WSL Packages

```sh
sudo apt update
sudo apt install -y git python3 python3-venv python3-pip lua5.4 util-linux procps iproute2
```

OpenCodeは公式手順で導入する: https://opencode.ai/docs/

Renoise 3.5.xをWindowsへインストールし、一度起動してdata directoryを作成してから
bootstrapへ進む。

## Bootstrap

```sh
git clone https://github.com/ysugawara-cyber/renoise-ai-dj.git
cd renoise-ai-dj
./setup.sh
```

Windows Renoise + WSL2を検出すると、local `.env`へ
`AIDJ_RENOISE_OSC_BIND_HOST=0.0.0.0`を設定する。管理者PowerShellで
`tools/windows_firewall.ps1`を実行し、現在のWSL IPだけにUDP 8080を許可する。WSLのIPが
再起動後に変わった場合は再実行する。詳細は`docs/windows_firewall.md`を参照する。

## Authentication

```sh
opencode auth login
```

OpenAIまたは利用するproviderを認証する。tokenはリポジトリへ保存しない。
tracked `opencode.json`のmodelを利用できない場合は、利用可能なmodel IDへ変更してから4 TUIを再起動する。

## Renoise Song

1. Renoiseで`Tools -> Scripting -> Reload Tools`。
2. 新規の空Songを開く。
3. `Tools -> AIDJ -> Setup -> Build Turnkey Song (Fresh Song Only)`。
4. `Tools -> AIDJ -> Setup -> Validate Current Song`。
5. XRNSを保存する。

fallback音源は第三者sampleを含まない。音質確認後、同じinstrument名を維持して利用者自身の
sampleへ差し替えられる。

## Start And Verify

```sh
./start.sh
```

RenoiseでXRNSを開き、`Tools -> AIDJ -> Start Session`を実行してから再度`./start.sh`を実行する。

```sh
./tools/preflight.sh --live
host/.venv/bin/python host/osc/verify_roundtrip.py
```

実機操作は`docs/controller_tutorial.md`を参照する。
