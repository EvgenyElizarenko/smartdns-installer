# Provider Hostname Profile (Without Cloudflare) / Профиль имени хоста провайдера (без Cloudflare)

**Language / Язык:** [English](#english) | [Русский](#русский)

---

<a id="english"></a>
## English

The **Provider Hostname Profile** in `smartdns-installer.sh` deploys the full SmartDNS + Transparent SNI Proxy stack using a provider-managed hostname and an **existing single-host Certbot certificate** (HTTP-01 challenge), without a Cloudflare account or DNS API token.

> **Important — Preservation of Cloudflare Certificate Renewal (`v3.0`):**
> Automatic TLS certificate renewal for the Cloudflare profile (`acme.sh` + DNS-01 + `smartdns-cert-renew.timer` + `/usr/local/bin/smartdns-cert-deploy.sh`) was fixed in **`v3.0-stealth`** and remains completely unchanged in `v4.0.1-stealth`. The Provider Hostname Profile uses a separate, isolated mechanism (`certbot.timer` + lineage-specific deploy hook). The two mechanisms do not replace each other and never interfere. In `v4.0.1-stealth`, this profile is supported both on dedicated servers (`--profile hostname --install`) and inside the dual-IP `systemd-nspawn` container (`--profile hostname --install-on-second-IP`).

### 1. Cloudflare Profile vs. Provider Hostname Profile

| Aspect | Cloudflare Profile (`--profile cloudflare`, default) | Provider Hostname Profile (`--profile hostname`) |
| :--- | :--- | :--- |
| DNS management | Cloudflare API (`Zone:DNS:Edit`) | External DNS / VPS provider (read-only `dig` verification) |
| TLS certificate | Wildcard (`ROOT_DOMAIN` + `*.ROOT_DOMAIN`) via `acme.sh` DNS-01 | Existing single-host Certbot certificate (`PROVIDER_HOSTNAME`) |
| Challenge type | DNS-01 (`dns_cf`) | HTTP-01 (`/.well-known/acme-challenge/` in Nginx port 80) |
| Auto-renewal | `smartdns-cert-renew.timer` + `smartdns-cert-deploy.sh` (`v3.0`, untouched) | Existing `certbot.timer` + `/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh` |
| DoH & DoT hostnames | `ROOT_DOMAIN` (DoH/Site) + subdomain `DOT_HOST` (DoT) | Single hostname `PROVIDER_HOSTNAME` for Cover Site, DoH, and DoT |
| DoT IP authorization | Optional (wizard choice) | **Enabled by default (`shared`)** because the DoT SNI is public |
| Domain change (`--change-domain`) | Supported | Blocked (requires a separate migration) |

### 2. Input Parameters

No VPS-specific hostname or IP defaults are hardcoded. Examples below use RFC documentation values (`dns.example.net`, `192.0.2.25`, `2001:db8::25`).

| Variable | Required | Default / Purpose |
| :--- | :--- | :--- |
| `PROVIDER_HOSTNAME` | Yes | Provider-assigned FQDN used for `ROOT_DOMAIN`, `DOH_HOST`, and `DOT_HOST` |
| `PUBLIC_IPV4` | Yes | Public static IPv4 address of the VPS |
| `PUBLIC_IPV6` | No | Optional public IPv6 address (empty requires no AAAA record) |
| `HOSTNAME_CERT_LINEAGE` | No | `/etc/letsencrypt/live/$PROVIDER_HOSTNAME` |
| `HOSTNAME_ACME_WEBROOT` | No | `/var/www/$PROVIDER_HOSTNAME` |
| `HOSTNAME_RENEWAL_CONF` | No | `/etc/letsencrypt/renewal/<lineage-name>.conf` |
| `SCRIPT_LANG` | No | `ru` (default) or `en` |

All inputs are validated against invalid hostnames, invalid IPv4/IPv6 addresses, shell/command injection, relative paths, and path traversal (`..`).

### 3. Read-Only Pre-Check (`--hostname-check`)

Performs read-only diagnostics without installing packages, modifying configs/firewall, stopping services, or issuing/renewing certificates:

```bash
sudo env PROVIDER_HOSTNAME='dns.example.net' PUBLIC_IPV4='192.0.2.25' \
  SCRIPT_LANG=en ./smartdns-installer.sh --hostname-check
```

With IPv6 and custom Certbot paths:

```bash
sudo env PROVIDER_HOSTNAME='dns.example.net' PUBLIC_IPV4='192.0.2.25' \
  PUBLIC_IPV6='2001:db8::25' \
  HOSTNAME_CERT_LINEAGE='/etc/letsencrypt/live/dns.example.net' \
  HOSTNAME_ACME_WEBROOT='/var/www/dns.example.net' \
  HOSTNAME_RENEWAL_CONF='/etc/letsencrypt/renewal/dns.example.net.conf' \
  SCRIPT_LANG=en ./smartdns-installer.sh --hostname-check
```

The report classifies `[ CRIT ]` and `[ WARN ]` findings across public DNS `A`/`AAAA` (`1.1.1.1`, `8.8.8.8`), certificate files and permissions, expiry (`< 24h` critical, `< 14d` warning), public/private key match, CA trust chain, `webroot` / `renewal/*.conf`, required ports (`80, 443, 853, 5353, 8053, 8443, 8444, 8853, 9443, 9444`), and conflicting services. Full installation is blocked on any `[ CRIT ]` finding.

### 4. Existing Certbot Certificate & Installation

This profile uses an **already issued** Certbot webroot certificate and never silently performs initial certificate issuance.

Interactive installation:

```bash
sudo ./smartdns-installer.sh --profile hostname --install
```

Non-interactive installation (fails cleanly without hanging if required inputs are missing):

```bash
sudo env PROVIDER_HOSTNAME='dns.example.net' PUBLIC_IPV4='192.0.2.25' \
  SCRIPT_LANG=en ./smartdns-installer.sh --profile hostname --install </dev/null
```

Validated inputs are saved in `/var/lib/oxidns-installer/settings` (`0600`, backed up to `settings.bak` before updates) with `INSTALL_PROFILE="hostname"`, `DNS_PROVIDER="external"`, and `TLS_MODE="existing-certbot"`.

### 5. HTTP-01 Challenge & Safe Certificate Renewal

- **HTTP-01 route:** Nginx port `80` serves `location ^~ /.well-known/acme-challenge/` from `HOSTNAME_ACME_WEBROOT` (`default_type "text/plain"; autoindex off; try_files $uri =404;`) without disturbing TLS or the Cover Site.
- **Lineage-specific deploy hook:** Installation creates `/usr/local/bin/smartdns-hostname-cert-deploy.sh` (`0750`) and installs `/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh` without modifying existing Certbot hooks.
- **Validation & rollback:** The hook exits cleanly (`exit 0`) if `TLS_MODE != "existing-certbot"` or `RENEWED_LINEAGE != HOSTNAME_CERT_LINEAGE`, verifies the new cert/key/chain via `/usr/local/bin/verify-hostname-tls-keys.sh`, saves `.previous` backups, runs `nginx -t` + `systemctl reload nginx`, and automatically restores `.previous` + re-validates Nginx on failure.

### 6. Maintenance, Limitations & Troubleshooting

- Supported commands: `--status`, `--test`, `--update`, `--sync-ip`, `--switch-engine`, `--domain-groups`, `--regenerate-cover`, `--whitelist-*`, `--backup`, `--rollback`, `--uninstall`.
- Client endpoints: `https://<PROVIDER_HOSTNAME>/resolve/<DOH_PATH>`, `https://<PROVIDER_HOSTNAME>/auth/<DOH_PATH>`, DoT `<PROVIDER_HOSTNAME>:853`. Authorize client IP via DoH or `/auth/<DOH_PATH>` before using DoT.
- Changing `PROVIDER_HOSTNAME` (`--change-domain` or re-running with a different hostname) is blocked and requires a separate migration.
- Fresh installation stops if required ports or services (`nginx`, `apache2`, `caddy`, `xray`, `oxidns`, `adguardhome`, `sing-box`, `caddy-naive`) are already active.
- `--uninstall` removes only SmartDNS hooks and copies in `/etc/ssl/smartdns/`, preserving original Certbot lineages and `certbot.timer`.

---

<a id="русский"></a>
## Русский

**Профиль имени хоста провайдера (Provider Hostname Profile)** в `smartdns-installer.sh` позволяет развернуть стек SmartDNS + Transparent SNI Proxy с именем хоста внешнего DNS/VPS-провайдера и **существующим сертификатом Certbot для одного хоста** (HTTP-01), без аккаунта Cloudflare и токена DNS API.

> **Важно — сохранение исправленного автопродления Cloudflare (`v3.0`):**
> Автоматическое продление сертификатов Cloudflare (`acme.sh` + DNS-01 + `smartdns-cert-renew.timer` + `/usr/local/bin/smartdns-cert-deploy.sh`) было исправлено в **`v3.0-stealth`** и осталось полностью без изменений в `v4.0.1-stealth`. Provider Hostname Profile использует отдельный изолированный механизм (`certbot.timer` + deploy-хук для конкретного lineage). Эти механизмы не взаимозаменяются и не влияют друг на друга. В `v4.0.1-stealth` профиль поддерживается как на выделенном сервере (`--profile hostname --install`), так и в изолированном контейнере `systemd-nspawn` на 2-м IP (`--profile hostname --install-on-second-IP`).

### 1. Отличия Cloudflare Profile и Provider Hostname Profile

| Параметр | Cloudflare Profile (`--profile cloudflare`, по умолчанию) | Provider Hostname Profile (`--profile hostname`) |
| :--- | :--- | :--- |
| Управление DNS | Автоматически через Cloudflare API (`Zone:DNS:Edit`) | Внешний DNS / VPS-провайдер (только проверка `dig`) |
| TLS-сертификат | Wildcard (`ROOT_DOMAIN` + `*.ROOT_DOMAIN`) через `acme.sh` DNS-01 | Существующий сертификат Certbot для одного хоста (`PROVIDER_HOSTNAME`) |
| Проверка владения | DNS-01 (`dns_cf`) | HTTP-01 (`/.well-known/acme-challenge/` на порту 80 Nginx) |
| Автопродление TLS | `smartdns-cert-renew.timer` + `smartdns-cert-deploy.sh` (`v3.0`, без изменений) | Существующий `certbot.timer` + `/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh` |
| Имена хостов DoH / DoT | `ROOT_DOMAIN` (сайт + DoH) и поддомен `DOT_HOST` (DoT) | Единый `PROVIDER_HOSTNAME` для Cover Site, DoH и DoT |
| Авторизация IP для DoT | Опционально (выбирается в мастере) | **Включена по умолчанию (`shared`)**, так как SNI DoT публичен |
| Смена домена (`--change-domain`) | Поддерживается | Заблокирована (требуется отдельная миграция) |

### 2. Входные параметры

В коде нет жёстко заданных хостов или IP. В примерах используются тестовые значения RFC (`dns.example.net`, `192.0.2.25`, `2001:db8::25`).

| Переменная | Обязательна | Значение по умолчанию / назначение |
| :--- | :--- | :--- |
| `PROVIDER_HOSTNAME` | Да | FQDN от провайдера (назначается для `ROOT_DOMAIN`, `DOH_HOST`, `DOT_HOST`) |
| `PUBLIC_IPV4` | Да | Публичный статический IPv4-адрес VPS |
| `PUBLIC_IPV6` | Нет | Публичный IPv6-адрес VPS (если пусто — AAAA должна отсутствовать) |
| `HOSTNAME_CERT_LINEAGE` | Нет | `/etc/letsencrypt/live/$PROVIDER_HOSTNAME` |
| `HOSTNAME_ACME_WEBROOT` | Нет | `/var/www/$PROVIDER_HOSTNAME` |
| `HOSTNAME_RENEWAL_CONF` | Нет | `/etc/letsencrypt/renewal/<имя-lineage>.conf` |
| `SCRIPT_LANG` | Нет | `ru` (по умолчанию) или `en` |

Все значения проверяются на корректность, защиту от shell/command injection, относительных путей и path traversal (`..`).

### 3. Проверка без изменений (`--hostname-check`)

Режим только чтения не устанавливает пакеты, не меняет конфиги/firewall, не останавливает службы и не выпускает/не продлевает сертификаты:

```bash
sudo env PROVIDER_HOSTNAME='dns.example.net' PUBLIC_IPV4='192.0.2.25' \
  SCRIPT_LANG=ru ./smartdns-installer.sh --hostname-check
```

Отчёт разделяет критические проблемы (`[ CRIT ]`) и предупреждения (`[ WARN ]`): записи `A`/`AAAA` (`1.1.1.1`, `8.8.8.8`), файлы и права сертификата, срок действия (`< 24ч` критично, `< 14д` предупреждение), совпадение ключей, цепочка доверия, `webroot` и `renewal/*.conf`, занятость портов (`80, 443, 853, 5353, 8053, 8443, 8444, 8853, 9443, 9444`) и конфликтующие службы. При наличии `[ CRIT ]` полная установка блокируется.

### 4. Требования к сертификату Certbot и установка

Профиль использует **уже существующий** сертификат Certbot (webroot) и не выполняет скрытый первичный выпуск.

Интерактивная установка:

```bash
sudo ./smartdns-installer.sh --profile hostname --install
```

Неинтерактивная установка (не зависает без TTY; завершается ошибкой при отсутствии обязательных переменных):

```bash
sudo env PROVIDER_HOSTNAME='dns.example.net' PUBLIC_IPV4='192.0.2.25' \
  SCRIPT_LANG=ru ./smartdns-installer.sh --profile hostname --install </dev/null
```

Параметры сохраняются в `/var/lib/oxidns-installer/settings` (`0600`, бэкап `settings.bak`) с `INSTALL_PROFILE="hostname"`, `DNS_PROVIDER="external"`, `TLS_MODE="existing-certbot"`.

### 5. HTTP-01 challenge и безопасное продление сертификата

- В `nginx.conf` (порт `80`) для `hostname`-профиля добавляется `location ^~ /.well-known/acme-challenge/` из `HOSTNAME_ACME_WEBROOT` (`default_type "text/plain"; autoindex off; try_files $uri =404;`).
- Создаётся хук `/usr/local/bin/smartdns-hostname-cert-deploy.sh` (`0750`), устанавливаемый в `/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh` без изменения сторонних хуков Certbot.
- Хук завершается без действий (`exit 0`) при `TLS_MODE != "existing-certbot"` или чужом `RENEWED_LINEAGE`, проверяет новую пару ключей и цепочку через `/usr/local/bin/verify-hostname-tls-keys.sh`, сохраняет `.previous`, выполняет `nginx -t` + `systemctl reload nginx` и автоматически откатывается при ошибке.

### 6. Обслуживание, ограничения и устранение неполадок

- Команды обслуживания: `--status`, `--test`, `--update`, `--sync-ip`, `--switch-engine`, `--domain-groups`, `--regenerate-cover`, `--whitelist-*`, `--backup`, `--rollback`, `--uninstall`.
- Клиентские точки: `https://<PROVIDER_HOSTNAME>/resolve/<DOH_PATH>`, `https://<PROVIDER_HOSTNAME>/auth/<DOH_PATH>`, DoT `<PROVIDER_HOSTNAME>:853`. Перед использованием DoT авторизуйте IP через DoH или `/auth/<DOH_PATH>`.
- Смена `PROVIDER_HOSTNAME` (`--change-domain` или повторный запуск с другим хостом) заблокирована и требует отдельной миграции.
- Установка поверх занятых портов или активных служб (`nginx`, `apache2`, `caddy`, `xray`, `oxidns`, `adguardhome`, `sing-box`, `caddy-naive`) останавливается с подробным отчётом.
- При `--uninstall` удаляются только созданные установщиком хуки и копии в `/etc/ssl/smartdns/`, а исходные сертификаты Certbot и `certbot.timer` сохраняются.
