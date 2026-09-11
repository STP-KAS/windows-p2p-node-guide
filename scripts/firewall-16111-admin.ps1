# Run as Administrator. Opens inbound TCP 16111 only for this kaspad.exe.
# Edit $exe so it matches (Get-CimInstance Win32_Process -Filter "Name='kaspad.exe'").ExecutablePath
$ErrorActionPreference = 'Stop'
$exe = 'C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe'
if (-not (Test-Path $exe)) { throw "kaspad.exe not found: $exe" }

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) { throw 'Run this in an Administrator PowerShell.' }

Write-Host "exe=$exe"
netsh advfirewall firewall delete rule name="Kaspa P2P 16111" | Out-Host
netsh advfirewall firewall add rule name="Kaspa P2P 16111" dir=in action=allow protocol=TCP localport=16111 program="$exe" | Out-Host
netsh advfirewall firewall show rule name="Kaspa P2P 16111" verbose | Out-Host
