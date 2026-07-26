param(
  [string]$RenoisePath = "C:\Program Files\Renoise 3.5.4\Renoise.exe",
  [string]$WslAddress = "",
  [switch]$Remove
)

$ErrorActionPreference = "Stop"
$ruleName = "AIDJ-Renoise-OSC-8080"
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw "Run this script from an Administrator PowerShell."
}

if ($Remove) {
  Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
  Write-Host "Removed $ruleName"
  exit 0
}

if (-not (Test-Path $RenoisePath)) {
  throw "Renoise executable not found: $RenoisePath"
}
if (-not $WslAddress) {
  $WslAddress = ((wsl.exe hostname -I) -split '\s+')[0]
}
$parsedAddress = $null
if (-not [Net.IPAddress]::TryParse($WslAddress, [ref]$parsedAddress)) {
  throw "Could not determine a valid WSL IP address. Pass -WslAddress explicitly."
}
Remove-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
New-NetFirewallRule `
  -Name $ruleName `
  -DisplayName "AIDJ Renoise OSC UDP 8080" `
  -Direction Inbound `
  -Action Allow `
  -Protocol UDP `
  -LocalPort 8080 `
  -Program $RenoisePath `
  -RemoteAddress $WslAddress `
  -Profile Any | Out-Null
Write-Host "Installed $ruleName for $RenoisePath (WSL source: $WslAddress)"
