# Unified SmartDNS + Transparent SNI Proxy Installer

[![Donate — CloudTips / SBP](https://img.shields.io/badge/Donate-CloudTips_%2F_SBP-0066FF?style=for-the-badge)](https://pay.cloudtips.ru/p/9785e813)

**Language:** [Русский](README.md) | **English**

[![Version](https://img.shields.io/badge/version-v2.10.0--stealth-blue.svg)](https://github.com/EvgenyElizarenko/smartdns-installer/releases/tag/v3.0-stealth)
[![OS](https://img.shields.io/badge/OS-Debian%2012%2F13%20%7C%20Ubuntu%2022.04%2F24.04-orange.svg)](#4-technical-requirements)
[![Interface](https://img.shields.io/badge/CLI-RU%20%7C%20EN-green.svg)](#51-interface-language-selection-russian--english)
[![ShellCheck](https://github.com/EvgenyElizarenko/smartdns-installer/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/EvgenyElizarenko/smartdns-installer/actions)

A unified transactional Bash installer for deploying a resilient **SmartDNS (DoH + DoT) + Transparent SNI Proxy (Xray-core) + Stealth Cover Site (Nginx)** stack on your own VPS, featuring automated wildcard TLS certificate issuance via Cloudflare DNS-01 and dynamic client IP authorization.

> [!IMPORTANT]
> This script is NOT intended to bypass Roskomnadzor (RKN) censorship or access websites restricted within the Russian Federation! Its sole purpose is to provide access to international AI services that are geo-restricted for users in certain regions.

---

## What's New in v3.0-stealth

- **Interactive Startup Menu (Launcher):** running without arguments (`sudo ./smartdns-installer-v3.0-stealth.sh`) opens a menu covering all modes (`Initial Server Setup`, SmartDNS installation, status, tests, updates, domain groups, DNS backend switching, DoT whitelist, IP sync, domain change, Cover Site, backup, rollback, and uninstall) with single-prompt language selection.
- **Initial Server Setup (`--initial-setup`):** interactive 10-step pre-installation phase — non-interactive OS update, `sudo` check/install, `root` password change, administrative user creation/selection in the `sudo` group, SSH audit, and a 16-point additional security audit (`fail2ban` with `backend=systemd`, `unattended-upgrades`, NTP, `swap`). State is saved in `/var/lib/oxidns-installer/initial-setup.env` (`0600`) without storing passwords, passphrases, or private keys.
- **Safe SSH Hardening (`Backup → Validate → Apply/Rollback`):** unified pipeline backing up to `/var/lib/oxidns-installer/ssh-backup/` (`initial/.sealed` + `SHA-256`), writing `/etc/ssh/sshd_config.d/00-smartdns-hardening.conf` (and `ssh.socket.d/override.conf` for socket activation), verifying via `sshd -t` and `sshd -T -C` with automatic rollback on failure. Supports `Ed25519` / `RSA 4096` key generation with Windows, Linux, and macOS transfer guides, two-phase SSH port switching, stack port protection, and strict pre-checks before disabling `PasswordAuthentication` or `PermitRootLogin` (the local `root` account is not locked).
- **Centralized `Reboot Lock`:** strict reboot prohibition (`/var/lib/oxidns-installer/reboot-lock.env`, `0600`, `needrestart` suppression, `/var/run/reboot-required` and external trigger tracking) across all phases until SmartDNS is installed, running, and passes DNS verification; deferred reboot is offered only with explicit `YES` confirmation.
- **Firewall SSH Guard & Startup Stability:** automatic UFW allow rules for all active SSH ports prior to enabling blocking rules, `TimeoutStartSec=60s`, and waiting for DNS backend readiness before starting `xray.service`.

## Table of Contents

1. [Purpose and Key Features](#1-purpose-and-key-features)
2. [Architecture and Stealth Camouflage](#2-architecture-and-stealth-camouflage)
3. [Comparison of Supported DNS Engines](#3-comparison-of-supported-dns-engines)
4. [Technical Requirements](#4-technical-requirements)
5. [Installation and Initial Setup](#5-installation-and-initial-setup)
6. [CLI Command Reference](#6-cli-command-reference)
7. [Client Device Configuration](#7-client-device-configuration)
8. [Security, Backups, and Diagnostics](#8-security-backups-and-diagnostics)
9. [Troubleshooting](#9-troubleshooting)

---

## 1. Purpose and Key Features

This script automates the end-to-end deployment and maintenance of a personal SmartDNS server:

* **Bilingual Command-Line Interface (`RU / EN`):** Interactive prompt to select Russian (default) or English on every run, as well as seamless execution in non-interactive environments (`cron`, `systemd`, `EOF`).
* **Transactional Installation with Automatic Rollback:** Creates a full snapshot of configuration files and firewall rules prior to applying changes; if any step fails (`ERR` trap), the system automatically rolls back to its initial state.
* **Hot-Swappable DNS Engines:** Supports both **OxiDNS** (Rust) and **AdGuardHome** (Go), allowing live switching via `--switch-engine` without reissuing TLS certificates or changing client endpoints.
* **Unified TLS SNI Profile on Port `443/TCP`:** A single second-level domain (`ROOT_DOMAIN`) simultaneously serves the decoy Cover Site, the secret DNS-over-HTTPS endpoint (`/resolve/<SECRET>`), the web-based IP authorization portal (`/auth/<SECRET>`), and the transparent SNI proxy for target services.
* **Client Real-IP Preservation (`PROXY protocol v1`):** Xray-core forwards the original client IP address to Nginx, preventing source addresses from being masked as `127.0.0.1` in access logs.
* **Dynamic `ipset` Authorization with 24-Hour TTL:** Access to the SNI proxy and (optionally) DoT port `853/TCP` is granted exclusively to IP addresses authorized via secret DoH, secret DoT SNI, or the `/auth/` web portal.
* **Integrity Verification and Least Privilege:** Validates SHA-256 checksums of downloaded release binaries and runs all runtime services (`xray`, `oxidns`, `adguardhome`, `nginx`) under dedicated unprivileged system accounts.
* **Built-In Self-Test Suite (`--test`):** 25 functional and negative automated tests covering DNS rewrites, `NODATA` responses for `AAAA`/`HTTPS (TYPE65)`, HTTP 404 path masking, firewall chains, and internal port isolation.

---

## 2. Architecture and Stealth Camouflage

### Traffic Processing Flow

```text
Client (DoH / DoT / HTTPS)
  │
  ├──► TCP 443 (External Interface)
  │      │
  │      ▼
  │    Xray-core (unprivileged user, TLS SNI Sniffing, port 8444/TCP via PREROUTING)
  │      ├── SNI = ROOT_DOMAIN ──► Nginx (127.0.0.1:9444, PROXY protocol v1)
  │      │                           ├── /resolve/<DOH_PATH> ──► DoH (127.0.0.1:8053) + auto-add IP to ipset
  │      │                           ├── /auth/<DOH_PATH>    ──► Web-based client IP authorization in ipset (TTL 86400s)
  │      │                           └── / (and any other paths) ► Unique procedural Cover Site (HTTP 200 / 404)
  │      │
  │      └── SNI ∈ Target domains (and IP ∈ ipset smartdns_clients)
  │            └──► Transparent TLS proxying to destination server (no traffic decryption)
  │
  └──► TCP 853 (External Interface, optional ipset filtering)
         │
         ▼
       Xray-core (DoT SNI Router, port 8853/TCP)
         ├── SNI = DOT_HOST ──► Local DoT upstream + auto-add IP to ipset
         └── Any other SNI  ──► Connection reset (blackhole) without presenting a certificate
```

### Core Anti-Detection Mechanisms
1. **Procedural Unique Cover Site:** During installation, a bespoke multi-section static website (HTML5 + CSS3) is generated with randomized industry theme, brand identity, color palette, and layout—free of technical keywords or server IP leaks in the markup. Running `--update` preserves the existing website; regeneration occurs only when explicitly requested via `--regenerate-cover`.
2. **Secret Route Masking:** Any request to `/resolve/*` or `/auth/*` lacking the exact 48+ character secret path returns a standard web server `HTTP 404` response.
3. **IPv6 and SVCB Leak Suppression:** For proxied domains, the DNS engine returns `NOERROR/NODATA` for `AAAA` and `HTTPS/SVCB (TYPE65)` queries, preventing browsers from bypassing the IPv4 proxy over IPv6 or QUIC/HTTP3.

---

## 3. Comparison of Supported DNS Engines

| Feature | 1) OxiDNS (Rust) | 2) AdGuardHome (Go) |
| :--- | :--- | :--- |
| **RAM Footprint** | Minimal (~15–30 MB) | Moderate (~60–120 MB) |
| **Pipeline Architecture** | Native `geosite.dat` processing and YAML sequence rules | `$dnsrewrite` rules and filter lists |
| **NODATA Support (`AAAA` / `TYPE65`)** | Native via `hosts` / `reject` | Via `$dnsrewrite=NOERROR` rules |
| **Local Web Statistics UI** | None (managed via config and CLI) | Included (`http://127.0.0.1:8053`, accessible via SSH tunnel only) |
| **Supported CPU Architectures** | `x86_64` (`amd64`) only | `x86_64` (`amd64`) and `aarch64` (`arm64`) |

---

## 4. Technical Requirements

### 4.1. Server Environment (OS, Kernel, and Resources)
| Component | Minimum Requirements | Recommended / Notes |
| :--- | :--- | :--- |
| **Operating System** | Debian 12 (Bookworm), Debian 13 (Trixie), Ubuntu 22.04 LTS, Ubuntu 24.04 LTS | Clean minimal OS installation without pre-installed hosting control panels |
| **CPU Architecture** | `x86_64` (`amd64`) or `aarch64` (`arm64`) | `OxiDNS` supports `x86_64` only; `AdGuardHome` runs on both `x86_64` and `aarch64` |
| **Memory (RAM)** | **512 MB** | **1 GB** or more (verified automatically during `--preflight`) |
| **Disk Space** | **1.5 GB** free space | Required for binaries, `geosite.dat` databases, logs, and transactional backups |
| **Linux Kernel & Modules** | Linux Kernel 5.10+, `systemd` | Requires `netfilter` (`iptables`/`ip6tables`) and `ipset` (`hash:ip` with `timeout` support) |
| **Privileges** | `root` (`sudo`) access to execute the script | All runtime services (`xray`, `oxidns`, `adguardhome`, `nginx`) run as unprivileged users |

### 4.2. Network, Ports, and Software Stack
* **Public IP Address:** A dedicated static public **IPv4 address** on the primary network interface (deployments behind provider NAT / CG-NAT are not supported). Global **IPv6** is optional—when present, `ip6tables` and `ipset` rules are configured automatically.
* **Inbound Ports (must be open in your cloud provider's firewall):**
  * `22/TCP` (or your custom SSH port) — administrative access;
  * `80/TCP` — HTTP redirect and baseline checks;
  * `443/TCP` — HTTPS Cover Site, DoH endpoint (`/resolve/...`), authorization portal (`/auth/...`), and transparent SNI proxy;
  * `853/TCP` — DNS-over-TLS (DoT).
* **Outbound Connectivity:** Unrestricted outbound access over `443/TCP` and `53/UDP+TCP` to Cloudflare API, Let's Encrypt endpoints, GitHub Releases (for downloading binaries and `GeoHideDNS`/`geosite.dat` lists), and DoH upstreams (`1.1.1.1`, `8.8.8.8`).
* **No Conflicting Services:** No other web servers (`apache2`, `caddy`, custom `nginx`), local DNS resolvers, or proxy panels may bind to ports `80`, `443`, `853`, `5353`, `8053`, `8443`, `8444`, `8853`, `9443`, or `9444`. If **Docker** is installed, the installer automatically inserts `SMARTDNS_PREROUTING` chains ahead of container rules.

### 4.3. Domain, DNS Provider, and Client Requirements
* **Domain and Cloudflare:**
  * Your own second-level domain (`ROOT_DOMAIN`) delegated to **Cloudflare** nameservers.
  * A Cloudflare API Token with **`Zone — DNS — Edit`** permission for the target zone.
  * All DNS records (`@`, `*`, DoT subdomain) must remain strictly in **DNS Only (grey cloud)** mode—enabling Cloudflare proxying (orange cloud) will break SNI proxying and DoT.
* **Client Devices:**
  * Native or app-level support for **DNS-over-HTTPS (RFC 8484)** or **DNS-over-TLS (RFC 7858)**.
  * **TLS 1.2 / 1.3** with unencrypted **SNI (Server Name Indication)** extension enabled (disable ECH/ESNI for target domains).
  * ISP fallback DNS disabled (`peerdns = 0` on routers) to prevent DNS queries from leaking outside SmartDNS.

---

## 5. Installation and Initial Setup

### 5.1. Interface Language Selection (Russian / English)

On every interactive launch, the script prompts for the user interface language before executing any operations:

```text
Выберите язык интерфейса / Select interface language:

1) Русский (по умолчанию)
2) English

Ваш выбор / Your choice [1]:
```

* **`1` or `Enter`** — activates the Russian interface (default).
* **`2`** — switches all menus, prompts, diagnostic messages, reports, and `--test` self-test output to English.
* **Non-interactive execution (`cron`, `systemd`, `/dev/null` or `EOF` input):** When no interactive TTY is attached or `stdin` reaches `EOF`, the script proceeds without blocking and defaults to Russian (or uses the language explicitly set via the `SCRIPT_LANG=en` or `SCRIPT_LANG=ru` environment variable).

### 5.2. Downloading and Running the Installer

1. **Download the script and make it executable:**
   ```bash
   curl -fsSL "https://raw.githubusercontent.com/EvgenyElizarenko/smartdns-installer/refs/heads/main/smartdns-installer-v3.0-stealth.sh" -o smartdns-installer.sh
   chmod +x smartdns-installer.sh
   ```

2. **Run a read-only server preflight check:**
   ```bash
   sudo ./smartdns-installer.sh --preflight
   ```

3. **Launch the interactive installation wizard:**
   ```bash
   sudo ./smartdns-installer.sh --install
   ```
   The wizard will prompt for:
   * DNS engine selection (`1` — OxiDNS, `2` — AdGuardHome);
   * primary second-level domain (`ROOT_DOMAIN`, e.g. `example.com`);
   * DoT subdomain prefix (`DOT_HOST`, defaults to a randomly generated 10-character subdomain);
   * automatic generation or manual entry of a 48-character secret `DOH_PATH`;
   * enabling and configuring `ipset` filtering mode for DoT (`shared` or `separate`);
   * optional domain filters (`EXCLUDE_GOOGLE_SYS`, `INCLUDE_XBOX_IPIFY`);
   * Cloudflare API Token (`Zone:DNS:Edit`) and contact email for Let's Encrypt certificates.

4. **Verify the deployed stack after installation:**
   ```bash
   sudo ./smartdns-installer.sh --test
   ```

---

## 6. CLI Command Reference

```text
Usage: sudo ./smartdns-installer.sh <COMMAND>
```

| Command | Description |
| :--- | :--- |
| `--help`, `-h` | Display help message listing all supported commands and exit |
| `--preflight` | Check OS, kernel, RAM, disk, network, ports, and engine compatibility (read-only) |
  --initial-setup                  Interactive Initial Server Setup & SSH Security Hardening
| `--install` | Run interactive transactional installation of the full stack |
| `--status` | Display active DNS engine, `systemd` services/timers state, and `ipset` entries |
| `--test` | Execute 25 functional and negative self-tests across the entire proxy pipeline |
| `--switch-engine [oxidns\|adguardhome]` | Transactionally switch the active DNS engine on a live server |
| `--regenerate-cover` | Generate a new unique Cover Site while backing up the previous one |
| `--sync-ip` | Auto-detect a new server IPv4/IPv6 and sync configs, firewall, and Cloudflare records |
| `--change-domain [NEW_DOMAIN]` | Change the primary domain (`ROOT_DOMAIN`) and reissue TLS certificates preserving secrets |
| `--update` | Safely update Xray/DNS binaries and domain lists (preserving the existing Cover Site) |
| `--backup` | Create an on-demand full backup of configurations, TLS keys, and firewall rules |
| `--rollback [PATH]` | Roll back system state to the latest (or specified) backup snapshot |
| `--uninstall` | Stop and disable all stack services and remove `SMARTDNS_*` firewall chains |
| `--whitelist-status` | Show DoT IP whitelist (`853/TCP`) state, set mode, and authorized IPs with remaining TTL |
| `--whitelist-toggle [on\|off]` | Enable, disable, or toggle IP filtering on DoT port `853/TCP` |
| `--whitelist-mode [shared\|separate]` | Switch DoT whitelist set mode (`shared` with DoH or `separate` isolated sets) |
| `--whitelist-add <IP>` | Manually add a single IPv4 or IPv6 address to the whitelist (24-hour TTL) |
| `--whitelist-remove <IP>` | Immediately remove a single IPv4 or IPv6 address from the whitelist |
| `--whitelist-flush` | Flush all authorized IPv4/IPv6 addresses from the DoT whitelist |

---

## 7. Client Device Configuration

Upon completing `--install`, the script outputs and stores three personal connection endpoints in `/var/lib/oxidns-installer/secrets.env` (`chmod 0600`):
* **DoH URL:** `https://<ROOT_DOMAIN>/resolve/<DOH_PATH>`
* **Web-Auth URL:** `https://<ROOT_DOMAIN>/auth/<DOH_PATH>`
* **DoT Hostname (`853/TCP`):** `<DOT_HOST>`

### 7.1. Connection Steps

1. **Authorize your client IP address (when using a dynamic IP or when DoT whitelist is enabled):**
   * **DoH clients** authorize automatically on their first DNS query.
   * **DoT clients** should open `https://<ROOT_DOMAIN>/auth/<DOH_PATH>` in a browser on the device or local network (or, if `DOT_WHITELIST_ENABLED` is disabled, the first DoT query with the valid `DOT_HOST` SNI authorizes the IP automatically).
2. **Configure DNS on your device:**
   * **Android (9+):** *Settings → Network & internet → Private DNS* → select *Private DNS provider hostname* and enter `<DOT_HOST>`.
   * **iOS / macOS:** Install an Apple Configuration Profile (`.mobileconfig`) configured for DNS-over-HTTPS `https://<ROOT_DOMAIN>/resolve/<DOH_PATH>` or DNS-over-TLS `<DOT_HOST>`.
   * **Windows 11:** *Settings → Network & internet → Ethernet / Wi-Fi → DNS server assignment (Manual)* → enter your server\x27s IPv4 address, set **DNS over HTTPS** to **On (manual template)**, and enter `https://<ROOT_DOMAIN>/resolve/<DOH_PATH>`.
   * **Web Browsers (Chrome / Edge / Firefox):** In Privacy & Security settings, enable *Use Secure DNS* with a custom provider template set to `https://<ROOT_DOMAIN>/resolve/<DOH_PATH>`.
   * **Routers (OpenWrt / Keenetic):** Configure `https-dns-proxy` (DoH) or `stubby` / built-in DoT client pointing to `<DOT_HOST>:853`, ensuring ISP peer DNS is disabled (`peerdns = 0`).

### 7.2. Android Authorization Workflow in DoT Whitelist & Automation

The built-in **Private DNS** client in Android (9 and later) relies exclusively on **DNS-over-TLS (`853/TCP`)** and accepts only a hostname (`<DOT_HOST>`). Unlike DNS-over-HTTPS (`/resolve/<DOH_PATH>`), the DoT protocol and Android's system settings provide no mechanism to pass a 48-character secret URI path.

**Architectural Reasons Behind Out-of-Band Authorization:**
* **Protection against active scanning and DoT subdomain discovery:** During a TLS 1.2/1.3 handshake on port `853/TCP`, the **SNI** extension (`<DOT_HOST>`) is transmitted in plaintext, and subdomains can also be enumerated via Certificate Transparency logs.
* **Preventing unauthorized resolver abuse:** When `DOT_WHITELIST_ENABLED` is active, `iptables`/`ipset` drops all packets to `853/TCP` from unauthenticated IP addresses prior to the TLS handshake. Because Android's native DoT client cannot present a secret token in a URL path, client authentication is decoupled into the HTTPS channel (`443/TCP`) via the secret `/auth/<DOH_PATH>` endpoint.

**Manual Authorization (via browser bookmark):**
1. Bookmark your personal authorization URL (or pin it as a home-screen shortcut): `https://<ROOT_DOMAIN>/auth/<DOH_PATH>`.
2. When joining a new Wi-Fi network or after a cellular IP change, temporarily turn off *Private DNS*, open the bookmark (Nginx registers your current IPv4/IPv6 in `ipset` for **24 hours** / `86400s`), and re-enable *Private DNS* (`<DOT_HOST>`).

#### Complete Android Automation Guide (MacroDroid / Tasker without root)

When an Android smartphone changes its IP address (switching between Wi-Fi and cellular data, or handoffs between cell towers), a deadlock occurs: **if Private DNS is already enabled in Android settings while the new IP is not yet in `ipset` on the server, the firewall drops packets to `853/TCP`. Consequently, Android cannot resolve `<ROOT_DOMAIN>` to open the authorization link `/auth/<DOH_PATH>`.**

To bypass this deadlock, an automation routine on Android must temporarily switch Private DNS to `off` (or `opportunistic`), send a background HTTP GET request to the authorization URL via the carrier/router DNS, and then restore the `hostname` mode (`<DOT_HOST>`).

Below are two ready-to-use solutions using **MacroDroid** (recommended for rootless operation without complex scripting) and **Tasker** (for advanced users).

##### Preparation: Granting WRITE_SECURE_SETTINGS Permission (Once via PC)

Changing the *Private DNS* mode without root requires the `android.permission.WRITE_SECURE_SETTINGS` system permission, granted once from a PC over **ADB**:

1. Enable **USB Debugging** inside *Developer options* on your phone and connect it to your PC.
2. Run the corresponding command in your terminal:
   * **For MacroDroid:**
     ```bash
     adb shell pm grant com.arlosoft.macrodroid android.permission.WRITE_SECURE_SETTINGS
     ```
   * **For Tasker:**
     ```bash
     adb shell pm grant net.dinglisch.android.taskerm android.permission.WRITE_SECURE_SETTINGS
     ```

##### Option 1. MacroDroid Implementation (Recommended)

Create a new macro (e.g., **`SmartDNS Auto-Auth`**) with the following structure:

**1. Triggers**
Add three triggers (the macro will fire when any of them occurs):
* **Wi-Fi Connected** (*Connectivity → Wi-Fi State → Connected to network → Any Network*).
* **Data Connectivity Available / Mobile Network Changed** (*Connectivity → Data Connectivity Change → Data Available*).
* **Regular Interval Timer** — every **12 hours** (since the `ipset` TTL is 24 hours, refreshing every 12 hours guarantees uninterrupted connectivity on static/long-lived IPs).

**2. Actions (Step-by-Step)**
1. **Wait before next action:** `3 seconds` — allows the Android network stack to obtain an IP address and gateway after an interface transition.
2. **System Setting:**
   * Table: `Global`
   * Key: `private_dns_mode`
   * Value: `off` *(temporarily disables Private DNS so `<ROOT_DOMAIN>` resolves via local network DNS)*.
3. **Wait:** `1 second`.
4. **HTTP Request:**
   * Method: `GET`
   * URL: `https://<ROOT_DOMAIN>/auth/<DOH_PATH>`
   * Timeout: `10 seconds`
   * Enable *Block next actions until complete*.
5. **System Setting:**
   * Table: `Global`
   * Key: `private_dns_specifier`
   * Value: `<DOT_HOST>`
6. **System Setting:**
   * Table: `Global`
   * Key: `private_dns_mode`
   * Value: `hostname` *(restores strict DoT Private DNS mode)*.

**3. Constraints**
To prevent infinite loops during brief signal drops:
* **Macro not invoked recently:** `at most once every 2 minutes`.
* **Connectivity Check:** Wi-Fi or cellular data is connected.

##### Option 2. Tasker Implementation (Network State Profile)

If you use **Tasker**, create a profile with the **State → Net → Network Type** context (select `WiFi`, `Mobile`, or both so the task triggers on any connection state change) and link the following `Task`:

1. **Task → Wait:** `3 Seconds`
2. **Settings → Custom Setting:**
   * Type: `Global`
   * Name: `private_dns_mode`
   * Value: `off`
3. **Net → HTTP Request:**
   * Method: `GET`
   * URL: `https://<ROOT_DOMAIN>/auth/<DOH_PATH>`
   * Timeout (Seconds): `10`
   * Enable **Continue Task After Error** (ensures Step 4 always restores Private DNS even if the request fails inside an elevator or subway).
4. **Settings → Custom Setting:**
   * Type: `Global`
   * Name: `private_dns_mode`
   * Value: `hostname`

> [!NOTE]
> Always enable continuing the task on HTTP request error (Step 3 in Tasker; enabled by default in MacroDroid). This ensures that if the phone enters an area with no internet coverage, Private DNS is never left in the disabled (`off`) state and always reverts to `hostname`.

---

## 8. Security, Backups, and Diagnostics

* **State and Configuration Files:**
  * `/var/lib/oxidns-installer/settings` — non-sensitive installation parameters (`DNS_ENGINE`, `ROOT_DOMAIN`, `DOT_HOST`, filter flags).
  * `/var/lib/oxidns-installer/secrets.env` — secret `DOH_PATH`, Cloudflare API token, and AdGuardHome credentials (`chmod 0600`).
  * `/var/lib/oxidns-installer/backups/` — transactional snapshots of configurations, TLS certificates, and `iptables`/`ipset` rules.
  * `/var/log/oxidns-installer/` — detailed logs for installation, updates, IP synchronization, and self-tests.
* **Accessing the AdGuardHome Web Dashboard (when using `adguardhome`):**
  The web UI binds exclusively to `127.0.0.1:8053` and is blocked from external access. Connect via a local SSH tunnel:
  ```bash
  ssh -L 8053:127.0.0.1:8053 omega@<SERVER_IP>
  ```
  Once connected, open `http://127.0.0.1:8053` in your browser (credentials are stored in `/var/lib/oxidns-installer/secrets.env`).
* **Non-Interactive Automation:**
  When invoking commands from `cron` or `systemd`, pass `SCRIPT_LANG` to skip the interactive language prompt:
  ```bash
  sudo SCRIPT_LANG=en /<user_home_folder>/smartdns-installer.sh --update </dev/null
  ```

---

## 9. Troubleshooting

If DNS queries from a client device in Russia fail or target services remain unreachable after a successful installation and passing `--test` on the server, perform the following step-by-step diagnostics from the client machine.

### 9.1. Checking Server IP Blocking on TSPU (DPI)

In certain foreign hosting provider subnets, traffic may be filtered by IP address or TLS handshake signatures by TSPU (especially when using IP ranges previously utilized by mass VPN services, or when connecting with ECH enabled). Verify direct reachability of the Cover Site on port `443/TCP` from a machine in Russia bypassing system DNS:

```bash
curl -vk --max-time 6 \
  --resolve "example.com:443:<server_ip>" \
  "https://example.com/"
```
*(Replace `example.com` with your `ROOT_DOMAIN` and `<server_ip>` with your server's public IPv4 address.)*

* **Expected result:** Successful TLS handshake (`SSL connection using TLSv1.3`), valid Let's Encrypt certificate for your domain, and an `HTTP/2 200` response serving the Cover Site.
* **Sign of TSPU filtering:** Connection timeout (`Operation timed out after 6000 milliseconds`) at the `ClientHello` stage while the site opens normally from the server itself or outside Russia. In this case, change the server's IPv4 address (or switch hosting providers) and run `sudo ./smartdns-installer.sh --sync-ip`.

### 9.2. Verifying the Secret DoH Endpoint (RFC 8484)

Confirm that requests to your secret `/resolve/<DOH_PATH>` route reach the DNS engine and return a valid binary DNS response (`application/dns-message`) rather than `HTTP 404`:

```bash
curl -sS -o /dev/null -w "HTTP Status: %{http_code}\n" \
  -H "Accept: application/dns-message" \
  "https://<ROOT_DOMAIN>/resolve/<DOH_PATH>?dns=AAABAAABAAAAAAAAA3d3dwdleGFtcGxlA2NvbQAAAQAB"
```

* **Expected result:** `HTTP Status: 200` (which also automatically registers your external IPv4/IPv6 in `ipset`).
* **If `404` is returned:** Verify that the 48-character `DOH_PATH` matches `/var/lib/oxidns-installer/secrets.env` and ensure Cloudflare proxying is disabled (**DNS Only / grey cloud**) for the `@` record.

### 9.3. Checking DoT (`853/TCP`) Reachability and `ipset` Authorization

1. **Test the TLS handshake with the DoT server from the client PC:**
   ```bash
   openssl s_client -connect <server_ip>:853 -servername <DOT_HOST> -brief </dev/null
   ```
   * **Expected result:** Established TLS session presenting the `*.<ROOT_DOMAIN>` certificate. If the connection drops immediately after `ClientHello`, open the authorization link `https://<ROOT_DOMAIN>/auth/<DOH_PATH>` in your browser (when `DOT_WHITELIST_ENABLED=true`) or verify that your ISP does not block outbound `853/TCP`.

2. **Verify your client IP registration in the server whitelist:**
   ```bash
   sudo ./smartdns-installer.sh --whitelist-status
   ```
   Confirm that your current external IP address is listed with an active non-zero `timeout` (if you are behind ISP CG-NAT, ensure your browser and OS DNS client share the same outbound route without a third-party VPN active).

### 9.4. Diagnosing IPv6 and Client DNS Cache Leaks

* **A-record rewrite and IPv6 (`AAAA`) suppression:** Query a proxied domain directly against your DoH/DoT endpoint (for example, using `kdig` or `doggo`):
  ```bash
  doggo chatgpt.com A chatgpt.com AAAA "@tls://<server_ip>:853" --tls-hostname="<DOT_HOST>"
  ```
  * **Expected result:** The `ANSWER` section returns `<server_ip>` for `A` and an empty `NOERROR` response for `AAAA`. If the client receives a real IPv6 address, browsers will bypass your proxy over IPv6—disable IPv6 on the client network adapter or ensure no secondary ISP DNS server is configured on the device.

---

## Support the Project

If you find this installer useful, you can support its ongoing development:

* **SBP (Fast Payment System) & Bank Cards:** [Donate via CloudTips / SBP](https://pay.cloudtips.ru/p/9785e813)

[![Donate — CloudTips / SBP](https://img.shields.io/badge/Donate-CloudTips_%2F_SBP-0066FF?style=for-the-badge)](https://pay.cloudtips.ru/p/9785e813)
