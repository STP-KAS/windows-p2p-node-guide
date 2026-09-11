# Windows P2P node guide

Make **one** [rusty-kaspa](https://github.com/kaspanet/rusty-kaspa) node **public**.

Public only means this: **inbound TCP 16111** reaches that `kaspad.exe`. Talking to the network on outbound peers is not public yet.

This is a home-PC checklist. Not Kaspa core. Not a wallet guide. Do not expose RPC.

Pin: [rusty-kaspa releases](https://github.com/kaspanet/rusty-kaspa/releases/latest) (this desk used **v2.0.1**).

---

## Read this first

| Do | Do not |
| --- | --- |
| Run **one** `kaspad.exe` | Start MyKAI, Kaspa NG, KDX, or a second `kaspad` on the same datadir |
| Open **TCP 16111** | Forward **16110** (gRPC) |
| Bind RPC to `127.0.0.1` | Put RPC on the internet |
| Keep the node past IBD (accepting tip blocks) | Test inbound during a full sync and call it broken |
| Use the **same** `kaspad.exe` path in the firewall rule | Point `program=` at MyKAI’s copy while this binary is the one listening |

Two kaspads on one datadir panic:

```text
Failed to create lock file: ...\kaspa-mainnet\datadir\meta\LOCK
The process cannot access the file because it is being used by another process.
```

If a node is already at tip, **leave it running**. Do not wipe the datadir to “make a new one.” Public is a port, not a resync.

---

## What you will have

```text
Internet  --TCP 16111-->  your public IPv4  -->  router forward
                                              -->  Windows firewall
                                              -->  kaspad.exe listening 0.0.0.0:16111
```

RPC stays on this PC only:

| Port | What | Public? |
| ---: | --- | --- |
| **16111** | P2P | Yes — this is the whole guide |
| 16110 | gRPC | No |
| 17110 | wRPC Borsh | No |
| 18110 | wRPC JSON | No |

---

## 0. See what is already running

Normal PowerShell (not admin):

```powershell
(Get-CimInstance Win32_Process -Filter "Name='kaspad.exe'").CommandLine
Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue |
  Where-Object { $_.LocalPort -in 16110,16111 } |
  Format-Table LocalAddress, LocalPort, OwningProcess
```

| Result | Meaning |
| --- | --- |
| One line, your `kaspad.exe` path, listen on `0.0.0.0:16111` | Keep it. Do not start another. |
| MyKAI / another folder | You are mixing stacks. Stop the extra node first. |
| Nothing | Start one node (step 2). |

Stop extras (only if you intend to):

```powershell
Get-Process kaspad, 'MyKAI Node' -ErrorAction SilentlyContinue | Stop-Process
```

Turn off MyKAI autostart if it keeps coming back:

```powershell
Remove-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' `
  -Name 'electron.app.MyKAI Node' -ErrorAction SilentlyContinue
```

---

## 1. Get the node binary

1. Download the Windows zip from [rusty-kaspa releases (latest)](https://github.com/kaspanet/rusty-kaspa/releases/latest).  
   File name looks like `rusty-kaspa-v2.0.1-win64.zip`.
2. Unpack to a folder you will keep. Example:

```text
C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe
```

Spaces in the path are fine. Quotes in commands are not optional.

Check the version:

```powershell
& 'C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe' --version
```

You want `kaspad 2.0.1` (or whatever *latest* is on that releases page).

Default data dir on Windows:

```text
%LOCALAPPDATA%\rusty-kaspa\kaspa-mainnet\
```

That is the chain. Wallets live elsewhere (for example `%USERPROFILE%\.kaspa`). Do not delete wallets because you are making the node public.

---

## 2. Start one public P2P process

Skip this if step 0 already shows a live `kaspad` on 16111.

In a **normal** PowerShell, from the folder that contains `kaspad.exe`, or with a full path:

```powershell
$exe = 'C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe'

# Refuse a second process
$have = Get-CimInstance Win32_Process -Filter "Name='kaspad.exe'"
if ($have) { $have | Select-Object ProcessId, ExecutablePath, CommandLine; throw 'kaspad already running' }

$pub = (Invoke-RestMethod -Uri 'https://api.ipify.org' -TimeoutSec 10).Trim()
Write-Host "advertising ${pub}:16111"

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
```

Leave that window open. Closing it can kill the node if this is how you launched it.

A copy of this lives in [`scripts/start-public-node.ps1`](scripts/start-public-node.ps1).

What good logs look like:

```text
kaspad v2.0.1
P2P Server starting on: 0.0.0.0:16111
GRPC Server starting on: 127.0.0.1:16110
External address is publicly routable 203.0.113.10:16111
IBD ... completed successfully
Accepted ... blocks ... via relay
```

`External address is publicly routable` only means the IPv4 is a public address. It is **not** proof that inbound 16111 works. That is step 6.

Do **not** pass `--disable-upnp` unless you know you will set a manual forward. UPnP can open 16111; a manual forward is more reliable.

---

## 3. Firewall (admin PowerShell)

Windows will not let a normal window add this rule. Open **Start → PowerShell → Run as administrator**.

Put **your** `kaspad.exe` path in `program=`. If the running node is MyKAI, this path is wrong.

```powershell
netsh advfirewall firewall delete rule name="Kaspa P2P 16111"
netsh advfirewall firewall add rule name="Kaspa P2P 16111" dir=in action=allow protocol=TCP localport=16111 program="C:\Users\YOU\Documents\kaspa\kaspa kaspad\kaspad.exe"
netsh advfirewall firewall show rule name="Kaspa P2P 16111"
```

You want: **Enabled Yes**, **Direction In**, **Protocol TCP**, **LocalPort 16111**, **Action Allow**, **Program** = that same exe.

A copy of this lives in [`scripts/firewall-16111-admin.ps1`](scripts/firewall-16111-admin.ps1). Edit the path at the top, then run the file **as administrator**.

Network profile should be **Private** on the home Ethernet/Wi‑Fi (not Guest). Check:

```powershell
Get-NetConnectionProfile | Format-Table Name, InterfaceAlias, NetworkCategory
```

---

## 4. This PC’s LAN IP

Normal PowerShell:

```powershell
Get-NetIPAddress -AddressFamily IPv4 |
  Where-Object { $_.PrefixOrigin -ne 'WellKnown' } |
  Format-Table IPAddress, InterfaceAlias
```

Use the **Ethernet or Wi‑Fi** address, usually `192.168.x.x`. Not `127.0.0.1`. Not WSL. Not Radmin VPN (`26.x`).

Give that IP a **DHCP reservation** on the router so it does not change. Port forwards follow the LAN IP, not the PC name.

---

## 5. Router port forward

Router admin is often `192.168.0.1` or `192.168.1.1` (this desk’s gateway was `192.168.128.1`). Browser, or the ISP app if the box has no web UI.

| Field | Value |
| --- | --- |
| Service name | Kaspa P2P |
| Protocol | **TCP** |
| External port | **16111** |
| Internal port | **16111** |
| Internal IP | the LAN IP from step 4 |

Save. Do **not** forward 16110.

If the router has UPnP and kaspad was started **without** `--disable-upnp`, it may already have mapped 16111. Check the UPnP list. A **manual** forward is the one you can still explain next month.

Also reserve the LAN IP (DHCP reservation / static lease) while you are in that UI.

---

## 6. Check you are not behind CGNAT

```powershell
nslookup myip.opendns.com resolver1.opendns.com
Invoke-RestMethod https://api.ipify.org
```

Compare that public IPv4 to the **WAN / internet IP** on the router status page.

| Compare | Meaning |
| --- | --- |
| Same public IPv4 | You can host. |
| Different IP, or WAN is `100.64.x.x` / `10.x` / CGNAT | Inbound will never work on this home line. You need a VPS or IPv6, not more local commands. |

A hostname like `*.adsl-dyn.isp.example` with a real public IPv4 is **dynamic public**, not CGNAT. The IP can still change; then update `--externalip` and restart **once**.

---

## 7. Prove inbound

Wait until the log is **past IBD** and accepting tip blocks.

### Local (only proves the process listens)

```powershell
Test-NetConnection 127.0.0.1 -Port 16111
```

`TcpTestSucceeded : True` is necessary and not sufficient.

### Real test (from the internet)

From a phone on **mobile data** (Wi‑Fi off), or a port-check site, test **your public IPv4:16111 TCP**.

Example: [canyouseeme.org](https://www.canyouseeme.org/) — port `16111`.

Good:

```text
Success: I can see your service on x.x.x.x on port (16111)
Your ISP is not blocking port 16111
```

Hairpin NAT (testing your public IP from the same LAN) often **fails** even when the phone test works. Ignore the LAN-to-WAN self-test.

### In the kaspad log

Look for **incoming** peers, not only:

```text
P2P Connected to outgoing peer ... (outbound: N)
```

Inbound Kaspa peers can lag minutes after the port is open. The phone / canyouseeme check is the public-node proof. Outbound-only logs mean the node is useful to *you*; they do not mean it is public.

---

## 8. If inbound stays 0

Work this list in order:

1. Second `kaspad` still running (LOCK errors in `rusty-kaspa_err.log`)
2. Firewall rule missing, or `program=` is the wrong exe
3. Forward to the wrong LAN IP (DHCP changed it)
4. ISP CGNAT
5. Windows network profile **Public**, or Guest Wi‑Fi / AP isolation
6. Radmin VPN / extra default route advertising the wrong address — bind `--externalip` to the **home** public IPv4
7. Node still in IBD

---

## 9. Background vs always-on

A node started from a PowerShell window or a Grok/agent job is **background for this login**. It is not a Windows service.

- Closing that job can kill `kaspad`.
- A reboot will not bring it back until you start it again.
- `scripts/start-public-node.ps1` refuses to start a second copy.

To survive reboot: Task Scheduler (user logon, highest privileges only if you need them) or a service wrapper. That is extra. This guide’s job is inbound **16111**.

---

## Copy-paste scripts

| File | When |
| --- | --- |
| [`scripts/start-public-node.ps1`](scripts/start-public-node.ps1) | Normal PowerShell. Starts one public P2P node. Looks up public IPv4. |
| [`scripts/firewall-16111-admin.ps1`](scripts/firewall-16111-admin.ps1) | **Run as administrator.** Named rule `Kaspa P2P 16111`. |

Edit the `$exe` path at the top of each script so it matches the process from step 0.

---

## Sources

- Node: [kaspanet/rusty-kaspa](https://github.com/kaspanet/rusty-kaspa)
- Latest Windows zip: [releases/latest](https://github.com/kaspanet/rusty-kaspa/releases/latest)
- Official builder door: [kaspa.org/build](https://kaspa.org/build)

Desk: [STP-KAS](https://github.com/STP-KAS). Not kaspanet.
