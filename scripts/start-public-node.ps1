# Single public rusty-kaspa node. Do not start MyKAI / a second kaspad while this runs.
# Edit $exe if kaspad.exe is not next to this script.
$ErrorActionPreference = 'Stop'
$exe = Join-Path $PSScriptRoot '..\kaspad.exe'
if (-not (Test-Path $exe)) {
    $exe = 'C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe'
}
$resolved = Resolve-Path $exe -ErrorAction SilentlyContinue
if (-not $resolved) { throw 'kaspad.exe not found. Set $exe in this script.' }
$exe = $resolved.Path

$existing = Get-CimInstance Win32_Process -Filter "Name='kaspad.exe'"
if ($existing) {
    Write-Host "kaspad already running PID $($existing.ProcessId) — not starting a second one."
    $existing | Select-Object ProcessId, ExecutablePath, CommandLine | Format-List
    exit 0
}

$pub = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).Trim()
if ($pub -notmatch '^\d+\.\d+\.\d+\.\d+$') { throw "could not get public IPv4 (got: $pub)" }
Write-Host "Starting $exe"
Write-Host "advertising ${pub}:16111  (P2P 16111 public, RPC localhost only)"

& $exe `
    --utxoindex `
    --listen=0.0.0.0:16111 `
    --rpclisten=127.0.0.1:16110 `
    --rpclisten-borsh=127.0.0.1:17110 `
    --rpclisten-json=127.0.0.1:18110 `
    --externalip="${pub}:16111" `
    --outpeers=8 `
    --maxinpeers=128 `
    --ram-scale=0.5
