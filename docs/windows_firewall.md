# Windows Firewall

Windows RenoiseとWSL2 bridgeのOSC通信には、RenoiseへのUDP 8080 inbound許可が必要。

管理者PowerShellで実行する。

WSL homeへcloneした場合は、PowerShellから
`\\wsl.localhost\<Distribution>\home\<User>\renoise-ai-dj\tools\windows_firewall.ps1`
のようなUNC pathでscriptを指定する。`/mnt/c`以下へcloneした場合は通常の`C:\...` pathを使う。

```powershell
Set-ExecutionPolicy -Scope Process Bypass
& "C:\path\to\renoise-ai-dj\tools\windows_firewall.ps1"
```

scriptは`wsl.exe hostname -I`から現在のWSL IPを取得し、その送信元だけを許可する。複数の
distributionを使う場合は`-WslAddress "172.x.x.x"`でAIDJを実行するdistributionのIPを指定する。
WSL再起動後にIPが変わった場合はscriptを再実行する。

Renoiseを別directoryへインストールした場合:

```powershell
& "C:\path\to\windows_firewall.ps1" -RenoisePath "D:\Apps\Renoise\Renoise.exe"
```

削除と確認:

```powershell
& "C:\path\to\windows_firewall.ps1" -Remove
Get-NetFirewallRule -Name "AIDJ-Renoise-OSC-8080"
Get-NetUDPEndpoint -LocalPort 8080 -ErrorAction SilentlyContinue
```

heartbeatは届くが操作が反映されない場合、Renoiseを完全終了し、古いUDP 8080 endpointが
消えたことを確認してから再起動する。
