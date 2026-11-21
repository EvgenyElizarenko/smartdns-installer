# Changelog

Все значимые изменения проекта **Unified SmartDNS + Transparent SNI Proxy Installer** документируются в этом файле.
Формат основан на [Keep a Changelog](https://keepachangelog.com/ru/1.1.0/).

---

## [3.1.0-stealth] — 2026-11-21

### Added
- **Два режима установки в интерактивном меню (`[0–18]`):**
  - `[ 2]` **Установка SmartDNS + SNI Proxy на выделенный сервер (`--install`)** — штатный режим без `systemd-nspawn` с полным сохранением архитектуры `v3.0`/`v3.0.1`.
  - `[ 3]` **Установка SmartDNS + SNI Proxy на сервер с 2мя IP (`--install-on-second-IP`)** — полностью изолированное развёртывание в контейнер `systemd-nspawn` (`smartdns-v3.1.0`, rootfs `/var/lib/machines/smartdns-v3.1.0`) на второй публичный IPv4/IPv6 с автозапуском через `machines.target`.
- **Read-only предварительный аудит (`--preflight-second-IP`, пункт `[ 7]`):** проверка ОС/ядра/`cgroups`/namespaces, наличия `systemd-nspawn`/`debootstrap` (без автоустановки до подтверждения), глобальных IPv4/IPv6 (с исключением виртуальных интерфейсов `docker*`, `amn*`, `wg*`), портов `80`/`443`/`853` (включая wildcard `0.0.0.0` и `[::]`), активных служб хоста, firewall (`UFW`/`iptables`/`nftables`) и чужих контейнеров с итогом `INSTALLATION READY` / `INSTALLATION READY WITH WARNINGS` / `INSTALLATION BLOCKED`.
- **Изолированная сеть и неразрушающий firewall хоста (`/usr/local/bin/smartdns-nspawn-host-net.sh`):** выделенная `veth`-пара (`sdns-h0` <-> `host0`, транзит `10.203.110.0/30` + опц. `fd53:5300:310::/126`), автономный юнит `smartdns-container-net.service` на базе `iproute2` (совместимый с Debian 12/13 и Ubuntu 22.04/24.04 без `systemd-networkd`), точечный DNAT/SNAT `SMARTDNS_NSPAWN_*` строго для IP #2 (поддержка `iptables`/`UFW` и чистого `nftables` без сброса правил хоста) с сохранением исходного IP клиента для `ipset` и блокировкой доступа контейнера к IP #1 и хосту.
- **Разделённое обслуживание Host / Container (`--target [auto|host|container]`):** маршрутизация `--status`, `--test`, `--update`, `--domain-groups`, `--switch-engine`, `--whitelist-*`, `--sync-ip`, `--change-domain`, `--regenerate-cover`, `--backup`, `--rollback`, `--uninstall`, идемпотентный повторный запуск и точечное удаление только контейнера и правил `SMARTDNS_NSPAWN_*`.
- **Дизайн страницы быстрой веб-авторизации (`/auth/<DOH_PATH>`):** динамическая синхронизация с брендом, инициалами, городом и стилями процедурного Cover Site через `/etc/nginx/smartdns-web-auth.conf` (включая обновление при `--regenerate-cover` и миграцию при `--update`).
- **Автотесты:** добавлен набор `tests/test_nspawn_second_ip.py` (24 проверки меню `[0–18]`, CLI, матрицы конфликтов, сетевого скрипта, синхронизации `/auth/`, фильтра `amn*` и пустого `--second-ip`).

### Fixed
- Устранено сообщение `tr: write error: Broken pipe` при генерации `DOT_HOST` и `DOH_PATH` в окружении `systemd-run`.
- Исправлена загрузка `SECRETS_FILE` в `--regenerate-cover` и `configure_nginx()` при обновлении конфигурации Nginx.
- Скрыт хостовой блок `Initial Server Setup` / `Reboot lock` и скорректирована подпись firewall в итоговом отчёте при установке внутри контейнера (`CONTAINER_MODE=1`); убраны остаточные упоминания `Studio Nord` из шаблона `/auth/` и заголовка отчёта.
- Исключены виртуальные интерфейсы AmneziaVPN (`amn*`) из списка IP-кандидатов и добавлено отклонение пустого `--second-ip ""`.

### Preserved
- Режим выделенного сервера (`--install`), профиль `Provider Hostname` (`v3.0.1-stealth`) и исправленный в `v3.0-stealth` механизм автопродления Cloudflare (`acme.sh` + `smartdns-cert-renew.timer` + `smartdns-cert-deploy.sh`) сохранены полностью без изменений.

## [3.0.1-stealth] — 2026-11-21

### Added
- **Provider Hostname Profile (`--profile hostname`, без Cloudflare):** интегрирован альтернативный профиль установки по Pull Request #1 (`53631fb`, `ec1e4af`) для внешнего DNS-провайдера и существующего сертификата Certbot (HTTP-01) с поддержкой всех возможностей `v3.0` (`Initial Server Setup`, `SSH Hardening`, `Reboot Lock`, 10 групп доменов, `Initial Backup`, выборочный `--uninstall`).
- **Read-only проверка (`--hostname-check`):** 16-пунктовая проверка публичных DNS `A`/`AAAA` (`1.1.1.1`, `8.8.8.8`), существующего сертификата Certbot (срок, совпадение ключей, цепочка доверия, права), `webroot` и `renewal/*.conf`, занятых портов и конфликтующих служб без изменения системы.
- **Изолированный контур HTTP-01 и Certbot renewal:** маршрут `/.well-known/acme-challenge/` в Nginx (только для `hostname`-профиля), отдельный валидатор `/usr/local/bin/verify-hostname-tls-keys.sh` и lineage-специфичный deploy-хук `/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh` (`smartdns-hostname-cert-deploy.sh`) с проверкой `TLS_MODE`, `RENEWED_LINEAGE`, `nginx -t`, `systemctl reload nginx` и автооткатом при сбое.
- **Автотесты и документация:** адаптирован и расширен набор `tests/test_hostname_profile.py` (регрессия неизменности функций Cloudflare renewal и защита от path traversal `..`), добавлен [HOSTNAME_SETUP.md](HOSTNAME_SETUP.md), обновлены `README.md` и `README_EN.md`.

### Security & Compatibility
- Усилена валидация путей (`validate_safe_abs_path` — запрет `..`, системных корней и метасимволов) и добавлен строгий pure-Bash валидатор IPv6 (`validate_strict_ipv6`).
- Для `Provider Hostname Profile` по умолчанию включена авторизация IP для DoT (`DOT_WHITELIST_ENABLED="true"`, режим `shared`) и блокировка установки поверх занятых портов или активных служб.
- **Cloudflare Profile & Renewal (`v3.0-stealth`):** существующий профиль Cloudflare DNS-01 и исправленный в `v3.0-stealth` механизм автопродления (`acme.sh`, `smartdns-cert-renew.timer`, `smartdns-cert-deploy.sh`, `verify-tls-keys.sh`) сохранены полностью без изменений.

## [v2.10.0-stealth] — 2026-11-15

### Новые возможности (Added)
* **Двуязычный интерфейс командной строки (`RU / EN`):** добавлен интерактивный выбор языка при запуске (`1) Русский`, `2) English`) с централизованным словарём сообщений (`MSG_RU` / `MSG_EN`, 274 ключа) и поддержкой переменной окружения `SCRIPT_LANG` для неинтерактивного запуска (`cron` / `systemd` / `EOF`).
* **Горячее переключение DNS-движков (`--switch-engine`):** добавлена транзакционная смена активного DNS-движка между **OxiDNS** (Rust) и **AdGuardHome** (Go) на работающем сервере с сохранением TLS-сертификатов, секретного пути `DOH_PATH` и правил firewall.
* **Быстрая смена основного домена (`--change-domain`):** добавлен мастер замены `ROOT_DOMAIN` с автоматической синхронизацией A/AAAA-записей в Cloudflare, перевыпуском wildcard-сертификата Let's Encrypt и сохранением префикса `DOT_HOST` и пути `DOH_PATH`.
* **Автоматическая синхронизация IP сервера (`--sync-ip`):** добавлено определение нового публичного IPv4/IPv6 после миграции или смены IP на VPS с обновлением конфигов, цепочек `iptables`/`ip6tables` и DNS-записей Cloudflare.
* **Процедурный уникальный Cover Site (`--regenerate-cover`):** реализована генерация индивидуального статического сайта-заглушки (HTML5 + CSS3) без технических маркеров и утечек IP сервера.
* **Гибкое управление белым списком DoT (`--whitelist-*`):** добавлены команды `--whitelist-status`, `--whitelist-toggle`, `--whitelist-mode [shared|separate]`, `--whitelist-add`, `--whitelist-remove` и `--whitelist-flush` с TTL 24 часа (`86400s`).
* **Расширенный комплекс самодиагностики (`--test`):** добавлено 25 функциональных и негативных автотестов (проверка DoH RFC 8484, DoT SNI, `NODATA` для `AAAA` и `HTTPS/TYPE65`, блокировка невалидных JSON в Xray и защита внутренних портов).
* **Документация и инфраструктура репозитория:** добавлена полная английская документация (`README_EN.md`), раздел устранения неполадок (проверка ТСПУ/DPI, DoH/DoT и утечек IPv6), CI-проверка `ShellCheck`, шаблоны Issue/PR, `SECURITY.md`, `SUPPORT.md` и `CONTRIBUTING.md`.

### Исправления ошибок (Fixed)
* Устранено расхождение версии в заголовке скрипта (`# Version: 2.10.0-stealth` синхронизировано с `INSTALLER_VERSION="2.10.0-stealth"`).
* Исправлены предупреждения статического анализатора `ShellCheck` (`SC2155`) путём разделения объявления локальных переменных и присваивания результатов подстановки команд.
* Исправлена обработка закрытого потока ввода (`EOF` / `</dev/null`) при старте скрипта в режиме `set -e`, исключающая зависание при вызове из планировщиков задач.

### Изменения безопасности (Security)
* Все рабочие службы (`xray`, `oxidns`, `adguardhome`, `nginx`) переведены на запуск от выделенных непривилегированных системных учётных записей с минимальными правами (`NoNewPrivileges`, `ProtectSystem`).
* Добавлена обязательная проверка контрольных сумм `SHA-256` для загружаемых релизов `Xray-core`, `OxiDNS` и `AdGuardHome`.
* Закрыт внешний доступ ко всем внутренним портам (`5353`, `8053`, `8444`, `8853`, `9443`, `9444`); доступ к веб-панели AdGuardHome ограничен исключительно интерфейсом `127.0.0.1:8053` (через SSH-туннель).
* Запрещено добавление широких CIDR-подсетей через `--whitelist-add` (разрешены только одиночные IPv4/IPv6-адреса с автоматическим истечением TTL 86400 сек).

### Изменения совместимости и миграции (Compatibility & Upgrade Notes)
* **Для уже установленных серверов (v2.9.x -> v2.10.0-stealth):** обновление выполняется командой `sudo ./smartdns-installer-v2.10.0-stealth.sh --update`. Существующий `Cover Site`, `DOH_PATH`, `DOT_HOST` и выпущенные сертификаты Let's Encrypt сохраняются без изменений.
* **Для автоматизации (`cron` / `systemd`):** при обновлении скрипта на сервере добавьте переменную окружения `SCRIPT_LANG=ru` (или `SCRIPT_LANG=en`) и перенаправление `</dev/null` в существующие задачи.
* **Архитектуры CPU:** `OxiDNS` поддерживается только на `x86_64` (`amd64`); для серверов `aarch64` (`arm64`) используйте движок `AdGuardHome`.

### Известные ограничения (Known Limitations)
* Сервер должен иметь выделенный статический публичный IPv4-адрес; работа за NAT провайдера (CG-NAT) не поддерживается.
* В панели Cloudflare для всех DNS-записей домена (`@`, `*`, `DOT_HOST`) должен быть активен режим **DNS Only (серое облако)** — включение Cloudflare Proxy (оранжевое облако) нарушает работу SNI-прокси и DoT.
* На клиентских устройствах и роутерах необходимо отключать резервный DNS провайдера (`peerdns = 0`) и ECH/ESNI для целевых доменов, чтобы исключить утечку запросов мимо SmartDNS.
