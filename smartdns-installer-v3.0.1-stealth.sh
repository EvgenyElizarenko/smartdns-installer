#!/usr/bin/env bash
# ==============================================================================
# Unified SmartDNS + Transparent SNI Proxy Production Installer (Stealth Edition)
# File: smartdns-installer-v3.0.1-stealth.sh
# Version: 3.0.1-stealth
# Supported OS: Debian 12, Debian 13 (Trixie), Ubuntu 22.04 LTS, Ubuntu 24.04 LTS
# ==============================================================================

set -Eeuo pipefail
umask 027

# ------------------------------ Global Constants ------------------------------
readonly SCRIPT_NAME="smartdns-installer-v3.0.1-stealth.sh"
INSTALLER_VERSION="3.0.1-stealth"

# ------------------------------ Localization Engine (RU / EN) -----------------
SCRIPT_LANG="${SCRIPT_LANG:-ru}"
declare -A MSG_RU=()
declare -A MSG_EN=()

MSG_RU[M_0001]='Критическая ошибка выполнения на строке %s (код возврата: %s).'
MSG_EN[M_0001]='Critical execution error at line %s (exit code: %s).'
MSG_RU[M_0002]='Обнаружена незавершённая транзакция. Запуск автоматического аварийного отката...'
MSG_EN[M_0002]='Incomplete transaction detected. Starting automatic emergency rollback...'
MSG_RU[M_0003]='ОШИБКА: Другой экземпляр %s уже запущен (блокировка %s).\n'
MSG_EN[M_0003]='ERROR: Another instance of %s is already running (lock %s).\n'
MSG_RU[M_0004]='ОШИБКА: Скрипт должен запускаться с привилегиями root (sudo).\n'
MSG_EN[M_0004]='ERROR: This script must be run with root privileges (sudo).\n'
MSG_RU[M_0005]='Не найден /etc/os-release. Невозможно определить ОС.'
MSG_EN[M_0005]='/etc/os-release not found. Unable to determine OS.'
MSG_RU[M_0006]='Несовместимая ОС: %s. Поддерживаются только Debian 12/13 и Ubuntu 22.04/24.04 LTS.'
MSG_EN[M_0006]='Incompatible OS: %s. Only Debian 12/13 and Ubuntu 22.04/24.04 LTS are supported.'
MSG_RU[M_0007]='Недостаточно оперативной памяти: %s МБ (требуется минимум 512 МБ).'
MSG_EN[M_0007]='Insufficient RAM: %s MB (minimum 512 MB required).'
MSG_RU[M_0008]='Недостаточно свободного места на диске: %s МБ (требуется минимум 1500 МБ).'
MSG_EN[M_0008]='Insufficient free disk space: %s MB (minimum 1500 MB required).'
MSG_RU[M_0009]='Не обнаружен глобальный IPv4-адрес на основном интерфейсе %s.'
MSG_EN[M_0009]='Global IPv4 address not detected on primary interface %s.'
MSG_RU[M_0010]='               ОТЧЁТ PREFLIGHT (РЕЖИМ ТОЛЬКО ЧТЕНИЕ)                          \n'
MSG_EN[M_0010]='                PREFLIGHT REPORT (READ-ONLY MODE)                             \n'
MSG_RU[M_0011]='ОС и версия          : %s (%s / %s)\n'
MSG_EN[M_0011]='OS and version          : %s (%s / %s)\n'
MSG_RU[M_0012]='Ядро Linux           : %s\n'
MSG_EN[M_0012]='Linux kernel           : %s\n'
MSG_RU[M_0013]='Архитектура CPU      : %s (%s ядер)\n'
MSG_EN[M_0013]='CPU architecture      : %s (%s cores)\n'
MSG_RU[M_0014]='Оперативная память   : %s МБ\n'
MSG_EN[M_0014]='Memory (RAM)   : %s MB\n'
MSG_RU[M_0015]='Свободно на диске    : %s МБ\n'
MSG_EN[M_0015]='Free disk space    : %s MB\n'
MSG_RU[M_0016]='Основной интерфейс   : %s\n'
MSG_EN[M_0016]='Primary interface   : %s\n'
MSG_RU[M_0017]='Публичный IPv4       : %s\n'
MSG_EN[M_0017]='Public IPv4       : %s\n'
MSG_RU[M_0018]='Публичный IPv6       : %s (активен: %s)\n'
MSG_EN[M_0018]='Public IPv6       : %s (active: %s)\n'
MSG_RU[M_0019]='Все адреса хоста     : %s\n'
MSG_EN[M_0019]='All host addresses     : %s\n'
MSG_RU[M_0020]='Обнаружен (ВНИМАНИЕ: возможен конфликт NAT)'
MSG_EN[M_0020]='Detected (WARNING: potential NAT conflict)'
MSG_RU[M_0021]='Не обнаружен'
MSG_EN[M_0021]='Not detected'
MSG_RU[M_0022]='Наличие Docker       : %s\n'
MSG_EN[M_0022]='Docker status       : %s\n'
MSG_RU[M_0023]='Состояние существующих служб:\n'
MSG_EN[M_0023]='Existing services state:\n'
MSG_RU[M_0024]='  - %-15s : АКТИВНА\n'
MSG_EN[M_0024]='  - %-15s : ACTIVE\n'
MSG_RU[M_0025]='  - %-15s : не активна / не установлена\n'
MSG_EN[M_0025]='  - %-15s : inactive / not installed\n'
MSG_RU[M_0026]='Проверка совместимости с OxiDNS и AdGuardHome:\n'
MSG_EN[M_0026]='OxiDNS and AdGuardHome compatibility check:\n'
MSG_RU[M_0027]='  - OxiDNS      : СОВМЕСТИМ (x86_64)\n'
MSG_EN[M_0027]='  - OxiDNS      : COMPATIBLE (x86_64)\n'
MSG_RU[M_0028]='  - OxiDNS      : НЕ СОВМЕСТИМ (официальный бинарный релиз требует x86_64)\n'
MSG_EN[M_0028]='  - OxiDNS      : INCOMPATIBLE (official binary release requires x86_64)\n'
MSG_RU[M_0029]='  - AdGuardHome : СОВМЕСТИМ (%s)\n'
MSG_EN[M_0029]='  - AdGuardHome : COMPATIBLE (%s)\n'
MSG_RU[M_0030]='Занятые сокеты (TCP/UDP):\n'
MSG_EN[M_0030]='Listening sockets (TCP/UDP):\n'
MSG_RU[M_0031]='ИТОГ PREFLIGHT: Сервер соответствует требованиям для развёртывания.\n'
MSG_EN[M_0031]='PREFLIGHT SUMMARY: Server meets deployment requirements.\n'
MSG_RU[M_0032]='   МАСТЕР НАСТРОЙКИ UNIFIED SMARTDNS + TRANSPARENT SNI PROXY (STEALTH MODE)   \n'
MSG_EN[M_0032]='   UNIFIED SMARTDNS + TRANSPARENT SNI PROXY SETUP WIZARD (STEALTH MODE)       \n'
MSG_RU[M_0033]='Сравнение поддерживаемых DNS-движков:\n'
MSG_EN[M_0033]='Supported DNS engines comparison:\n'
MSG_RU[M_0034]='| Характеристика         | 1) OxiDNS (Rust)              | 2) AdGuardHome (Go)           |\n'
MSG_EN[M_0034]='| Feature               | 1) OxiDNS (Rust)              | 2) AdGuardHome (Go)           |\n'
MSG_RU[M_0035]='| Архитектура конвейера  | YAML sequence (hosts/nodata)  | DNS-правила ($dnsrewrite)     |\n'
MSG_EN[M_0035]='| Pipeline architecture | YAML sequence (hosts/nodata)  | DNS rules ($dnsrewrite)       |\n'
MSG_RU[M_0036]='| Блокировка рекламы     | Нативно через geosite.dat     | Списки фильтров AdGuard       |\n'
MSG_EN[M_0036]='| Ad blocking           | Native via geosite.dat        | AdGuard filter lists          |\n'
MSG_RU[M_0037]='| Поддержка NODATA       | Нативно через hosts/reject    | Правила $dnsrewrite=NOERROR   |\n'
MSG_EN[M_0037]='| NODATA support        | Native via hosts/reject       | $dnsrewrite=NOERROR rules     |\n'
MSG_RU[M_0038]='| Веб-панель управления  | Отсутствует (конфиг YAML)     | Есть (локально 127.0.0.1:8053)|\n'
MSG_EN[M_0038]='| Web management UI     | None (YAML config)            | Yes (local 127.0.0.1:8053)    |\n'
MSG_RU[M_0039]='| Поддержка архитектур   | Только x86_64                 | x86_64, aarch64, armv7        |\n'
MSG_EN[M_0039]='| CPU architectures     | x86_64 only                   | x86_64, aarch64, armv7        |\n'
MSG_RU[M_0040]='Выберите DNS-движок [1 - OxiDNS, 2 - AdGuardHome] (по умолчанию 1): '
MSG_EN[M_0040]='Select DNS engine [1 - OxiDNS, 2 - AdGuardHome] (default 1): '
MSG_RU[M_0041]='ОШИБКА: OxiDNS предоставляет официальную сборку только для x86_64. Ваша архитектура: %s.\n'
MSG_EN[M_0041]='ERROR: OxiDNS provides official builds for x86_64 only. Your architecture: %s.\n'
MSG_RU[M_0042]='Пожалуйста, введите 1 или 2.\n'
MSG_EN[M_0042]='Please enter 1 or 2.\n'
MSG_RU[M_0043]='Введите основной домен (ROOT_DOMAIN, например example.com): '
MSG_EN[M_0043]='Enter primary domain (ROOT_DOMAIN, e.g. example.com): '
MSG_RU[M_0044]='ОШИБКА: Некорректный синтаксис доменного имени.\n'
MSG_EN[M_0044]='ERROR: Invalid domain name syntax.\n'
MSG_RU[M_0045]='Режим маскировки DoH       : используется корневой домен https://%s/resolve/[SECRET]\n'
MSG_EN[M_0045]='DoH camouflage mode        : using root domain https://%s/resolve/[SECRET]\n'
MSG_RU[M_0046]='Введите поддомен для DoT (DOT_HOST, по умолчанию %s.%s): '
MSG_EN[M_0046]='Enter DoT subdomain (DOT_HOST, default %s.%s): '
MSG_RU[M_0047]='ОШИБКА: DOT_HOST должен быть валидным поддоменом *.%s.\n'
MSG_EN[M_0047]='ERROR: DOT_HOST must be a valid subdomain of *.%s.\n'
MSG_RU[M_0048]='\nНастройка секретного пути DoH и веб-авторизации (минимум 48 символов):\n'
MSG_EN[M_0048]='\nSecret DoH and Web-Auth path configuration (minimum 48 characters):\n'
MSG_RU[M_0049]='Сгенерировать криптографически случайный путь автоматически? [Y/n]: '
MSG_EN[M_0049]='Generate a cryptographically random path automatically? [Y/n]: '
MSG_RU[M_0050]='Введите собственный секретный путь DoH (не менее 48 букв/цифр): '
MSG_EN[M_0050]='Enter custom secret DoH path (at least 48 alphanumeric characters): '
MSG_RU[M_0051]='ОШИБКА: Путь должен содержать минимум 48 символов (только латинские буквы и цифры).\n'
MSG_EN[M_0051]='ERROR: Path must contain at least 48 characters (Latin letters and digits only).\n'
MSG_RU[M_0052]='\nНастройка IP-whitelist для DNS-over-TLS (DoT, TCP 853):\n'
MSG_EN[M_0052]='\nIP whitelist configuration for DNS-over-TLS (DoT, TCP 853):\n'
MSG_RU[M_0053]='Текущее сохранённое значение DOT_WHITELIST_ENABLED: %s (режим: %s)\n'
MSG_EN[M_0053]='Current saved DOT_WHITELIST_ENABLED value: %s (mode: %s)\n'
MSG_RU[M_0054]='Требуется ли включить предварительный whitelist IP-адресов для DoT (TCP 853)? [y/N]: '
MSG_EN[M_0054]='Enable preliminary IP whitelist for DoT (TCP 853)? [y/N]: '
MSG_RU[M_0055]='Оставить текущее значение (%s) без изменений? [Y/n]: '
MSG_EN[M_0055]='Keep current value (%s) unchanged? [Y/n]: '
MSG_RU[M_0056]='Выберите режим работы whitelist для DoT:\n'
MSG_EN[M_0056]='Select DoT whitelist operating mode:\n'
MSG_RU[M_0057]='  1 — общий whitelist smartdns_clients для DoH и DoT (по умолчанию)\n'
MSG_EN[M_0057]='  1 — shared smartdns_clients whitelist for DoH and DoT (default)\n'
MSG_RU[M_0058]='  2 — отдельный независимый whitelist dot_clients для DoT (с автодоступом к SNI-прокси)\n'
MSG_EN[M_0058]='  2 — dedicated dot_clients whitelist for DoT (with auto-access to SNI proxy)\n'
MSG_RU[M_0059]='Режим whitelist [1/2] (по умолчанию 1): '
MSG_EN[M_0059]='Whitelist mode [1/2] (default 1): '
MSG_RU[M_0060]='\nНастройка фильтра фоновых системных доменов Google/Android (EXCLUDE_GOOGLE_SYS):\n'
MSG_EN[M_0060]='\nGoogle/Android background system domains filter (EXCLUDE_GOOGLE_SYS):\n'
MSG_RU[M_0061]='  y — исключить фоновые домены (apis.google.com, *.clients.google.com и др.), сохранив generativelanguage.googleapis.com\n'
MSG_EN[M_0061]='  y — exclude background domains (apis.google.com, *.clients.google.com, etc.), keeping generativelanguage.googleapis.com\n'
MSG_RU[M_0062]='  N — оставить все домены Google в проксируемом списке (по умолчанию N)\n'
MSG_EN[M_0062]='  N — keep all Google domains in the proxied list (default N)\n'
MSG_RU[M_0063]='Исключить фоновые домены Google? [y/N]: '
MSG_EN[M_0063]='Exclude Google background domains? [y/N]: '
MSG_RU[M_0064]='\nНастройка дополнительных фильтров (INCLUDE_XBOX_IPIFY):\n'
MSG_EN[M_0064]='\nAdditional domain filters configuration (INCLUDE_XBOX_IPIFY):\n'
MSG_RU[M_0065]='  y — включить домены Xbox Live в проксируемый список\n'
MSG_EN[M_0065]='  y — include Xbox Live domains in the proxied list\n'
MSG_RU[M_0066]='  N — исключить их (по умолчанию N)\n'
MSG_EN[M_0066]='  N — exclude them (default N)\n'
MSG_RU[M_0067]='Включить домены Xbox Live? [y/N]: '
MSG_EN[M_0067]='Include Xbox Live domains? [y/N]: '
MSG_RU[M_0068]='Введите Cloudflare API Token (или нажмите Enter для использования сохранённого токена): '
MSG_EN[M_0068]='Enter Cloudflare API Token (or press Enter to use saved token): '
MSG_RU[M_0069]='ОШИБКА: API-токен Cloudflare необходим для автоматической привязки IP сервера к домену и выпуска сертификата.\n'
MSG_EN[M_0069]='ERROR: Cloudflare API token is required for automatic DNS binding and certificate issuance.\n'
MSG_RU[M_0070]='Введите контактный email для выпуска сертификатов Let'"'"'s Encrypt (по умолчанию admin@%s): '
MSG_EN[M_0070]='Enter contact email for Let'"'"'s Encrypt certificates (default admin@%s): '
MSG_RU[M_0071]='                    ПОДТВЕРЖДЕНИЕ ПАРАМЕТРОВ УСТАНОВКИ                        \n'
MSG_EN[M_0071]='                     INSTALLATION PARAMETERS CONFIRMATION                     \n'
MSG_RU[M_0072]='Выбранный DNS-движок       : %s (системный пользователь: %s)\n'
MSG_EN[M_0072]='Selected DNS engine        : %s (system user: %s)\n'
MSG_RU[M_0073]='Основной домен (Сайт + DoH): %s (единый TLS SNI профиль)\n'
MSG_EN[M_0073]='Primary domain (Site + DoH): %s (unified TLS SNI profile)\n'
MSG_RU[M_0074]='Домен DoT                  : %s\n'
MSG_EN[M_0074]='DoT domain                 : %s\n'
MSG_RU[M_0075]='Секретный путь DoH / Auth  : [СКРЫТО, длина %d симв.]\n'
MSG_EN[M_0075]='Secret DoH / Auth path     : [HIDDEN, length %d chars]\n'
MSG_RU[M_0076]='DoT IP-whitelist (TCP 853) : %s (режим: %s)\n'
MSG_EN[M_0076]='DoT IP whitelist (TCP 853) : %s (mode: %s)\n'
MSG_RU[M_0077]='Публичные порты            : 80/TCP, 443/TCP, 853/TCP\n'
MSG_EN[M_0077]='Public ports               : 80/TCP, 443/TCP, 853/TCP\n'
MSG_RU[M_0078]='Внутренние порты           : 8444/TCP (Xray), 9443/9444 (Nginx), 8853/TCP (DoT), 5353 (DNS), 8053 (DoH)\n'
MSG_EN[M_0078]='Internal ports             : 8444/TCP (Xray), 9443/9444 (Nginx), 8853/TCP (DoT), 5353 (DNS), 8053 (DoH)\n'
MSG_RU[M_0079]='План Firewall              : UFW + %s + ipset (smartdns_clients / dot_clients, TTL 86400s)\n'
MSG_EN[M_0079]='Firewall plan              : UFW + %s + ipset (smartdns_clients / dot_clients, TTL 86400s)\n'
MSG_RU[M_0080]='ПРЕДУПРЕЖДЕНИЕ             : Обнаружен Docker. Правила PREROUTING будут вставлены перед цепочками DOCKER.\n'
MSG_EN[M_0080]='WARNING                    : Docker detected. PREROUTING rules will be inserted before DOCKER chains.\n'
MSG_RU[M_0081]='Подтверждаете внесение изменений в конфигурацию сервера? [y/N]: '
MSG_EN[M_0081]='Confirm applying changes to server configuration? [y/N]: '
MSG_RU[M_0082]='Установка отменена пользователем.\n'
MSG_EN[M_0082]='Installation cancelled by user.\n'
MSG_RU[M_0083]='Создание полной резервной копии в %s...'
MSG_EN[M_0083]='Creating full system backup in %s...'
MSG_RU[M_0084]='Резервная копия успешно создана: %s'
MSG_EN[M_0084]='Backup created successfully: %s'
MSG_RU[M_0085]='Не найдена директория резервной копии для отката.'
MSG_EN[M_0085]='Backup directory for rollback not found.'
MSG_RU[M_0086]='Восстановление состояния системы из %s...'
MSG_EN[M_0086]='Restoring system state from %s...'
MSG_RU[M_0087]='Откат из резервной копии %s завершён (активный DNS backend: %s).'
MSG_EN[M_0087]='Rollback from backup %s completed (active DNS backend: %s).'
MSG_RU[M_0088]='Установка системных пакетов и официального репозитория Nginx...'
MSG_EN[M_0088]='Installing system packages and official Nginx repository...'
MSG_RU[M_0089]='Установлен стабильный Nginx версии: %s'
MSG_EN[M_0089]='Installed stable Nginx version: %s'
MSG_RU[M_0090]='Настройка непривилегированных пользователей, перекрёстных групп и прав доступа...'
MSG_EN[M_0090]='Configuring unprivileged users, cross-groups, and permissions...'
MSG_RU[M_0091]='Неподдерживаемая архитектура CPU для Xray: %s'
MSG_EN[M_0091]='Unsupported CPU architecture for Xray: %s'
MSG_RU[M_0092]='Проверка релизов Xray-core (базовый релиз: %s)...'
MSG_EN[M_0092]='Checking Xray-core releases (baseline release: %s)...'
MSG_RU[M_0093]='api.github.com недоступен, используется прямая ссылка: %s'
MSG_EN[M_0093]='api.github.com is unreachable, using direct fallback URL: %s'
MSG_RU[M_0094]='Загрузка Xray-core (%s) из %s...'
MSG_EN[M_0094]='Downloading Xray-core (%s) from %s...'
MSG_RU[M_0095]='Ошибка проверки SHA-256 архива Xray! Ожидался: %s, получен: %s'
MSG_EN[M_0095]='Xray archive SHA-256 verification failed! Expected: %s, got: %s'
MSG_RU[M_0096]='Установлен и проверен Xray-core: %s (%s)'
MSG_EN[M_0096]='Installed and verified Xray-core: %s (%s)'
MSG_RU[M_0097]='OxiDNS поддерживает только архитектуру x86_64. Текущая архитектура: %s.'
MSG_EN[M_0097]='OxiDNS supports x86_64 architecture only. Current architecture: %s.'
MSG_RU[M_0098]='Проверка релизов OxiDNS в официальном репозитории %s...'
MSG_EN[M_0098]='Checking OxiDNS releases in official repository %s...'
MSG_RU[M_0099]='Загрузка OxiDNS (%s) из %s...'
MSG_EN[M_0099]='Downloading OxiDNS (%s) from %s...'
MSG_RU[M_0100]='Загруженный архив OxiDNS повреждён.'
MSG_EN[M_0100]='Downloaded OxiDNS archive is corrupted.'
MSG_RU[M_0101]='В архиве OxiDNS не найден исполняемый файл oxidns.'
MSG_EN[M_0101]='Executable oxidns binary not found in OxiDNS archive.'
MSG_RU[M_0102]='OxiDNS успешно установлен в /usr/local/bin/oxidns: %s'
MSG_EN[M_0102]='OxiDNS installed successfully in /usr/local/bin/oxidns: %s'
MSG_RU[M_0103]='Получение информации о последнем стабильном релизе AdGuardHome...'
MSG_EN[M_0103]='Fetching latest stable AdGuardHome release metadata...'
MSG_RU[M_0104]='Не удалось получить стабильный релиз AdGuardHome.'
MSG_EN[M_0104]='Failed to fetch stable AdGuardHome release metadata.'
MSG_RU[M_0105]='Неподдерживаемая архитектура для AdGuardHome: %s'
MSG_EN[M_0105]='Unsupported architecture for AdGuardHome: %s'
MSG_RU[M_0106]='Не найден бинарный файл AdGuardHome после распаковки.'
MSG_EN[M_0106]='AdGuardHome binary not found after extraction.'
MSG_RU[M_0107]='AdGuardHome успешно установлен: %s'
MSG_EN[M_0107]='AdGuardHome installed successfully: %s'
MSG_RU[M_0108]='Некорректный Cloudflare API Token. Пропуск обновления DNS в Cloudflare.'
MSG_EN[M_0108]='Invalid Cloudflare API Token. Skipping Cloudflare DNS update.'
MSG_RU[M_0109]='CF_API_TOKEN не задан в %s. Пропуск обновления Cloudflare API.'
MSG_EN[M_0109]='CF_API_TOKEN is not set in %s. Skipping Cloudflare API update.'
MSG_RU[M_0110]='Получение Zone ID в Cloudflare для домена %s...'
MSG_EN[M_0110]='Fetching Cloudflare Zone ID for domain %s...'
MSG_RU[M_0111]='Не удалось получить Zone ID для %s через Cloudflare API. Проверьте права токена.'
MSG_EN[M_0111]='Failed to fetch Zone ID for %s via Cloudflare API. Check token permissions.'
MSG_RU[M_0112]='Cloudflare DNS: обновлена запись %s %s -> %s (DNS Only / proxied=false).'
MSG_EN[M_0112]='Cloudflare DNS: updated record %s %s -> %s (DNS Only / proxied=false).'
MSG_RU[M_0113]='Cloudflare DNS: ошибка обновления %s %s.'
MSG_EN[M_0113]='Cloudflare DNS: failed to update record %s %s.'
MSG_RU[M_0114]='Cloudflare DNS: создана запись %s %s -> %s (DNS Only / proxied=false).'
MSG_EN[M_0114]='Cloudflare DNS: created record %s %s -> %s (DNS Only / proxied=false).'
MSG_RU[M_0115]='Cloudflare DNS: ошибка создания %s %s.'
MSG_EN[M_0115]='Cloudflare DNS: failed to create record %s %s.'
MSG_RU[M_0116]='Cloudflare DNS: удалена неактуальная запись %s для %s (ID: %s).'
MSG_EN[M_0116]='Cloudflare DNS: removed stale %s record for %s (ID: %s).'
MSG_RU[M_0117]='Проверка наличия ранее выпущенного wildcard TLS-сертификата для %s...'
MSG_EN[M_0117]='Checking for previously issued wildcard TLS certificate for %s...'
MSG_RU[M_0118]='Найден действующий проверенный сертификат в %s. Повторный выпуск не требуется.'
MSG_EN[M_0118]='Valid verified certificate found in %s. Re-issuance is not required.'
MSG_RU[M_0119]='Восстановлен ранее выпущенный валидный сертификат из %s без обращения к Let'"'"'s Encrypt.'
MSG_EN[M_0119]='Restored previously issued valid certificate from %s without contacting Let'"'"'s Encrypt.'
MSG_RU[M_0120]='Действующий сертификат не найден. Подготовка выпуска через Cloudflare DNS-01...'
MSG_EN[M_0120]='No valid existing certificate found. Preparing issuance via Cloudflare DNS-01...'
MSG_RU[M_0121]='Запрос сертификата для SAN: %s и *.%s...'
MSG_EN[M_0121]='Requesting certificate for SAN: %s and *.%s...'
MSG_RU[M_0122]='Не удалось выпустить сертификат через Cloudflare DNS-01. Старые сертификаты сохранены.'
MSG_EN[M_0122]='Failed to issue certificate via Cloudflare DNS-01. Existing certificates preserved.'
MSG_RU[M_0123]='Проверка ключей нового сертификата не пройдена! Отмена установки сертификата.'
MSG_EN[M_0123]='New certificate key pair verification failed! Aborting certificate installation.'
MSG_RU[M_0124]='Сертификат для %s и *.%s успешно проверен и установлен.'
MSG_EN[M_0124]='Certificate for %s and *.%s verified and installed successfully.'
MSG_RU[M_0125]='Создание скриптов обновления geosite.dat и GeoHideDNS...'
MSG_EN[M_0125]='Creating geosite.dat and GeoHideDNS update scripts...'
MSG_RU[M_0126]='Формирование и проверка конфигурации OxiDNS (/etc/oxidns/config.yaml)...'
MSG_EN[M_0126]='Generating and validating OxiDNS configuration (/etc/oxidns/config.yaml)...'
MSG_RU[M_0127]='Формирование конфигурации AdGuardHome (/etc/adguardhome/AdGuardHome.yaml)...'
MSG_EN[M_0127]='Generating AdGuardHome configuration (/etc/adguardhome/AdGuardHome.yaml)...'
MSG_RU[M_0128]='Не найден модуль python3-bcrypt или утилита htpasswd для генерации хэша пароля AdGuardHome.'
MSG_EN[M_0128]='Neither python3-bcrypt nor htpasswd utility found to generate AdGuardHome password hash.'
MSG_RU[M_0129]='Формирование базовой конфигурации Xray (/etc/xray/conf.d/00-base.json) с поддержкой PROXY protocol...'
MSG_EN[M_0129]='Generating base Xray configuration (/etc/xray/conf.d/00-base.json) with PROXY protocol support...'
MSG_RU[M_0130]='Проверка Cover Site не пройдена: отсутствует или пуст %s.'
MSG_EN[M_0130]='Cover Site verification failed: missing or empty %s.'
MSG_RU[M_0131]='Проверка Cover Site не пройдена: отсутствует обязательный тег %s.'
MSG_EN[M_0131]='Cover Site verification failed: missing required tag %s.'
MSG_RU[M_0132]='Проверка Cover Site не пройдена: недостаточно секций (%s).'
MSG_EN[M_0132]='Cover Site verification failed: insufficient sections (%s).'
MSG_RU[M_0133]='Проверка безопасности Cover Site не пройдена: обнаружены технические ключевые слова.'
MSG_EN[M_0133]='Cover Site security check failed: technical keywords detected.'
MSG_RU[M_0134]='Проверка безопасности Cover Site не пройдена: обнаружен IPv4 сервера в HTML.'
MSG_EN[M_0134]='Cover Site security check failed: server IPv4 detected in HTML.'
MSG_RU[M_0135]='Сгенерированный index.html совпал по SHA-256 с предыдущим, требуется повторная генерация.'
MSG_EN[M_0135]='Generated index.html matched previous SHA-256, regenerating.'
MSG_RU[M_0136]='Существующий Cover Site обнаружен в %s; повторная генерация пропущена для сохранения текущей страницы.'
MSG_EN[M_0136]='Existing Cover Site detected in %s; regeneration skipped to preserve the current page.'
MSG_RU[M_0137]='Запуск процедурной генерации уникального Cover Site в %s...'
MSG_EN[M_0137]='Starting procedural generation of a unique Cover Site in %s...'
MSG_RU[M_0138]='Не удалось сгенерировать уникальный валидный Cover Site после 5 попыток.'
MSG_EN[M_0138]='Failed to generate a unique valid Cover Site after 5 attempts.'
MSG_RU[M_0139]='Уникальный Cover Site успешно сгенерирован и проверен (SHA-256 index.html: %s...).'
MSG_EN[M_0139]='Unique Cover Site generated and verified successfully (SHA-256 index.html: %s...).'
MSG_RU[M_0140]='Генерация конфигурации Nginx (9443 direct + 9444 PROXY protocol, DoH и /auth/ на ROOT_DOMAIN)...'
MSG_EN[M_0140]='Generating Nginx configuration (9443 direct + 9444 PROXY protocol, DoH and /auth/ on ROOT_DOMAIN)...'
MSG_RU[M_0141]='Создание служб динамической авторизации IP для DoH, Web-Auth и DoT...'
MSG_EN[M_0141]='Creating dynamic IP authorization services for DoH, Web-Auth, and DoT...'
MSG_RU[M_0142]='Настройка sysctl (TCP Keepalive + MTU Probing) и межсетевого экрана (UFW + iptables + ipset)...'
MSG_EN[M_0142]='Configuring sysctl (TCP Keepalive + MTU Probing) and firewall (UFW + iptables + ipset)...'
MSG_RU[M_0143]='Правила UFW, iptables (%s) и ipset успешно применены (DoT Whitelist: %s, режим: %s).'
MSG_EN[M_0143]='UFW, iptables (%s), and ipset rules applied successfully (DoT Whitelist: %s, mode: %s).'
MSG_RU[M_0144]='Автоматически добавлен IPv4 текущей SSH-сессии администратора (%s) в smartdns_clients и dot_clients (TTL 86400s).'
MSG_EN[M_0144]='Automatically added current admin SSH session IPv4 (%s) to smartdns_clients and dot_clients (TTL 86400s).'
MSG_RU[M_0145]='Автоматически добавлен IPv6 текущей SSH-сессии администратора (%s) в smartdns_clients6 и dot_clients6 (TTL 86400s).'
MSG_EN[M_0145]='Automatically added current admin SSH session IPv6 (%s) to smartdns_clients6 and dot_clients6 (TTL 86400s).'
MSG_RU[M_0146]='Создание изолированных systemd units с минимальными привилегиями...'
MSG_EN[M_0146]='Creating isolated systemd unit files with least privileges...'
MSG_RU[M_0147]='       ИЗОЛИРОВАННОЕ ТЕСТИРОВАНИЕ DNS BACKEND: %-20s          \n'
MSG_EN[M_0147]='        ISOLATED DNS BACKEND VERIFICATION: %-20s          \n'
MSG_RU[M_0148]='Служба %s не активна!'
MSG_EN[M_0148]='Service %s is not active!'
MSG_RU[M_0149]='Конфликт: альтернативный движок %s всё ещё активен!'
MSG_EN[M_0149]='Conflict: alternative engine %s is still active!'
MSG_RU[M_0150]='[ PASS ] Служба %s активна, конфликт с %s отсутствует\n'
MSG_EN[M_0150]='[ PASS ] Service %s is active, no conflict with %s\n'
MSG_RU[M_0151]='[ PASS ] Сокеты 127.0.0.1:5353 (UDP/TCP) и 127.0.0.1:8053 (TCP DoH) прослушиваются\n'
MSG_EN[M_0151]='[ PASS ] Sockets 127.0.0.1:5353 (UDP/TCP) and 127.0.0.1:8053 (TCP DoH) are listening\n'
MSG_RU[M_0152]='Не обнаружены ожидаемые сокеты 127.0.0.1:5353 / 127.0.0.1:8053 для %s.'
MSG_EN[M_0152]='Expected sockets 127.0.0.1:5353 / 127.0.0.1:8053 not detected for %s.'
MSG_RU[M_0153]='Ошибка разрешения обычного домена example.com через %s (получено: %s).'
MSG_EN[M_0153]='Failed to resolve regular domain example.com via %s (got: %s).'
MSG_RU[M_0154]='Ошибка повторного (кэшированного) запроса example.com.'
MSG_EN[M_0154]='Failed on repeated (cached) query for example.com.'
MSG_RU[M_0155]='[ PASS ] Upstream DNS и кэш работают (example.com -> %s)\n'
MSG_EN[M_0155]='[ PASS ] Upstream DNS and cache work properly (example.com -> %s)\n'
MSG_RU[M_0156]='Подмена A-записи не сработала в %s (ожидался %s, получено: %s).'
MSG_EN[M_0156]='A-record rewrite failed in %s (expected %s, got: %s).'
MSG_RU[M_0157]='[ PASS ] Правила SmartDNS подменяют проксируемый домен на %s\n'
MSG_EN[M_0157]='[ PASS ] SmartDNS rules rewrite proxied domain to %s\n'
MSG_RU[M_0158]='Некорректный ответ AAAA для проксируемого домена в %s.'
MSG_EN[M_0158]='Invalid AAAA response for proxied domain in %s.'
MSG_RU[M_0159]='Некорректный ответ HTTPS (TYPE65) для проксируемого домена в %s.'
MSG_EN[M_0159]='Invalid HTTPS (TYPE65) response for proxied domain in %s.'
MSG_RU[M_0160]='[ PASS ] Ответы AAAA (NOERROR/NODATA) и HTTPS TYPE65 (пустой ответ) валидны\n'
MSG_EN[M_0160]='[ PASS ] AAAA (NOERROR/NODATA) and HTTPS TYPE65 (empty answer) responses are valid\n'
MSG_RU[M_0161]='Фильтрация рекламы (doubleclick.net) не сработала в %s.'
MSG_EN[M_0161]='Ad blocking (doubleclick.net) failed in %s.'
MSG_RU[M_0162]='[ PASS ] Фильтрация рекламных доменов (doubleclick.net) активна\n'
MSG_EN[M_0162]='[ PASS ] Ad domain filtering (doubleclick.net) is active\n'
MSG_RU[M_0163]='Прямой DoH POST на http://127.0.0.1:8053/dns-query вернул %s.'
MSG_EN[M_0163]='Direct DoH POST to http://127.0.0.1:8053/dns-query returned %s.'
MSG_RU[M_0164]='[ PASS ] Прямой RFC 8484 HTTP DoH POST на 127.0.0.1:8053/dns-query работает (%s)\n'
MSG_EN[M_0164]='[ PASS ] Direct RFC 8484 HTTP DoH POST to 127.0.0.1:8053/dns-query works (%s)\n'
MSG_RU[M_0165]='ОШИБКА: Укажите целевой DNS backend: %s --switch-engine [oxidns|adguardhome]\n'
MSG_EN[M_0165]='ERROR: Specify target DNS backend: %s --switch-engine [oxidns|adguardhome]\n'
MSG_RU[M_0166]='ОШИБКА: Система не установлена (%s не найден).\n'
MSG_EN[M_0166]='ERROR: System is not installed (%s not found).\n'
MSG_RU[M_0167]='DNS backend %s уже активен. Запуск проверок...\n'
MSG_EN[M_0167]='DNS backend %s is already active. Running verification...\n'
MSG_RU[M_0168]='ОШИБКА: OxiDNS поддерживает только x86_64.\n'
MSG_EN[M_0168]='ERROR: OxiDNS supports x86_64 only.\n'
MSG_RU[M_0169]='Запуск транзакционного переключения DNS backend: %s -> %s...'
MSG_EN[M_0169]='Starting transactional DNS backend switch: %s -> %s...'
MSG_RU[M_0170]='Остановка %s.service (конфигурация сохраняется) и запуск %s.service...'
MSG_EN[M_0170]='Stopping %s.service (configuration preserved) and starting %s.service...'
MSG_RU[M_0171]='Служба %s не открыла порты 5353/8053 в отведённое время.'
MSG_EN[M_0171]='Service %s did not open ports 5353/8053 within the expected timeout.'
MSG_RU[M_0172]='Переключение DNS backend на %s успешно завершено и проверено.'
MSG_EN[M_0172]='DNS backend switch to %s completed and verified successfully.'
MSG_RU[M_0173]=' УСПЕШНОЕ ПЕРЕКЛЮЧЕНИЕ НА ADGUARDHOME (СЕРТИФИКАТЫ И СЕКРЕТЫ СОХРАНЕНЫ)\n'
MSG_EN[M_0173]='  SUCCESSFULLY SWITCHED TO ADGUARDHOME (CERTIFICATES AND SECRETS PRESERVED)\n'
MSG_RU[M_0174]='Активный DNS backend      : AdGuardHome (127.0.0.1:5353 / 127.0.0.1:8053)\n'
MSG_EN[M_0174]='Active DNS backend        : AdGuardHome (127.0.0.1:5353 / 127.0.0.1:8053)\n'
MSG_RU[M_0175]='Веб-интерфейс AdGuardHome : http://127.0.0.1:8053 (доступ только через SSH-туннель)\n'
MSG_EN[M_0175]='AdGuardHome web UI        : http://127.0.0.1:8053 (access via SSH tunnel only)\n'
MSG_RU[M_0176]='Логин администратора      : %s\n'
MSG_EN[M_0176]='Admin username            : %s\n'
MSG_RU[M_0177]='Пароль администратора     : [сохранён в %s]\n'
MSG_EN[M_0177]='Admin password            : [saved in %s]\n'
MSG_RU[M_0178]='Возврат к OxiDNS          : sudo %s --switch-engine oxidns\n'
MSG_EN[M_0178]='Switch back to OxiDNS     : sudo %s --switch-engine oxidns\n'
MSG_RU[M_0179]=' УСПЕШНЫЙ ВОЗВРАТ К OXIDNS (СЕРТИФИКАТЫ И СЕКРЕТЫ СОХРАНЕНЫ)\n'
MSG_EN[M_0179]='  SUCCESSFULLY SWITCHED BACK TO OXIDNS (CERTIFICATES AND SECRETS PRESERVED)\n'
MSG_RU[M_0180]='ОШИБКА: Файл настроек %s не найден. Сначала выполните --install.\n'
MSG_EN[M_0180]='ERROR: Settings file %s not found. Run --install first.\n'
MSG_RU[M_0181]='Режим whitelist       : %s (наборы DoT: %s / %s)\n'
MSG_EN[M_0181]='Whitelist mode       : %s (DoT sets: %s / %s)\n'
MSG_RU[M_0182]='TTL записей           : 86400 секунд\n'
MSG_EN[M_0182]='Entry TTL            : 86400 seconds\n'
MSG_RU[M_0183]='Файл сохранения       : %s\n'
MSG_EN[M_0183]='Persistence file       : %s\n'
MSG_RU[M_0184]='Разрешённые IPv4-адреса в %s (DoT 853/TCP) и оставшийся TTL:\n'
MSG_EN[M_0184]='Authorized IPv4 addresses in %s (DoT 853/TCP) and remaining TTL:\n'
MSG_RU[M_0185]='  (список пуст)\n'
MSG_EN[M_0185]='  (list is empty)\n'
MSG_RU[M_0186]='Разрешённые IPv4-адреса в smartdns_clients (DoH / SNI Proxy 443/TCP):\n'
MSG_EN[M_0186]='Authorized IPv4 addresses in smartdns_clients (DoH / SNI Proxy 443/TCP):\n'
MSG_RU[M_0187]='Разрешённые IPv6-адреса (%s) и оставшийся TTL:\n'
MSG_EN[M_0187]='Authorized IPv6 addresses (%s) and remaining TTL:\n'
MSG_RU[M_0188]='ОШИБКА: Укажите IPv4 или IPv6 адрес. Пример: %s --whitelist-add 203.0.113.10\n'
MSG_EN[M_0188]='ERROR: Specify an IPv4 or IPv6 address. Example: %s --whitelist-add 203.0.113.10\n'
MSG_RU[M_0189]='ОШИБКА: Добавление CIDR-диапазонов запрещено политикой безопасности. Укажите одиночный IP-адрес.\n'
MSG_EN[M_0189]='ERROR: Adding CIDR ranges is prohibited by security policy. Specify a single IP address.\n'
MSG_RU[M_0190]='Вручную добавлен IPv4 %s в %s и smartdns_clients (TTL 86400s).'
MSG_EN[M_0190]='Manually added IPv4 %s to %s and smartdns_clients (TTL 86400s).'
MSG_RU[M_0191]='УСПЕШНО: IPv4 %s добавлен в %s и smartdns_clients (TTL: 86400 сек).\n'
MSG_EN[M_0191]='SUCCESS: IPv4 %s added to %s and smartdns_clients (TTL: 86400 sec).\n'
MSG_RU[M_0192]='Вручную добавлен IPv6 %s в %s и smartdns_clients6 (TTL 86400s).'
MSG_EN[M_0192]='Manually added IPv6 %s to %s and smartdns_clients6 (TTL 86400s).'
MSG_RU[M_0193]='УСПЕШНО: IPv6 %s добавлен в %s и smartdns_clients6 (TTL: 86400 сек).\n'
MSG_EN[M_0193]='SUCCESS: IPv6 %s added to %s and smartdns_clients6 (TTL: 86400 sec).\n'
MSG_RU[M_0194]='ОШИБКА: Некорректный формат IPv4/IPv6 адреса: %s\n'
MSG_EN[M_0194]='ERROR: Invalid IPv4/IPv6 address format: %s\n'
MSG_RU[M_0195]='ОШИБКА: Укажите IPv4 или IPv6 адрес для удаления.\n'
MSG_EN[M_0195]='ERROR: Specify an IPv4 or IPv6 address to remove.\n'
MSG_RU[M_0196]='Удалён IPv4 %s из %s и smartdns_clients.'
MSG_EN[M_0196]='Removed IPv4 %s from %s and smartdns_clients.'
MSG_RU[M_0197]='УСПЕШНО: IPv4 %s удалён из %s и smartdns_clients.\n'
MSG_EN[M_0197]='SUCCESS: IPv4 %s removed from %s and smartdns_clients.\n'
MSG_RU[M_0198]='Удалён IPv6 %s из %s и smartdns_clients6.'
MSG_EN[M_0198]='Removed IPv6 %s from %s and smartdns_clients6.'
MSG_RU[M_0199]='УСПЕШНО: IPv6 %s удалён из %s и smartdns_clients6.\n'
MSG_EN[M_0199]='SUCCESS: IPv6 %s removed from %s and smartdns_clients6.\n'
MSG_RU[M_0200]='Очищены списки DoT whitelist (%s, %s).'
MSG_EN[M_0200]='Flushed DoT whitelist sets (%s, %s).'
MSG_RU[M_0201]='УСПЕШНО: Списки %s и %s полностью очищены.\n'
MSG_EN[M_0201]='SUCCESS: Sets %s and %s have been completely flushed.\n'
MSG_RU[M_0202]='ОШИБКА: Недопустимое значение "%s". Используйте: %s --whitelist-toggle [on|off]\n'
MSG_EN[M_0202]='ERROR: Invalid value "%s". Usage: %s --whitelist-toggle [on|off]\n'
MSG_RU[M_0203]='Режим DoT IP-whitelist (TCP 853) переключён: %s -> %s (режим наборов: %s).'
MSG_EN[M_0203]='DoT IP whitelist mode (TCP 853) switched: %s -> %s (set mode: %s).'
MSG_RU[M_0204]='УСПЕШНО: DoT IP-whitelist (TCP 853) переключён: %s -> %s.\n\n'
MSG_EN[M_0204]='SUCCESS: DoT IP whitelist (TCP 853) switched: %s -> %s.\n\n'
MSG_RU[M_0205]='ОШИБКА: Укажите режим whitelist: %s --whitelist-mode [shared|separate]\n'
MSG_EN[M_0205]='ERROR: Specify whitelist mode: %s --whitelist-mode [shared|separate]\n'
MSG_RU[M_0206]='Режим наборов DoT whitelist изменён: %s -> %s.'
MSG_EN[M_0206]='DoT whitelist set mode changed: %s -> %s.'
MSG_RU[M_0207]='УСПЕШНО: Режим наборов DoT whitelist изменён: %s -> %s.\n\n'
MSG_EN[M_0207]='SUCCESS: DoT whitelist set mode changed: %s -> %s.\n\n'
MSG_RU[M_0208]='Не удалось определить текущий глобальный IPv4-адрес сервера.'
MSG_EN[M_0208]='Failed to determine current global IPv4 address of the server.'
MSG_RU[M_0209]='Запуск синхронизации IP-адреса: старый IPv4=%s -> новый IPv4=%s (IPv6=%s)'
MSG_EN[M_0209]='Starting IP address synchronization: old IPv4=%s -> new IPv4=%s (IPv6=%s)'
MSG_RU[M_0210]='Предупреждение: не удалось автоматически обновить записи в Cloudflare API. Проверьте их вручную.'
MSG_EN[M_0210]='Warning: failed to automatically update records via Cloudflare API. Please check them manually.'
MSG_RU[M_0211]='Синхронизация нового IP (%s) успешно завершена.'
MSG_EN[M_0211]='Synchronization of new IP (%s) completed successfully.'
MSG_RU[M_0212]='ОШИБКА: Файлы настроек не найдены. Сначала выполните --install.\n'
MSG_EN[M_0212]='ERROR: Settings files not found. Run --install first.\n'
MSG_RU[M_0213]='     БЫСТРАЯ СМЕНА ДОМЕНА (С СОХРАНЕНИЕМ ПОДДОМЕНА DoT И СЕКРЕТНЫХ ПУТЕЙ)     \n'
MSG_EN[M_0213]='     QUICK DOMAIN CHANGE (PRESERVING DoT SUBDOMAIN AND SECRET PATHS)          \n'
MSG_RU[M_0214]='Текущий основной домен (ROOT_DOMAIN) : %s\n'
MSG_EN[M_0214]='Current primary domain (ROOT_DOMAIN) : %s\n'
MSG_RU[M_0215]='Текущий поддомен DoT (DOT_HOST)      : %s (префикс "%s" сохраняется)\n'
MSG_EN[M_0215]='Current DoT subdomain (DOT_HOST)     : %s (prefix "%s" preserved)\n'
MSG_RU[M_0216]='Секретный путь DoH (DOH_PATH)        : [СОХРАНЯЕТСЯ БЕЗ ИЗМЕНЕНИЙ, %d симв.]\n\n'
MSG_EN[M_0216]='Secret DoH path (DOH_PATH)           : [PRESERVED UNCHANGED, %d chars]\n\n'
MSG_RU[M_0217]='ОШИБКА: Некорректный синтаксис переданного домена: %s\n'
MSG_EN[M_0217]='ERROR: Invalid domain syntax provided: %s\n'
MSG_RU[M_0218]='Введите новый основной домен (ROOT_DOMAIN, например newdomain.com): '
MSG_EN[M_0218]='Enter new primary domain (ROOT_DOMAIN, e.g. newdomain.com): '
MSG_RU[M_0219]='ОШИБКА: Для выпуска сертификата на новый домен необходим действующий Cloudflare API Token.\n'
MSG_EN[M_0219]='ERROR: A valid Cloudflare API Token is required to issue a certificate for the new domain.\n'
MSG_RU[M_0220]='\nПлан смены домена:\n'
MSG_EN[M_0220]='\nDomain change plan:\n'
MSG_RU[M_0221]='  - Новый ROOT_DOMAIN (Сайт + DoH) : %s\n'
MSG_EN[M_0221]='  - New ROOT_DOMAIN (Site + DoH) : %s\n'
MSG_RU[M_0222]='  - Новый DOT_HOST (TCP 853)       : %s (префикс "%s" не изменён)\n'
MSG_EN[M_0222]='  - New DOT_HOST (TCP 853)       : %s (prefix "%s" unchanged)\n'
MSG_RU[M_0223]='  - Секретный путь DoH / Web-Auth  : сохраняется прежний\n'
MSG_EN[M_0223]='  - Secret DoH / Web-Auth path   : existing path preserved\n'
MSG_RU[M_0224]='Применить смену домена и выпустить новый сертификат? [y/N]: '
MSG_EN[M_0224]='Apply domain change and issue new certificate? [y/N]: '
MSG_RU[M_0225]='Операция отменена пользователем.\n'
MSG_EN[M_0225]='Operation cancelled by user.\n'
MSG_RU[M_0226]='Синхронизация A/AAAA записей для нового домена %s в Cloudflare...'
MSG_EN[M_0226]='Synchronizing A/AAAA records for new domain %s in Cloudflare...'
MSG_RU[M_0227]='Выпуск wildcard-сертификата для нового домена %s...'
MSG_EN[M_0227]='Issuing wildcard certificate for new domain %s...'
MSG_RU[M_0228]='Смена домена успешно завершена: %s -> %s (DoT: %s).'
MSG_EN[M_0228]='Domain change completed successfully: %s -> %s (DoT: %s).'
MSG_RU[M_0229]=' ДОМЕН УСПЕШНО ИЗМЕНЁН (ПОДДОМЕН DoT И СЕКРЕТНЫЙ ПУТЬ СОХРАНЕНЫ)\n'
MSG_EN[M_0229]='  DOMAIN CHANGED SUCCESSFULLY (DoT SUBDOMAIN AND SECRET PATH PRESERVED)\n'
MSG_RU[M_0230]='Новый DoH URL             : https://%s/resolve/%s\n'
MSG_EN[M_0230]='New DoH URL               : https://%s/resolve/%s\n'
MSG_RU[M_0231]='Новая ссылка авторизации  : https://%s/auth/%s\n'
MSG_EN[M_0231]='New authorization URL     : https://%s/auth/%s\n'
MSG_RU[M_0232]='Новый хост DoT (853/TCP)  : %s\n'
MSG_EN[M_0232]='New DoT host (853/TCP)    : %s\n'
MSG_RU[M_0233]='         КОМПЛЕКСНОЕ ТЕСТИРОВАНИЕ UNIFIED SMARTDNS + SNI PROXY                \n'
MSG_EN[M_0233]='          UNIFIED SMARTDNS + SNI PROXY COMPREHENSIVE TEST SUITE               \n'
MSG_RU[M_0234]='         Активный DNS backend: %-45s  \n'
MSG_EN[M_0234]='          Active DNS backend: %-45s  \n'
MSG_RU[M_0235]='Служба %s активна'
MSG_EN[M_0235]='Service %s is active'
MSG_RU[M_0236]='Процесс Xray работает без root (user=%s)'
MSG_EN[M_0236]='Xray process runs without root privileges (user=%s)'
MSG_RU[M_0237]='Сертификат SAN и SHA-256 ключей валидны'
MSG_EN[M_0237]='Certificate SAN and SHA-256 keys are valid'
MSG_RU[M_0238]='Обычный домен (example.com) разрешается в реальный IP (%s)'
MSG_EN[M_0238]='Regular domain (example.com) resolves to real IP (%s)'
MSG_RU[M_0239]='SmartDNS подменяет A-запись проксируемого домена на %s'
MSG_EN[M_0239]='SmartDNS rewrites A-record of proxied domain to %s'
MSG_RU[M_0240]='Обработка AAAA возвращает корректный NOERROR/NODATA'
MSG_EN[M_0240]='AAAA handling returns valid NOERROR/NODATA'
MSG_RU[M_0241]='Обработка HTTPS (qtype 65) возвращает пустой ответ (NOERROR/REFUSED)'
MSG_EN[M_0241]='HTTPS (qtype 65) handling returns empty answer (NOERROR/REFUSED)'
MSG_RU[M_0242]='Негативный тест: неверный путь DoH на %s маскируется под 404 (HTTP %s)'
MSG_EN[M_0242]='Negative test: invalid DoH path on %s is masked as 404 (HTTP %s)'
MSG_RU[M_0243]='Корректный DoH-запрос (A) на корневом домене %s работает'
MSG_EN[M_0243]='Valid DoH query (A) on root domain %s works'
MSG_RU[M_0244]='Секретная ссылка веб-авторизации /auth/ работает'
MSG_EN[M_0244]='Secret Web-Auth link /auth/ works'
MSG_RU[M_0245]='DoT Whitelist (ENABLED): запрещённый IPv4 блокируется firewall на 853/TCP'
MSG_EN[M_0245]='DoT Whitelist (ENABLED): blocked IPv4 is dropped by firewall on 853/TCP'
MSG_RU[M_0246]='DoT Whitelist (ENABLED): разрешённый IPv4 успешно подключается к 853/TCP'
MSG_EN[M_0246]='DoT Whitelist (ENABLED): allowed IPv4 connects to 853/TCP successfully'
MSG_RU[M_0247]='DoT Whitelist (ENABLED): неверный SNI с разрешённого IPv4 не получает сертификат'
MSG_EN[M_0247]='DoT Whitelist (ENABLED): invalid SNI from allowed IPv4 does not receive a certificate'
MSG_RU[M_0248]='DoT Whitelist (ENABLED): запрещённый IPv6 блокируется firewall на 853/TCP'
MSG_EN[M_0248]='DoT Whitelist (ENABLED): blocked IPv6 is dropped by firewall on 853/TCP'
MSG_RU[M_0249]='DoT Whitelist (ENABLED): правило разрешённого IPv6 активно в ip6tables и ipset'
MSG_EN[M_0249]='DoT Whitelist (ENABLED): allowed IPv6 rule is active in ip6tables and ipset'
MSG_RU[M_0250]='DoT Whitelist: автоматическое истечение TTL записи в ipset работает'
MSG_EN[M_0250]='DoT Whitelist: automatic TTL expiration of ipset entry works'
MSG_RU[M_0251]='DoT Whitelist: повторная авторизация обновляет TTL до 86400s (TTL=%s)'
MSG_EN[M_0251]='DoT Whitelist: re-authorization refreshes TTL to 86400s (TTL=%s)'
MSG_RU[M_0252]='DoT Whitelist (DISABLED): неверный SNI на 853/TCP блокируется Xray'
MSG_EN[M_0252]='DoT Whitelist (DISABLED): invalid SNI on 853/TCP is blocked by Xray'
MSG_RU[M_0253]='DoT Whitelist (DISABLED): подключение без IP-фильтрации с валидным DOT_HOST работает'
MSG_EN[M_0253]='DoT Whitelist (DISABLED): connection without IP filtering using valid DOT_HOST works'
MSG_RU[M_0254]='Сохранение настроек после перезагрузки и защита внутренних портов (включая 9444 и 8053) активны'
MSG_EN[M_0254]='Settings persistence after reboot and internal port protection (including 9444 and 8053) are active'
MSG_RU[M_0255]='Процедурный Cover Site доступен (HTTP 200), CSS загружается и разметка валидна'
MSG_EN[M_0255]='Procedural Cover Site is reachable (HTTP 200), CSS loads, and markup is valid'
MSG_RU[M_0256]='Негативный тест: повреждённый JSON блокируется проверкой xray run -test'
MSG_EN[M_0256]='Negative test: malformed JSON is rejected by xray run -test validation'
MSG_RU[M_0257]='Цепочки Firewall (PREROUTING/INPUT/OUTPUT) и ipset активны'
MSG_EN[M_0257]='Firewall chains (PREROUTING/INPUT/OUTPUT) and ipset are active'
MSG_RU[M_0258]='РЕЗУЛЬТАТ: Все проверки успешно пройдены!\n'
MSG_EN[M_0258]='RESULT: All checks passed successfully!\n'
MSG_RU[M_0259]='РЕЗУЛЬТАТ: Обнаружено ошибок: %d. Проверьте журналы в %s.\n'
MSG_EN[M_0259]='RESULT: Errors detected: %d. Check logs in %s.\n'
MSG_RU[M_0260]='\nПубличный отчёт сохранён в: %s\n'
MSG_EN[M_0260]='\nPublic report saved to: %s\n'
MSG_RU[M_0261]='Секретные параметры сохранены в: %s (права 0600)\n'
MSG_EN[M_0261]='Secret parameters saved to: %s (mode 0600)\n'
MSG_RU[M_0262]='Показать секретные ссылки DoH и /auth/ прямо сейчас в терминале? [y/N]: '
MSG_EN[M_0262]='Display secret DoH and /auth/ URLs in the terminal right now? [y/N]: '
MSG_RU[M_0263]='Перегенерация уникального Cover Site успешно завершена.'
MSG_EN[M_0263]='Unique Cover Site regeneration completed successfully.'
MSG_RU[M_0264]='=== СТАТУС СЛУЖБ SMARTDNS + SNI PROXY ===\n'
MSG_EN[M_0264]='=== SMARTDNS + SNI PROXY SERVICES STATUS ===\n'
MSG_RU[M_0265]='Активный DNS_ENGINE'
MSG_EN[M_0265]='Active DNS_ENGINE'
MSG_RU[M_0266]='ОШИБКА: Система не установлена.\n'
MSG_EN[M_0266]='ERROR: System is not installed.\n'
MSG_RU[M_0267]='Обновление всех компонентов, маскировки и списков успешно завершено.'
MSG_EN[M_0267]='Update of all components, cover site, and domain lists completed successfully.'
MSG_RU[M_0268]='ВНИМАНИЕ: Вы действительно хотите удалить стек SmartDNS + Xray? [y/N]: '
MSG_EN[M_0268]='WARNING: Are you sure you want to uninstall the SmartDNS + Xray stack? [y/N]: '
MSG_RU[M_0269]='Службы и правила маршрутизации отключены. Резервные копии сохранены в %s.\n'
MSG_EN[M_0269]='Services and routing rules disabled. Backups preserved in %s.\n'
MSG_RU[M_0270]='Запуск транзакционной установки Unified SmartDNS + SNI Proxy (%s)...'
MSG_EN[M_0270]='Starting transactional installation of Unified SmartDNS + SNI Proxy (%s)...'
MSG_RU[M_0271]='Синхронизация DNS-записей домена %s в Cloudflare...'
MSG_EN[M_0271]='Synchronizing DNS records for domain %s in Cloudflare...'
MSG_RU[M_0272]='Не удалось автоматически обновить A/AAAA записи через Cloudflare API. Проверьте их в панели Cloudflare.'
MSG_EN[M_0272]='Failed to automatically update A/AAAA records via Cloudflare API. Please check them in the Cloudflare dashboard.'
MSG_RU[M_0273]='Использование: ${SCRIPT_NAME} [РЕЖИМ]

Доступные режимы работы:
  --help                           Вывести эту справку
  --preflight                      Проверка готовности сервера в режиме только чтения (без изменений)
  --hostname-check                 Проверка Provider Hostname Profile (DNS/TLS/Certbot) без изменений
  --profile [cloudflare|hostname]  Выбрать профиль установки (Cloudflare DNS-01 или Provider Hostname)
  --initial-setup                  Initial Server Setup & SSH Security Hardening
  --install                        Полная интерактивная транзакционная установка стека
  --switch-engine [oxidns|adguardhome]
                                   Транзакционное переключение DNS backend с сохранением сертификатов и OxiDNS
  --sync-ip                        Автоматическое обновление IP сервера в локальных конфигах и Cloudflare DNS
  --change-domain [DOM]            Быстрая смена домена и перевыпуск сертификата без смены префикса DoT и путей
  --domain-groups                  Управление группами проксируемых доменов и импорт пользовательского списка
  --update                         Безопасное обновление компонентов и списков (с сохранением Cover Site)
  --regenerate-cover               Осознанная перегенерация уникального Cover Site с резервным копированием
  --status                         Просмотр текущего состояния служб, DNS_ENGINE и ipset
  --test                           Запуск комплексного набора функциональных и негативных тестов
  --backup                         Создание внеплановой резервной копии конфигураций и правил
  --rollback                       Аварийный откат к последней рабочей резервной копии
  --uninstall                      Интерактивное полное или выборочное удаление с восстановлением backup

Управление DoT IP-whitelist (TCP 853):
  --whitelist-status               Просмотр статуса DoT whitelist, списка разрешённых IPv4/IPv6 и их TTL
  --whitelist-toggle [on|off]      Включить, выключить или переключить (без аргумента) IP-whitelist для DoT (TCP 853)
  --whitelist-mode [shared|separate]
                                   Выбрать общий (smartdns_clients) или отдельный (dot_clients) набор IP для DoT
  --whitelist-add IP               Добавить одиночный IPv4 или IPv6 адрес в whitelist на 86400 секунд
  --whitelist-remove IP            Удалить одиночный IPv4 или IPv6 адрес из whitelist
  --whitelist-flush                Полностью очистить список разрешённых IP-адресов'
MSG_EN[M_0273]='Usage: sudo ./smartdns-installer-v3.0-stealth.sh <COMMAND>

Commands:
  --help, -h                       Show this help message and exit
  --preflight                      Run read-only system, network, and port preflight checks
  --hostname-check                 Read-only Provider Hostname Profile check (DNS/TLS/Certbot/ports)
  --profile [cloudflare|hostname]  Select installation profile (Cloudflare DNS-01 or Provider Hostname)
  --initial-setup                  Initial Server Setup & SSH Security Hardening
  --install                        Run interactive transactional installation of the full stack
  --status                         Show active DNS engine, systemd services/timers, and ipset state
  --test                           Run 25 functional and negative self-tests
  --switch-engine [oxidns|adguardhome]
                                   Transactionally switch active DNS engine on a live server
  --regenerate-cover               Explicitly regenerate a new unique Cover Site with backup
  --sync-ip                        Auto-detect new server IPv4/IPv6 and sync configs, firewall & Cloudflare
  --change-domain [NEW_DOMAIN]     Change primary domain (ROOT_DOMAIN) and reissue TLS certificate
  --domain-groups                  Manage proxied domain groups and import custom domain lists
  --update                         Safely update Xray/DNS binaries and domain lists (preserves Cover Site)
  --backup                         Create an on-demand full backup of configs, TLS, and firewall rules
  --rollback [PATH]                Roll back system state to the latest (or specified) backup
  --uninstall                      Interactive full or selective uninstall with backup restoration
  --whitelist-status               Show DoT IP whitelist (853/TCP) status, mode, and authorized IPs
  --whitelist-toggle [on|off]      Enable, disable, or toggle DoT IP filtering on port 853/TCP
  --whitelist-mode [shared|separate]
                                   Switch DoT whitelist mode between shared and isolated ipset sets
  --whitelist-add <IP>             Manually add a single IPv4 or IPv6 address to whitelist (24h TTL)
  --whitelist-remove <IP>          Immediately remove a single IPv4 or IPv6 address from whitelist
  --whitelist-flush                Flush all authorized IPv4/IPv6 addresses from DoT whitelist'
MSG_RU[M_0274]='Неизвестный параметр: %s\n'
MSG_EN[M_0274]='Unknown option: %s\n'
MSG_RU[M_0275]='Инициализация защищённого хранилища первоначального backup в %s...'
MSG_EN[M_0275]='Initializing protected initial backup store in %s...'
MSG_RU[M_0276]='Первоначальный backup уже запечатан (%s). Повторная перезапись запрещена.'
MSG_EN[M_0276]='Initial backup is already sealed (%s). Overwriting is prohibited.'
MSG_RU[M_0277]='ОШИБКА backup перед изменением %s: контрольная сумма или метаданные не подтверждены. Изменение файла заблокировано.'
MSG_EN[M_0277]='Backup error before modifying %s: checksum or metadata verification failed. File modification aborted.'
MSG_RU[M_0278]='Выполнен pre-modify backup файла %s (SHA-256: %s).'
MSG_EN[M_0278]='Completed pre-modify backup of %s (SHA-256: %s).'
MSG_RU[M_0279]='Первоначальный backup проверен и запечатан (%s).'
MSG_EN[M_0279]='Initial backup verified and sealed (%s).'
MSG_RU[M_0280]='Проверка целостности backup не пройдена для %s (ожидался SHA-256: %s, получен: %s).'
MSG_EN[M_0280]='Backup integrity check failed for %s (expected SHA-256: %s, got: %s).'
MSG_RU[M_0281]='Проверка целостности backup в %s успешно пройдена (проверено записей: %s).'
MSG_EN[M_0281]='Backup integrity check in %s passed successfully (verified entries: %s).'
MSG_RU[M_0282]='Инициализирован installation manifest: %s'
MSG_EN[M_0282]='Initialized installation manifest: %s'
MSG_RU[M_0283]='Installation manifest обновлён (%s).'
MSG_EN[M_0283]='Installation manifest updated (%s).'
MSG_RU[M_0284]='Не удалось запечатать первоначальный backup: проверка целостности завершилась ошибкой.'
MSG_EN[M_0284]='Failed to seal initial backup: integrity verification failed.'
MSG_RU[M_0285]='=== UNINSTALL (УДАЛЕНИЕ UNIFIED SMARTDNS STACK) ===\n'
MSG_EN[M_0285]='=== UNINSTALL (UNIFIED SMARTDNS STACK REMOVAL) ===\n'
MSG_RU[M_0286]='Установленные компоненты SmartDNS не обнаружены в системе. Удалять нечего.\n'
MSG_EN[M_0286]='No installed SmartDNS components were detected on this system. Nothing to remove.\n'
MSG_RU[M_0287]='Installation manifest : %s\n'
MSG_EN[M_0287]='Installation manifest : %s\n'
MSG_RU[M_0288]='Initial backup        : %s\n'
MSG_EN[M_0288]='Initial backup        : %s\n'
MSG_RU[M_0289]='НАЙДЕН И ВАЛИДЕН'
MSG_EN[M_0289]='FOUND AND VALID'
MSG_RU[M_0290]='ОТСУТСТВУЕТ ИЛИ ПОВРЕЖДЁН (безопасный legacy-режим)'
MSG_EN[M_0290]='MISSING OR CORRUPTED (safe legacy mode)'
MSG_RU[M_0291]='ПРОВЕРЕН (SHA-256 OK)'
MSG_EN[M_0291]='VERIFIED (SHA-256 OK)'
MSG_RU[M_0292]='ОТСУТСТВУЕТ ИЛИ ОШИБКА ЦЕЛОСТНОСТИ (системные файлы не будут перезаписаны)'
MSG_EN[M_0292]='MISSING OR INTEGRITY FAILED (system files will not be overwritten)'
MSG_RU[M_0293]='\nОбнаруженные компоненты (отмеченные [x] будут УДАЛЕНЫ, [ ] — СОХРАНЕНЫ):\n\n'
MSG_EN[M_0293]='\nDetected components ([x] will be REMOVED, [ ] will be KEPT):\n\n'
MSG_RU[M_0294]='\nВыберите действие:\n  [ A ] Удалить все обнаруженные компоненты\n  [ S ] Сохранить все компоненты (выход)\n  [ C ] Настроить выборочно\n  [ Q ] Отмена\n\nВаш выбор [Q]: '
MSG_EN[M_0294]='\nSelect an action:\n  [ A ] Remove all detected components\n  [ S ] Keep all components (exit)\n  [ C ] Custom selection\n  [ Q ] Cancel\n\nYour choice [Q]: '
MSG_RU[M_0295]='Удаление отменено пользователем. Изменения в систему не вносились.\n'
MSG_EN[M_0295]='Uninstall cancelled by user. No changes were made to the system.\n'
MSG_RU[M_0296]='Введите номера компонентов через пробел для переключения, [D] — продолжить, [A] — выбрать все, [N] — снять все, [Q] — отмена: '
MSG_EN[M_0296]='Enter component numbers separated by spaces to toggle, [D] to continue, [A] all, [N] none, [Q] cancel: '
MSG_RU[M_0297]='Не выбрано ни одного компонента для удаления. Изменения не вносились.\n'
MSG_EN[M_0297]='No components selected for removal. No changes were made.\n'
MSG_RU[M_0298]='\nВНИМАНИЕ: Обнаружены конфликты зависимостей между сохраняемыми и удаляемыми компонентами:\n'
MSG_EN[M_0298]='\nWARNING: Dependency conflicts detected between kept and removed components:\n'
MSG_RU[M_0299]='  - Сохранение [%s] требует сохранения [%s] (%s)\n'
MSG_EN[M_0299]='  - Keeping [%s] requires keeping [%s] (%s)\n'
MSG_RU[M_0300]='\nВыберите разрешение конфликта:\n  [ 1 ] Автоматически сохранить необходимые зависимости\n  [ 2 ] Вернуться к выбору компонентов\n  [ Q ] Отменить удаление\nВаш выбор [1]: '
MSG_EN[M_0300]='\nResolve conflict:\n  [ 1 ] Automatically keep required dependencies\n  [ 2 ] Return to component selection\n  [ Q ] Cancel uninstall\nYour choice [1]: '
MSG_RU[M_0301]='\n==================== ПЛАН УДАЛЕНИЯ ====================\n'
MSG_EN[M_0301]='\n==================== UNINSTALL PLAN ====================\n'
MSG_RU[M_0302]='Будут УДАЛЕНЫ:\n'
MSG_EN[M_0302]='Will be REMOVED:\n'
MSG_RU[M_0303]='Будут СОХРАНЕНЫ:\n'
MSG_EN[M_0303]='Will be KEPT:\n'
MSG_RU[M_0304]='  (нет)\n'
MSG_EN[M_0304]='  (none)\n'
MSG_RU[M_0305]='Пользовательские правила (custom-allow.txt / custom-deny.txt): %s\n'
MSG_EN[M_0305]='User custom rules (custom-allow.txt / custom-deny.txt): %s\n'
MSG_RU[M_0306]='УДАЛИТЬ'
MSG_EN[M_0306]='REMOVE'
MSG_RU[M_0307]='СОХРАНИТЬ'
MSG_EN[M_0307]='KEEP'
MSG_RU[M_0308]='Удалить пользовательские списки custom-allow.txt и custom-deny.txt? [y/N]: '
MSG_EN[M_0308]='Delete user custom lists custom-allow.txt and custom-deny.txt? [y/N]: '
MSG_RU[M_0309]='Удалить системные пакеты, установленные именно этим скриптом (%s)? [y/N]: '
MSG_EN[M_0309]='Remove APT packages installed exclusively by this script (%s)? [y/N]: '
MSG_RU[M_0310]='Пакеты APT к удалению : %s\n'
MSG_EN[M_0310]='APT packages to remove: %s\n'
MSG_RU[M_0311]='Подтверждаете выполнение плана удаления? Введите YES для запуска (любой другой ввод — отмена): '
MSG_EN[M_0311]='Confirm executing the uninstall plan? Type YES to proceed (anything else cancels): '
MSG_RU[M_0312]='\nВНИМАНИЕ: Файл %s был изменён вручную после установки (или отсутствует исходный контрольный хеш).\n'
MSG_EN[M_0312]='\nWARNING: File %s was modified after installation (or baseline hash is unavailable).\n'
MSG_RU[M_0313]='Выберите действие для %s:\n  [ K ] Сохранить текущую версию (по умолчанию)\n'
MSG_EN[M_0313]='Select action for %s:\n  [ K ] Keep current version (default)\n'
MSG_RU[M_0314]='  [ R ] Восстановить оригинальную версию из initial-backup\n'
MSG_EN[M_0314]='  [ R ] Restore original version from initial-backup\n'
MSG_RU[M_0315]='  [ D ] Показать различия (diff -u с initial-backup)\n'
MSG_EN[M_0315]='  [ D ] Show differences (diff -u against initial-backup)\n'
MSG_RU[M_0316]='  [ X ] Удалить файл без восстановления\n'
MSG_EN[M_0316]='  [ X ] Delete file without restoration\n'
MSG_RU[M_0317]='  [ C ] Отменить удаление данного файла (сохранить)\nВаш выбор [K]: '
MSG_EN[M_0317]='  [ C ] Cancel deletion of this file (keep)\nYour choice [K]: '
MSG_RU[M_0318]='Сохранён файл %s по выбору пользователя.'
MSG_EN[M_0318]='Preserved file %s per user selection.'
MSG_RU[M_0319]='Восстановлен оригинальный файл %s из initial-backup (SHA-256 подтверждён).'
MSG_EN[M_0319]='Restored original file %s from initial-backup (SHA-256 verified).'
MSG_RU[M_0320]='Ошибка восстановления %s из initial-backup: файл сохранен без изменений.'
MSG_EN[M_0320]='Failed to restore %s from initial-backup: existing file preserved unchanged.'
MSG_RU[M_0321]='Удалён управляемый файл %s.'
MSG_EN[M_0321]='Removed managed file %s.'
MSG_RU[M_0322]='Не удаляется файл %s: исходный backup отсутствует или повреждён.'
MSG_EN[M_0322]='Skipping deletion of %s: original backup is missing or corrupted.'
MSG_RU[M_0323]='[UNINSTALL] Удаление компонента: %s...'
MSG_EN[M_0323]='[UNINSTALL] Removing component: %s...'
MSG_RU[M_0324]='[UNINSTALL] ОШИБКА при удалении компонента %s. Критические зависимости и backup сохранены.'
MSG_EN[M_0324]='[UNINSTALL] ERROR while removing component %s. Critical dependencies and backups are preserved.'
MSG_RU[M_0325]='Удалить также каталог резервных копий (%s и %s)? [y/N]: '
MSG_EN[M_0325]='Also delete backup directories (%s and %s)? [y/N]: '
MSG_RU[M_0326]='Удаление завершено успешно. Резервные копии сохранены в %s.\n'
MSG_EN[M_0326]='Uninstall completed successfully. Backups preserved in %s.\n'
MSG_RU[M_0327]='Полное удаление завершено успешно (включая резервные копии по запросу пользователя).\n'
MSG_EN[M_0327]='Full uninstall completed successfully (including backups per user request).\n'
MSG_RU[M_0328]='Частичное удаление завершено с ошибками (%s). Manifest и резервные копии сохранены в %s; вы можете безопасно повторить --uninstall.\n'
MSG_EN[M_0328]='Partial uninstall finished with errors (%s). Manifest and backups preserved in %s; you may safely re-run --uninstall.\n'
MSG_RU[M_0329]='Частичное удаление завершено: выбранные компоненты удалены, сохранённые компоненты и manifest оставлены в системе.\n'
MSG_EN[M_0329]='Selective uninstall completed: selected components removed, kept components and manifest preserved.\n'
MSG_RU[M_0330]='Каталог %s не пуст (содержит сторонние или сохранённые файлы) — пропущен.'
MSG_EN[M_0330]='Directory %s is not empty (contains third-party or preserved files) — skipped.'
MSG_RU[M_0331]='Удалить также локальный клиент /root/.acme.sh (при отсутствии других доменов)? [y/N]: '
MSG_EN[M_0331]='Also remove local /root/.acme.sh client (if no other domains exist)? [y/N]: '
MSG_RU[M_0332]='Различия недоступны: до установки файла %s не существовало.\n'
MSG_EN[M_0332]='Diff unavailable: %s did not exist prior to installation.\n'
MSG_RU[M_0333]='\nЗагрузка и индексация групп доменов GeoHideDNS...\n'
MSG_EN[M_0333]='\nFetching and indexing GeoHideDNS domain groups...\n'
MSG_RU[M_0334]='ПРЕДУПРЕЖДЕНИЕ: Не удалось загрузить свежий GeoHideDNS (%s); используются локальные данные или 0.\n'
MSG_EN[M_0334]='WARNING: Failed to fetch fresh GeoHideDNS (%s); using local cache or 0.\n'
MSG_RU[M_0335]='\n==================== ГРУППЫ ПРОКСИРУЕМЫХ ДОМЕНОВ ====================\n'
MSG_EN[M_0335]='\n==================== PROXY DOMAIN GROUPS ====================\n'
MSG_RU[M_0336]='Выберите необходимые группы ([x] — включена, [ ] — отключена):\n\n'
MSG_EN[M_0336]='Select required groups ([x] — enabled, [ ] — disabled):\n\n'
MSG_RU[M_0337]='\nВыберите действие:\n  [ A ] Все группы\n  [ N ] Ни одной группы\n  [ C ] Настроить выборочно\n  [ Q ] Отмена\n\nВаш выбор: '
MSG_EN[M_0337]='\nSelect an action:\n  [ A ] All groups\n  [ N ] None (no upstream groups)\n  [ C ] Custom selection\n  [ Q ] Cancel\n\nYour choice: '
MSG_RU[M_0338]='Введите номера групп через пробел для переключения, [D] — подтвердить, [A] — все, [N] — ни одной, [Q] — отмена: '
MSG_EN[M_0338]='Enter group numbers separated by spaces to toggle, [D] confirm, [A] all, [N] none, [Q] cancel: '
MSG_RU[M_0339]='Выбор групп доменов: %s\n'
MSG_EN[M_0339]='Selected domain groups: %s\n'
MSG_RU[M_0340]='Выбор групп отменён пользователем.\n'
MSG_EN[M_0340]='Domain group selection cancelled by user.\n'
MSG_RU[M_0341]='\nЖелаете добавить свой файл со списком доменов для проксирования? [y/N]: '
MSG_EN[M_0341]='\nWould you like to add your own file with a list of domains to proxy? [y/N]: '
MSG_RU[M_0342]='Введите локальный путь к файлу или ссылку (http:// / https://) [Enter — отмена]: '
MSG_EN[M_0342]='Enter local file path or URL (http:// / https://) [Enter to cancel]: '
MSG_RU[M_0343]='Загрузка пользовательского списка доменов по URL: %s...\n'
MSG_EN[M_0343]='Downloading custom domain list from URL: %s...\n'
MSG_RU[M_0344]='ОШИБКА: Не удалось скачать файл по URL %s (проверьте доступность и размер <= 10 МБ).\n'
MSG_EN[M_0344]='ERROR: Failed to download file from URL %s (check availability and size <= 10 MB).\n'
MSG_RU[M_0345]='ОШИБКА: Локальный файл не найден или недоступен для чтения: %s\n'
MSG_EN[M_0345]='ERROR: Local file not found or not readable: %s\n'
MSG_RU[M_0346]='\n---------- АНАЛИЗ ПОЛЬЗОВАТЕЛЬСКОГО СПИСКА ДОМЕНОВ ----------\n'
MSG_EN[M_0346]='\n---------- CUSTOM DOMAIN LIST ANALYSIS ----------\n'
MSG_RU[M_0347]='Источник                                          : %s\n'
MSG_EN[M_0347]='Source                                            : %s\n'
MSG_RU[M_0348]='Валидных уникальных доменов в файле               : %s\n'
MSG_EN[M_0348]='Valid unique domains in file                      : %s\n'
MSG_RU[M_0349]='Исключено внутренних дубликатов внутри файла      : %s\n'
MSG_EN[M_0349]='Removed duplicate entries within file             : %s\n'
MSG_RU[M_0350]='Отброшено невалидных строк                        : %s\n'
MSG_EN[M_0350]='Discarded invalid lines                           : %s\n'
MSG_RU[M_0351]='Исключено пересечений с выбранными группами/allow : %s\n'
MSG_EN[M_0351]='Excluded overlaps with selected groups/custom     : %s\n'
MSG_RU[M_0352]='Отклонено системными исключениями / custom-deny   : %s\n'
MSG_EN[M_0352]='Excluded by system safety rules / custom-deny     : %s\n'
MSG_RU[M_0353]='Новых уникальных доменов к добавлению             : %s\n'
MSG_EN[M_0353]='New unique domains to be added                    : %s\n'
MSG_RU[M_0354]='-------------------------------------------------------------\n'
MSG_EN[M_0354]='-------------------------------------------------------------\n'
MSG_RU[M_0355]='Новых уникальных доменов для добавления не найдено (все домены уже присутствуют или невалидны).\n'
MSG_EN[M_0355]='No new unique domains to add (all domains already exist or were invalid).\n'
MSG_RU[M_0356]='Добавить эти %s уникальных доменов в пользовательский список проксирования? [Y/n]: '
MSG_EN[M_0356]='Add these %s unique domains to the custom proxy list? [Y/n]: '
MSG_RU[M_0357]='Подготовлено к добавлению %s уникальных доменов (без дубликатов).\n'
MSG_EN[M_0357]='Staged %s unique domains for addition (deduplicated).\n'
MSG_RU[M_0358]='Добавить ещё один файл или URL со списком доменов? [y/N]: '
MSG_EN[M_0358]='Add another file or URL with a domain list? [y/N]: '
MSG_RU[M_0359]='В пользовательский список %s добавлено новых уникальных доменов: %s (итого в custom-allow: %s).'
MSG_EN[M_0359]='Added %s new unique domains to %s (total in custom-allow: %s).'
MSG_RU[M_0360]='Выбранные группы доменов   : %s\n'
MSG_EN[M_0360]='Selected domain groups     : %s\n'
MSG_RU[M_0361]='Новых доменов из файла     : %s\n'
MSG_EN[M_0361]='Custom domains from file   : %s\n'
MSG_RU[M_0362]='Текущие выбранные группы   : %s\n'
MSG_EN[M_0362]='Current selected groups    : %s\n'
MSG_RU[M_0363]='Текущих доменов в custom-allow.txt : %s\n'
MSG_EN[M_0363]='Current domains in custom-allow.txt: %s\n'
MSG_RU[M_0364]='Применить обновлённый выбор групп (%s) и пересобрать правила Xray/DNS? [y/N]: '
MSG_EN[M_0364]='Apply updated domain groups (%s) and rebuild Xray/DNS rules? [y/N]: '
MSG_RU[M_0365]='Обновление групп доменов (%s) успешно применено и проверено.'
MSG_EN[M_0365]='Domain group update (%s) applied and verified successfully.'
MSG_RU[M_0366]='[ SKIP ] Список проксируемых доменов пуст (режим групп: %s) — проверки подмены A/AAAA/HTTPS пропущены\n'
MSG_EN[M_0366]='[ SKIP ] Proxied domain list is empty (groups mode: %s) — A/AAAA/HTTPS rewrite checks skipped\n'
MSG_RU[M_0367]='Список проксируемых доменов пуст (выбраны группы: %s) — пропуск теста подмены'
MSG_EN[M_0367]='Proxied domain list is empty (selected groups: %s) — rewrite test skipped'
MSG_RU[M_0368]='Выберите корректный пункт меню (A, N, C или Q).\n'
MSG_EN[M_0368]='Please select a valid menu option (A, N, C, or Q).\n'
MSG_RU[M_0369]='Настройка автоматического продления TLS-сертификатов (smartdns-cert-renew.timer + атомарный deploy-хук)...'
MSG_EN[M_0369]='Configuring automated TLS certificate renewal (smartdns-cert-renew.timer + atomic deploy hook)...'
MSG_RU[M_0370]='Автопродление сертификатов настроено: smartdns-cert-renew.timer активен, reloadcmd подключён.'
MSG_EN[M_0370]='Certificate auto-renewal configured: smartdns-cert-renew.timer is active, reloadcmd linked.'
MSG_RU[M_0371]='Предупреждение: не удалось зарегистрировать --install-cert в acme.sh для %s (будет использован fallback в deploy-хуке).'
MSG_EN[M_0371]='Warning: failed to register --install-cert in acme.sh for %s (deploy hook fallback will be used).'
MSG_RU[M_0372]='Автопродление TLS (smartdns-cert-renew.timer + deploy-хук acme.sh) активно и корректно настроено'
MSG_EN[M_0372]='TLS auto-renewal (smartdns-cert-renew.timer + acme.sh deploy hook) is active and properly configured'
MSG_RU[M_0373]='Профиль acme.sh для %s не найден; таймер создан и готов к работе после выпуска сертификата.'
MSG_EN[M_0373]='acme.sh profile for %s not found; renewal timer created and ready after certificate issuance.'
MSG_RU[M_0374]='Загрузка базы geosite.dat с GitHub (может занять до 1-2 минут)...'
MSG_EN[M_0374]='Downloading geosite.dat from GitHub (may take 1-2 minutes)...'
MSG_RU[M_0375]='Загрузка GeoHideDNS и генерация правил маршрутизации Xray/DNS...'
MSG_EN[M_0375]='Downloading GeoHideDNS and generating Xray/DNS routing rules...'
MSG_RU[M_0376]='Активирован запрет перезагрузки (reboot-lock) до успешной установки и проверки SmartDNS (%s).'
MSG_EN[M_0376]='Reboot lock activated until SmartDNS is installed and verified (%s).'
MSG_RU[M_0377]='\n==============================================================================\nВНИМАНИЕ!\n\nДля применения некоторых системных обновлений\nтребуется перезагрузка сервера.\n\nПричина / пакеты: %s\n\nПерезагрузка автоматически НЕ выполняется.\nУстановка будет продолжена без перезагрузки,\nесли это безопасно и технически возможно.\n\nПерезагрузка будет разрешена только после\nуспешного завершения установки и проверки SmartDNS.\n==============================================================================\n'
MSG_EN[M_0377]='\n==============================================================================\nWARNING!\n\nA server reboot is required to apply some system updates.\n\nReason / packages: %s\n\nAutomatic reboot is NOT performed.\nInstallation will continue without rebooting\nif it is safe and technically possible.\n\nReboot will only be permitted after SmartDNS\ninstallation and verification succeed.\n==============================================================================\n'
MSG_RU[M_0378]='ВНИМАНИЕ: Обнаружены сторонние механизмы автоперезагрузки: %s. Установщик заблокирует автоматический reboot на время своей работы.'
MSG_EN[M_0378]='WARNING: External auto-reboot triggers detected: %s. The installer will suppress automatic reboot during execution.'
MSG_RU[M_0379]='Невозможно безопасно продолжить установку без устранения системного состояния: %s'
MSG_EN[M_0379]='Cannot safely continue installation without resolving system state: %s'
MSG_RU[M_0380]='\n==============================================================================\nУСТАНОВКА ПРИОСТАНОВЛЕНА ДЛЯ БЕЗОПАСНОГО ВОССТАНОВЛЕНИЯ\n==============================================================================\nЭтап           : %s\nПричина        : %s\nСостояние      : %s\nЖурнал         : %s/installation.log\n\nЗапрет автоматической перезагрузки (REBOOT_LOCKED=true) СОХРАНЁН.\nПосле устранения причины повторите запуск:\n  sudo ./%s --install\n==============================================================================\n'
MSG_EN[M_0380]='\n==============================================================================\nINSTALLATION PAUSED FOR SAFE RECOVERY\n==============================================================================\nStage          : %s\nReason         : %s\nState file     : %s\nLog file       : %s/installation.log\n\nReboot lock (REBOOT_LOCKED=true) remains ACTIVE.\nAfter resolving the issue, resume installation with:\n  sudo ./%s --install\n==============================================================================\n'
MSG_RU[M_0381]='Запрет перезагрузки НЕ снят: не выполнены обязательные условия проверки SmartDNS (%s).'
MSG_EN[M_0381]='Reboot lock NOT released: mandatory SmartDNS verification conditions not met (%s).'
MSG_RU[M_0382]='SmartDNS установлен, проверен и активен (%s). Запрет перезагрузки (reboot-lock) снят.'
MSG_EN[M_0382]='SmartDNS installed, verified, and active (%s). Reboot lock has been released.'
MSG_RU[M_0383]='\n==============================================================================\nВНИМАНИЕ: ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА СЕРВЕРА (SmartDNS УСПЕШНО УСТАНОВЛЕН)\n==============================================================================\nУстановка и проверка SmartDNS успешно завершены, запрет перезагрузки снят.\nДля применения отложенных системных обновлений рекомендуется перезагрузить сервер.\n\nПричины / пакеты : %s\n\nПерезагрузка НЕ выполняется автоматически.\nВыполнить перезагрузку сервера прямо сейчас? Введите YES для подтверждения [N]: '
MSG_EN[M_0383]='\n==============================================================================\nNOTICE: SERVER REBOOT REQUIRED (SmartDNS SUCCESSFULLY INSTALLED)\n==============================================================================\nSmartDNS installation and verification succeeded; reboot lock is released.\nA reboot is recommended to apply deferred system updates.\n\nReasons / packages: %s\n\nReboot is NOT performed automatically.\nReboot the server right now? Type YES to confirm [N]: '
MSG_RU[M_0384]='Перезагрузка отложена пользователем. Вы можете выполнить её позже командой: sudo systemctl reboot\n'
MSG_EN[M_0384]='Reboot deferred by user. You may reboot later using: sudo systemctl reboot\n'
MSG_RU[M_0385]='Пользователь подтвердил перезагрузку после успешной проверки SmartDNS. Выполняется systemctl reboot...'
MSG_EN[M_0385]='User confirmed reboot after SmartDNS verification. Executing systemctl reboot...'
MSG_RU[M_0386]='ОШИБКА: Попытка перезагрузки заблокирована — SmartDNS не прошёл обязательную проверку.'
MSG_EN[M_0386]='ERROR: Reboot attempt blocked — SmartDNS has not passed mandatory verification.'
MSG_RU[M_0387]='\n--- [1] ПОЛНОЕ ОБНОВЛЕНИЕ СИСТЕМЫ ---\n'
MSG_EN[M_0387]='\n--- [1] FULL SYSTEM UPDATE ---\n'
MSG_RU[M_0388]='Обновление системы уже выполнялось в этом сеансе/установке. Повторить проверку обновлений? [y/N]: '
MSG_EN[M_0388]='System update was already completed previously. Re-run update check? [y/N]: '
MSG_RU[M_0389]='ОШИБКА: Недостаточно свободного места для безопасного обновления ОС: %s МБ (минимум 1500 МБ).\n'
MSG_EN[M_0389]='ERROR: Insufficient free disk space for safe OS update: %s MB (minimum 1500 MB).\n'
MSG_RU[M_0390]='Проверка доступности репозиториев APT (apt-get update)...\n'
MSG_EN[M_0390]='Checking APT repositories reachability (apt-get update)...\n'
MSG_RU[M_0391]='ОШИБКА: Не удалось обновить списки пакетов (apt-get update). Проверьте сеть и репозитории.\n'
MSG_EN[M_0391]='ERROR: Failed to update package lists (apt-get update). Check network and repositories.\n'
MSG_RU[M_0392]='Все установленные пакеты ОС уже актуальны (0 обновлений).\n'
MSG_EN[M_0392]='All installed OS packages are already up to date (0 upgrades).\n'
MSG_RU[M_0393]='Доступно обновлений пакетов: %s (переход на другую major-версию ОС не выполняется; перезагрузка заблокирована).\n'
MSG_EN[M_0393]='Available package upgrades: %s (major OS release upgrade will NOT be performed; reboot is locked).\n'
MSG_RU[M_0394]='Выполнить обновление пакетов ОС сейчас? [y/N]: '
MSG_EN[M_0394]='Proceed with OS package upgrade now? [y/N]: '
MSG_RU[M_0395]='Обновление пакетов ОС пропущено пользователем.\n'
MSG_EN[M_0395]='OS package upgrade skipped by user.\n'
MSG_RU[M_0396]='Выполняется non-interactive обновление пакетов ОС (без перезагрузки)...\n'
MSG_EN[M_0396]='Running non-interactive OS package upgrade (no reboot)...\n'
MSG_RU[M_0397]='Обновление пакетов ОС успешно завершено.\n'
MSG_EN[M_0397]='OS package upgrade completed successfully.\n'
MSG_RU[M_0398]='Найдены неиспользуемые пакеты для безопасного autoremove: %s\n'
MSG_EN[M_0398]='Unused packages available for safe autoremove: %s\n'
MSG_RU[M_0399]='Выполнить apt-get autoremove для этих пакетов? [y/N]: '
MSG_EN[M_0399]='Run apt-get autoremove for these packages? [y/N]: '
MSG_RU[M_0400]='ПРЕДУПРЕЖДЕНИЕ: Список autoremove содержит критически важные пакеты (%s) — удаление пропущено.\n'
MSG_EN[M_0400]='WARNING: autoremove list contains critical packages (%s) — removal skipped.\n'
MSG_RU[M_0401]='\n--- [2] ПРОВЕРКА И УСТАНОВКА SUDO ---\n'
MSG_EN[M_0401]='\n--- [2] SUDO CHECK AND INSTALLATION ---\n'
MSG_RU[M_0402]='Пакет и команда sudo уже установлены и работают корректно (%s).\n'
MSG_EN[M_0402]='The sudo package and command are already installed and functional (%s).\n'
MSG_RU[M_0403]='Команда sudo не найдена в системе.\n'
MSG_EN[M_0403]='The sudo command was not found on this system.\n'
MSG_RU[M_0404]='Установить пакет sudo через apt-get? [Y/n]: '
MSG_EN[M_0404]='Install the sudo package via apt-get? [Y/n]: '
MSG_RU[M_0405]='Пакет sudo успешно установлен и проверен.\n'
MSG_EN[M_0405]='The sudo package was installed and verified successfully.\n'
MSG_RU[M_0406]='ОШИБКА: Не удалось установить или проверить sudo.\n'
MSG_EN[M_0406]='ERROR: Failed to install or verify sudo.\n'
MSG_RU[M_0407]='\n--- [3] ИЗМЕНЕНИЕ ПАРОЛЯ ROOT ---\n'
MSG_EN[M_0407]='\n--- [3] CHANGE ROOT PASSWORD ---\n'
MSG_RU[M_0408]='Изменить пароль root? [y/N]: '
MSG_EN[M_0408]='Change root password? [y/N]: '
MSG_RU[M_0409]='Интерактивный терминал недоступен (non-interactive режим) — смена пароля пропущена.\n'
MSG_EN[M_0409]='Interactive terminal unavailable (non-interactive mode) — password change skipped.\n'
MSG_RU[M_0410]='Пароль root успешно изменён.\n'
MSG_EN[M_0410]='Root password changed successfully.\n'
MSG_RU[M_0411]='ПРЕДУПРЕЖДЕНИЕ: Смена пароля root не завершена или отменена.\n'
MSG_EN[M_0411]='WARNING: Root password change was not completed or cancelled.\n'
MSG_RU[M_0412]='\n--- [4] СОЗДАНИЕ / ВЫБОР АДМИНИСТРАТИВНОГО ПОЛЬЗОВАТЕЛЯ ---\n'
MSG_EN[M_0412]='\n--- [4] CREATE / SELECT ADMINISTRATIVE USER ---\n'
MSG_RU[M_0413]='Ранее настроен административный пользователь: %s. Оставить его без изменений? [Y/n]: '
MSG_EN[M_0413]='Previously configured admin user: %s. Keep unchanged? [Y/n]: '
MSG_RU[M_0414]='Создать нового пользователя (или выбрать существующего) для управления сервером? [y/N]: '
MSG_EN[M_0414]='Create a new user (or select an existing one) for server administration? [y/N]: '
MSG_RU[M_0415]='Введите имя пользователя (строчные латинские буквы, цифры, _, -; Enter — отмена): '
MSG_EN[M_0415]='Enter username (lowercase Latin letters, digits, _, -; Enter to cancel): '
MSG_RU[M_0416]='ОШИБКА: Недопустимое или зарезервированное системное имя пользователя: %s\n'
MSG_EN[M_0416]='ERROR: Invalid or reserved system username: %s\n'
MSG_RU[M_0417]='Пользователь "%s" уже существует (UID=%s, home=%s, shell=%s, sudo=%s).\n'
MSG_EN[M_0417]='User "%s" already exists (UID=%s, home=%s, shell=%s, sudo=%s).\n'
MSG_RU[M_0418]='ОШИБКА: Пользователь "%s" является системной учётной записью (UID=%s < 1000). Изменение запрещено.\n'
MSG_EN[M_0418]='ERROR: User "%s" is a system account (UID=%s < 1000). Modification is prohibited.\n'
MSG_RU[M_0419]='Использовать существующего пользователя "%s" для администрирования? [Y/n]: '
MSG_EN[M_0419]='Use existing user "%s" for administration? [Y/n]: '
MSG_RU[M_0420]='Введите полное имя пользователя (опционально, Enter — пропустить): '
MSG_EN[M_0420]='Enter full name (optional, Enter to skip): '
MSG_RU[M_0421]='Создать пользователя "%s" с домашней директорией и shell /bin/bash? [Y/n]: '
MSG_EN[M_0421]='Create user "%s" with home directory and /bin/bash shell? [Y/n]: '
MSG_RU[M_0422]='Задайте пароль для пользователя "%s" (ввод не отображается и не сохраняется в логах):\n'
MSG_EN[M_0422]='Set password for user "%s" (input is hidden and never logged):\n'
MSG_RU[M_0423]='Пользователь "%s" успешно создан (UID=%s, home=%s).\n'
MSG_EN[M_0423]='User "%s" created successfully (UID=%s, home=%s).\n'
MSG_RU[M_0424]='ОШИБКА: Не удалось создать пользователя "%s".\n'
MSG_EN[M_0424]='ERROR: Failed to create user "%s".\n'
MSG_RU[M_0425]='--- ДОБАВЛЕНИЕ ПОЛЬЗОВАТЕЛЯ В ГРУППУ SUDO ---\n'
MSG_EN[M_0425]='--- ADD USER TO SUDO GROUP ---\n'
MSG_RU[M_0426]='Пользователь "%s" уже состоит в группе sudo. Изменения не требуются.\n'
MSG_EN[M_0426]='User "%s" is already a member of the sudo group. No changes needed.\n'
MSG_RU[M_0427]='Добавить пользователя "%s" в группу sudo? [Y/n]: '
MSG_EN[M_0427]='Add user "%s" to the sudo group? [Y/n]: '
MSG_RU[M_0428]='Пользователь "%s" успешно добавлен в группу sudo (visudo -c: OK).\n'
MSG_EN[M_0428]='User "%s" successfully added to the sudo group (visudo -c: OK).\n'
MSG_RU[M_0429]='ОШИБКА: Группа sudo отсутствует в системе. Сначала установите пакет sudo.\n'
MSG_EN[M_0429]='ERROR: Group sudo does not exist on this system. Install the sudo package first.\n'
MSG_RU[M_0430]='ОШИБКА: Проверка visudo -c не пройдена — правило /etc/sudoers.d/90-smartdns-sudo-group откачено.\n'
MSG_EN[M_0430]='ERROR: visudo -c validation failed — /etc/sudoers.d/90-smartdns-sudo-group rolled back.\n'
MSG_RU[M_0431]='Не указан административный пользователь для добавления в sudo. Введите имя существующего пользователя (Enter — пропустить): '
MSG_EN[M_0431]='No admin user selected for sudo. Enter an existing username (Enter to skip): '
MSG_RU[M_0432]='ОШИБКА: Пользователь "%s" не найден в системе.\n'
MSG_EN[M_0432]='ERROR: User "%s" was not found on this system.\n'
MSG_RU[M_0433]='Создан backup конфигурации SSH в %s (файлов: %s).'
MSG_EN[M_0433]='SSH configuration backup created in %s (files: %s).'
MSG_RU[M_0434]='ОШИБКА: Не удалось создать резервную копию конфигурации SSH. Изменения отменены.'
MSG_EN[M_0434]='ERROR: Failed to back up SSH configuration. Changes aborted.'
MSG_RU[M_0435]='ОШИБКА проверки конфигурации SSH (%s). Выполняется автоматический откат из %s...'
MSG_EN[M_0435]='SSH configuration validation failed (%s). Rolling back from %s...'
MSG_RU[M_0436]='Откат конфигурации SSH из %s завершён успешно (sshd -t: OK).'
MSG_EN[M_0436]='SSH configuration rollback from %s completed successfully (sshd -t: OK).'
MSG_RU[M_0437]='Конфигурация SSH проверена (sshd -t / sshd -T) и безопасно применена без разрыва текущей сессии.'
MSG_EN[M_0437]='SSH configuration validated (sshd -t / sshd -T) and applied safely without dropping the current session.'
MSG_RU[M_0438]='ПРЕДУПРЕЖДЕНИЕ: В /etc/ssh/sshd_config* обнаружены блоки Match. Итоговые параметры будут проверены через sshd -T -C.'
MSG_EN[M_0438]='WARNING: Match blocks detected in /etc/ssh/sshd_config*. Effective parameters will be verified via sshd -T -C.'
MSG_RU[M_0439]='\n--- [5] АУДИТ И БАЗОВАЯ НАСТРОЙКА SSH ---\n'
MSG_EN[M_0439]='\n--- [5] SSH AUDIT AND BASE CONFIGURATION ---\n'
MSG_RU[M_0440]='Пакет openssh-server (sshd) не установлен в системе.\n'
MSG_EN[M_0440]='Package openssh-server (sshd) is not installed on this system.\n'
MSG_RU[M_0441]='Установить openssh-server через apt-get (без перезагрузки)? [Y/n]: '
MSG_EN[M_0441]='Install openssh-server via apt-get (no reboot)? [Y/n]: '
MSG_RU[M_0442]='Текущее состояние SSH:\n  - Служба / Socket     : %s (socket activation: %s)\n  - Активные порты      : %s\n  - PubkeyAuthentication: %s\n  - PasswordAuth        : %s\n  - PermitRootLogin     : %s\n  - AuthorizedKeysFile  : %s\n  - Файлы sshd_config.d : %s\n'
MSG_EN[M_0442]='Current SSH state:\n  - Service / Socket    : %s (socket activation: %s)\n  - Active ports        : %s\n  - PubkeyAuthentication: %s\n  - PasswordAuth        : %s\n  - PermitRootLogin     : %s\n  - AuthorizedKeysFile  : %s\n  - sshd_config.d files : %s\n'
MSG_RU[M_0443]='Включить PubkeyAuthentication yes в конфигурации SSH сейчас? [Y/n]: '
MSG_EN[M_0443]='Enable PubkeyAuthentication yes in SSH configuration now? [Y/n]: '
MSG_RU[M_0444]='\n--- [7] НАСТРОЙКА SSH KEY AUTHENTICATION ---\n'
MSG_EN[M_0444]='\n--- [7] SSH KEY AUTHENTICATION SETUP ---\n'
MSG_RU[M_0445]='Настройка SSH-ключей для пользователя: %s (домашний каталог: %s)\n'
MSG_EN[M_0445]='Configuring SSH keys for user: %s (home directory: %s)\n'
MSG_RU[M_0446]='ВНИМАНИЕ: Отдельный административный пользователь не создан; ключи будут настраиваться для root.\n'
MSG_EN[M_0446]='WARNING: No separate admin user configured; keys will be configured for root.\n'
MSG_RU[M_0447]='\nГде создать SSH key?\n  [1] На локальном компьютере (рекомендуется — вставить публичный ключ)\n  [2] Сгенерировать на сервере (Ed25519 / RSA 4096)\n  [3] Использовать существующий ключ в системе\n  [4] Пропустить\n\nВаш выбор [1]: '
MSG_EN[M_0447]='\nWhere should the SSH key be created?\n  [1] On your local computer (recommended — paste public key)\n  [2] Generate on this server (Ed25519 / RSA 4096)\n  [3] Use an existing key on the system\n  [4] Skip\n\nYour choice [1]: '
MSG_RU[M_0448]='Вставьте строку публичного SSH-ключа (ssh-ed25519 / ssh-rsa / ecdsa-sha2-..., Enter — отмена): '
MSG_EN[M_0448]='Paste your SSH public key line (ssh-ed25519 / ssh-rsa / ecdsa-sha2-..., Enter to cancel): '
MSG_RU[M_0449]='ОШИБКА: Переданная строка не является валидным публичным SSH-ключом (проверка ssh-keygen -lf не пройдена).\n'
MSG_EN[M_0449]='ERROR: Provided line is not a valid SSH public key (ssh-keygen -lf validation failed).\n'
MSG_RU[M_0450]='Этот публичный ключ уже присутствует в %s (дубликат не добавлен).\n'
MSG_EN[M_0450]='This public key already exists in %s (duplicate skipped).\n'
MSG_RU[M_0451]='Публичный SSH-ключ проверен и добавлен в %s (%s).\n'
MSG_EN[M_0451]='SSH public key validated and added to %s (%s).\n'
MSG_RU[M_0452]='Выберите тип ключа:\n  [1] Ed25519 (рекомендуется)\n  [2] RSA 4096\nВаш выбор [1]: '
MSG_EN[M_0452]='Select key type:\n  [1] Ed25519 (recommended)\n  [2] RSA 4096\nYour choice [1]: '
MSG_RU[M_0453]='Введите имя файла ключа (по умолчанию %s): '
MSG_EN[M_0453]='Enter key filename (default %s): '
MSG_RU[M_0454]='ОШИБКА: Имя файла ключа должно содержать только латинские буквы, цифры, точки, _ и -.\n'
MSG_EN[M_0454]='ERROR: Key filename must contain only Latin letters, digits, dots, _, and -.\n'
MSG_RU[M_0455]='Файл ключа %s уже существует. Перезаписать его? [y/N]: '
MSG_EN[M_0455]='Key file %s already exists. Overwrite it? [y/N]: '
MSG_RU[M_0456]='Генерация ключа на сервере (рекомендуется задать надёжную passphrase; приватный ключ не отображается и не пишется в лог)...\n'
MSG_EN[M_0456]='Generating key on server (a strong passphrase is recommended; private key is never printed or logged)...\n'
MSG_RU[M_0457]='ОШИБКА: Генерация SSH-ключа завершилась неудачей.\n'
MSG_EN[M_0457]='ERROR: SSH key generation failed.\n'
MSG_RU[M_0458]='Найдено валидных ключей в %s: %s.\n'
MSG_EN[M_0458]='Valid keys found in %s: %s.\n'
MSG_RU[M_0459]='В /root/.ssh/authorized_keys найдено ключей: %s. Скопировать их в %s без перезаписи существующих? [Y/n]: '
MSG_EN[M_0459]='Found %s key(s) in /root/.ssh/authorized_keys. Append them to %s without overwriting existing keys? [Y/n]: '
MSG_RU[M_0460]='Действующие публичные ключи не найдены в %s. Сначала добавьте или сгенерируйте ключ.\n'
MSG_EN[M_0460]='No valid public keys found in %s. Please add or generate a key first.\n'
MSG_RU[M_0461]='\nВАЖНО: Проверьте вход по SSH-ключу в ОТДЕЛЬНОМ терминале на вашем компьютере:\n  ssh -p %s %s@%s\nПодтверждаете, что вход по SSH-ключу успешно работает? [y/N]: '
MSG_EN[M_0461]='\nIMPORTANT: Test SSH key login in a SEPARATE terminal on your local machine:\n  ssh -p %s %s@%s\nDo you confirm that SSH key authentication works? [y/N]: '
MSG_RU[M_0462]='Статус SSH key authentication: ПОДТВЕРЖДЁН пользователем.\n'
MSG_EN[M_0462]='SSH key authentication status: CONFIRMED by user.\n'
MSG_RU[M_0463]='Вход по ключу пока НЕ подтверждён. Отключение PasswordAuthentication и Root Login будет заблокировано до подтверждения.\n'
MSG_EN[M_0463]='Key login NOT confirmed yet. Disabling PasswordAuthentication and Root Login will remain blocked until confirmed.\n'
MSG_RU[M_0464]='\n--- [6] НАСТРОЙКА SSH PORT ---\n'
MSG_EN[M_0464]='\n--- [6] SSH PORT CONFIGURATION ---\n'
MSG_RU[M_0465]='Текущий SSH port: %s\n'
MSG_EN[M_0465]='Current SSH port: %s\n'
MSG_RU[M_0466]='Изменить SSH port? [y/N]: '
MSG_EN[M_0466]='Change SSH port? [y/N]: '
MSG_RU[M_0467]='Введите новый SSH port (1024-65535, Enter — отмена): '
MSG_EN[M_0467]='Enter new SSH port (1024-65535, Enter to cancel): '
MSG_RU[M_0468]='ОШИБКА: Порт должен быть целым числом в диапазоне 1024..65535.\n'
MSG_EN[M_0468]='ERROR: Port must be an integer in range 1024..65535.\n'
MSG_RU[M_0469]='ОШИБКА: Порт %s зарезервирован для компонентов SmartDNS/Xray/Nginx. Выберите другой порт.\n'
MSG_EN[M_0469]='ERROR: Port %s is reserved for SmartDNS/Xray/Nginx components. Choose another port.\n'
MSG_RU[M_0470]='ОШИБКА: Порт %s уже занят другим процессом в системе.\n'
MSG_EN[M_0470]='ERROR: Port %s is already in use by another process on this system.\n'
MSG_RU[M_0471]='Порт %s совпадает с текущим SSH-портом. Изменение не требуется.\n'
MSG_EN[M_0471]='Port %s is already the current SSH port. No change required.\n'
MSG_RU[M_0472]='\nВНИМАНИЕ: Firewall (UFW/iptables) на данном этапе НЕ включается — выбранный порт %s будет автоматически передан в основную фазу установки и разрешён до включения блокирующих правил.\nСначала SSH будет временно слушать ОБА порта (%s и %s), чтобы вы безопасно проверили новое подключение.\nПрименить временную конфигурацию с двумя портами? [Y/n]: '
MSG_EN[M_0472]='\nNOTICE: Firewall (UFW/iptables) is NOT enabled at this stage — port %s will be passed to the main installation phase and allowed before blocking rules.\nSSH will temporarily listen on BOTH ports (%s and %s) so you can safely test the new connection.\nApply temporary dual-port configuration? [Y/n]: '
MSG_RU[M_0473]='\nSSH теперь слушает порты %s и %s. Откройте ВТОРОЙ терминал и проверьте вход:\n  ssh -p %s %s@%s\nПодтверждаете, что подключение на новый порт %s успешно работает? [y/N]: '
MSG_EN[M_0473]='\nSSH is now listening on ports %s and %s. Open a SECOND terminal and test login:\n  ssh -p %s %s@%s\nDo you confirm that login on the new port %s works? [y/N]: '
MSG_RU[M_0474]='Отключить старый SSH port %s и оставить только порт %s? [y/N]: '
MSG_EN[M_0474]='Disable the old SSH port %s and keep only port %s? [y/N]: '
MSG_RU[M_0475]='Новый SSH port %s успешно применён (старый порт %s отключён).\n'
MSG_EN[M_0475]='New SSH port %s applied successfully (old port %s disabled).\n'
MSG_RU[M_0476]='ВНИМАНИЕ: Новый порт %s не подтверждён. Выполнить откат к исходному порту %s? [Y/n]: '
MSG_EN[M_0476]='WARNING: New port %s was not confirmed. Roll back to original port %s? [Y/n]: '
MSG_RU[M_0477]='Старый порт %s оставлен активным вместе с %s для безопасности доступа.\n'
MSG_EN[M_0477]='Old port %s remains active alongside %s to protect access.\n'
MSG_RU[M_0478]='\n--- [8] ОТКЛЮЧЕНИЕ PASSWORDAUTHENTICATION ---\n'
MSG_EN[M_0478]='\n--- [8] DISABLE PASSWORDAUTHENTICATION ---\n'
MSG_RU[M_0479]='PasswordAuthentication уже отключён (sshd -T: passwordauthentication no).\n'
MSG_EN[M_0479]='PasswordAuthentication is already disabled (sshd -T: passwordauthentication no).\n'
MSG_RU[M_0480]='ЗАБЛОКИРОВАНО: Нельзя отключить PasswordAuthentication — %s.\n'
MSG_EN[M_0480]='BLOCKED: Cannot disable PasswordAuthentication — %s.\n'
MSG_RU[M_0481]='ВНИМАНИЕ: Отключение входа по паролю сделает невозможным вход без валидного SSH-ключа.\nОтключить PasswordAuthentication и KbdInteractiveAuthentication? [y/N]: '
MSG_EN[M_0481]='WARNING: Disabling password login will prevent login without a valid SSH key.\nDisable PasswordAuthentication and KbdInteractiveAuthentication? [y/N]: '
MSG_RU[M_0482]='PasswordAuthentication успешно отключён и подтверждён через sshd -T.\n'
MSG_EN[M_0482]='PasswordAuthentication successfully disabled and verified via sshd -T.\n'
MSG_RU[M_0483]='\n--- [9] ОТКЛЮЧЕНИЕ ROOT LOGIN ПО SSH ---\n'
MSG_EN[M_0483]='\n--- [9] DISABLE SSH ROOT LOGIN ---\n'
MSG_RU[M_0484]='PermitRootLogin уже отключён (sshd -T: permitrootlogin no).\n'
MSG_EN[M_0484]='PermitRootLogin is already disabled (sshd -T: permitrootlogin no).\n'
MSG_RU[M_0485]='ЗАБЛОКИРОВАНО: Нельзя отключить SSH Root Login — %s.\n'
MSG_EN[M_0485]='BLOCKED: Cannot disable SSH Root Login — %s.\n'
MSG_RU[M_0486]='Отключить SSH login под root (PermitRootLogin no)?\nРекомендуется использовать отдельного пользователя "%s" с sudo (учётная запись root не блокируется).\nПодтверждаете? [y/N]: '
MSG_EN[M_0486]='Disable SSH root login (PermitRootLogin no)?\nRecommended when using separate sudo user "%s" (the root OS account itself is NOT locked).\nConfirm? [y/N]: '
MSG_RU[M_0487]='PermitRootLogin no успешно применён и подтверждён через sshd -T (учётная запись root сохранена).\n'
MSG_EN[M_0487]='PermitRootLogin no applied and verified via sshd -T (local root account preserved).\n'
MSG_RU[M_0488]='ОШИБКА: Эффективное значение sshd -T для %s не совпало (ожидалось: %s, получено: %s).'
MSG_EN[M_0488]='ERROR: Effective sshd -T value for %s mismatch (expected: %s, got: %s).'
MSG_RU[M_0489]='\n--- [10] ДОПОЛНИТЕЛЬНЫЕ МЕРЫ БЕЗОПАСНОСТИ (ДИАГНОСТИКА И ОПЦИИ) ---\n'
MSG_EN[M_0489]='\n--- [10] ADDITIONAL SECURITY MEASURES (DIAGNOSTICS & OPTIONS) ---\n'
MSG_RU[M_0490]='\nВыберите дополнительную меру (ничего не применяется автоматически):\n  [1] Установить и настроить Fail2ban (защита SSH от brute-force, backend=systemd)\n  [2] Включить автоматические security-обновления (unattended-upgrades, без auto-reboot)\n  [3] Усилить криптографические алгоритмы SSH (KexAlgorithms / Ciphers / MACs)\n  [4] Исправить права доступа ~/.ssh (0700) и authorized_keys (0600)\n  [5] Включить синхронизацию системного времени (NTP / timedatectl)\n  [6] Создать swap-файл 1 ГБ (рекомендуется при RAM < 2 ГБ)\n  [0] Завершить и вернуться в меню Initial Server Setup\n\nВаш выбор [0]: '
MSG_EN[M_0490]='\nSelect an optional security measure (nothing is applied automatically):\n  [1] Install & configure Fail2ban (SSH brute-force protection, backend=systemd)\n  [2] Enable automatic security updates (unattended-upgrades, no auto-reboot)\n  [3] Harden SSH cryptographic algorithms (KexAlgorithms / Ciphers / MACs)\n  [4] Fix ~/.ssh (0700) and authorized_keys (0600) permissions\n  [5] Enable system time synchronization (NTP / timedatectl)\n  [6] Create a 1 GB swap file (recommended when RAM < 2 GB)\n  [0] Finish and return to Initial Server Setup menu\n\nYour choice [0]: '
MSG_RU[M_0491]='Fail2ban защищает только SSH-порт (%s) через journald и не конфликтует с Xray/Nginx/OxiDNS.\nУстановить и включить fail2ban? [y/N]: '
MSG_EN[M_0491]='Fail2ban protects only the SSH port (%s) via journald and does not conflict with Xray/Nginx/OxiDNS.\nInstall and enable fail2ban? [y/N]: '
MSG_RU[M_0492]='Fail2ban успешно настроен для порта SSH %s и запущен.\n'
MSG_EN[M_0492]='Fail2ban successfully configured for SSH port %s and started.\n'
MSG_RU[M_0493]='unattended-upgrades устанавливает только security-обновления со строгим запретом автоматической перезагрузки (Automatic-Reboot=false).\nУстановить и настроить unattended-upgrades? [y/N]: '
MSG_EN[M_0493]='unattended-upgrades installs security updates only with Automatic-Reboot=false strictly enforced.\nInstall and configure unattended-upgrades? [y/N]: '
MSG_RU[M_0494]='unattended-upgrades успешно настроен (Automatic-Reboot "false").\n'
MSG_EN[M_0494]='unattended-upgrades configured successfully (Automatic-Reboot "false").\n'
MSG_RU[M_0495]='Усиление криптографии SSH ограничивает KEX/Ciphers/MACs современными алгоритмами (совместимо с OpenSSH 8.x+, PuTTY 0.78+, macOS/Linux).\nПрименить современные криптографические настройки SSH? [y/N]: '
MSG_EN[M_0495]='SSH crypto hardening restricts KEX/Ciphers/MACs to modern algorithms (compatible with OpenSSH 8.x+, PuTTY 0.78+, macOS/Linux).\nApply modern SSH cryptographic settings? [y/N]: '
MSG_RU[M_0496]='Права доступа к каталогам и файлам SSH проверены и приведены к безопасным значениям (0700 / 0600).\n'
MSG_EN[M_0496]='SSH directory and file permissions checked and set to secure modes (0700 / 0600).\n'
MSG_RU[M_0497]='Синхронизация времени NTP включена (timedatectl set-ntp true).\n'
MSG_EN[M_0497]='NTP time synchronization enabled (timedatectl set-ntp true).\n'
MSG_RU[M_0498]='Swap уже активен (%s МБ) или недостаточно места на диске для создания swap-файла.\n'
MSG_EN[M_0498]='Swap is already active (%s MB) or insufficient free disk space to create a swap file.\n'
MSG_RU[M_0499]='Создать swap-файл /swapfile размером 1024 МБ (без перезагрузки)? [y/N]: '
MSG_EN[M_0499]='Create a 1024 MB /swapfile (without rebooting)? [y/N]: '
MSG_RU[M_0500]='Swap-файл /swapfile (1024 МБ) успешно создан, активирован и добавлен в /etc/fstab.\n'
MSG_EN[M_0500]='Swap file /swapfile (1024 MB) created, activated, and added to /etc/fstab.\n'
MSG_RU[M_0501]='\nВыберите действие:\n  [ A ] Выполнить рекомендуемую настройку (пошагово с подтверждением)\n  [ S ] Пропустить первоначальную настройку и перейти далее\n  [ C ] Настроить выборочно (отдельные пункты 1..10)\n  [ Q ] Выход (отмена)\n\nВаш выбор [A]: '
MSG_EN[M_0501]='\nSelect an action:\n  [ A ] Run recommended setup (step-by-step with confirmation)\n  [ S ] Skip initial setup and proceed\n  [ C ] Customize selectively (individual items 1..10)\n  [ Q ] Quit (cancel)\n\nYour choice [A]: '
MSG_RU[M_0502]='\nОбнаружена ранее выполненная первоначальная настройка сервера (%s).\nПовторное создание пользователя, перезапись ключей и обновление ОС без согласия НЕ выполняются.\n  [ S ] Сохранить текущие настройки и продолжить\n  [ C ] Проверить или изменить отдельные параметры\n  [ Q ] Выход\n\nВаш выбор [S]: '
MSG_EN[M_0502]='\nPreviously completed Initial Server Setup detected (%s).\nUser creation, key overwrite, and OS upgrades will NOT be re-run without consent.\n  [ S ] Keep existing settings and continue\n  [ C ] Inspect or modify specific settings\n  [ Q ] Quit\n\nYour choice [S]: '
MSG_RU[M_0503]='Введите номер пункта [1-10], [D] — завершить и продолжить, [Q] — выход: '
MSG_EN[M_0503]='Enter item number [1-10], [D] — finish and continue, [Q] — quit: '
MSG_RU[M_0504]='\n[Шаг %s/10 — Пункт [%s]: %s]\nНавигация: [Enter] — выполнить/настроить, [S] — пропустить, [B] — назад, [Q] — отмена: '
MSG_EN[M_0504]='\n[Step %s/10 — Item [%s]: %s]\nNavigation: [Enter] — run/configure, [S] — skip, [B] — back, [Q] — cancel: '
MSG_RU[M_0505]='Первоначальная настройка сервера завершена; параметры сохранены в %s.\n'
MSG_EN[M_0505]='Initial server setup completed; settings saved to %s.\n'
MSG_RU[M_0506]='Первоначальная настройка пропущена пользователем.\n'
MSG_EN[M_0506]='Initial server setup skipped by user.\n'
MSG_RU[M_0507]='Выход из установщика по запросу пользователя на этапе Initial Server Setup.\n'
MSG_EN[M_0507]='Installer exited by user during Initial Server Setup.\n'
MSG_RU[M_0508]='Разрешён порт SSH %s/tcp в UFW до включения блокирующих правил firewall.'
MSG_EN[M_0508]='Allowed SSH port %s/tcp in UFW prior to enabling blocking firewall rules.'
MSG_RU[M_0509]='ПРЕДУПРЕЖДЕНИЕ: Правило или сокет SSH на порту %s/tcp требует проверки; применено резервное разрешение UFW.'
MSG_EN[M_0509]='WARNING: SSH rule or socket on port %s/tcp needs attention; emergency UFW allow applied.'
MSG_RU[M_0510]='ПРЕДУПРЕЖДЕНИЕ: Fail2ban установлен, но запуск службы сейчас не удался (будет активирован после настройки firewall в основной фазе).\n'
MSG_EN[M_0510]='WARNING: Fail2ban was installed, but starting the service failed now (it can start once firewall packages are installed in the main phase).\n'
MSG_RU[M_0511]='Выберите пункт [1/2/0]: '
MSG_EN[M_0511]='Select an option [1/2/0]: '
MSG_RU[M_0512]='Некорректный выбор. Введите 1, 2 или 0.\n'
MSG_EN[M_0512]='Invalid choice. Enter 1, 2, or 0.\n'
MSG_RU[M_0513]='Выход из установщика.\n'
MSG_EN[M_0513]='Exiting installer.\n'
MSG_RU[M_0511]='Выберите пункт [0-15]: '
MSG_EN[M_0511]='Select an option [0-15]: '
MSG_RU[M_0512]='Некорректный выбор. Введите число от 0 до 15.\n'
MSG_EN[M_0512]='Invalid choice. Enter a number from 0 to 15.\n'
MSG_RU[M_0514]='\nНажмите Enter для возврата в главное меню...'
MSG_EN[M_0514]='\nPress Enter to return to the main menu...'
MSG_RU[M_0515]='\nОперация завершилась с кодом возврата: %s.\n'
MSG_EN[M_0515]='\nOperation exited with status code: %s.\n'
MSG_RU[M_0516]='\nПереключение DNS backend:\n  [1] OxiDNS (Rust)\n  [2] AdGuardHome (Go)\n  [0] Назад\nВаш выбор [0]: '
MSG_EN[M_0516]='\nSwitch DNS backend:\n  [1] OxiDNS (Rust)\n  [2] AdGuardHome (Go)\n  [0] Back\nYour choice [0]: '
MSG_RU[M_0517]='\nУправление DoT IP-whitelist:\n  [1] Включить DoT IP-whitelist\n  [2] Отключить DoT IP-whitelist\n  [3] Режим shared (общий ipset для DoH и DoT)\n  [4] Режим separate (отдельный ipset для DoT)\n  [0] Назад\nВаш выбор [0]: '
MSG_EN[M_0517]='\nDoT IP-whitelist management:\n  [1] Enable DoT IP-whitelist\n  [2] Disable DoT IP-whitelist\n  [3] Mode: shared (shared ipset for DoH & DoT)\n  [4] Mode: separate (dedicated ipset for DoT)\n  [0] Back\nYour choice [0]: '
MSG_RU[M_0518]='Введите путь к резервной копии (Enter — откат к последней, 0 — отмена): '
MSG_EN[M_0518]='Enter backup path (Enter for latest backup, 0 to cancel): '
MSG_RU[M_0519]='Доступные резервные копии в /var/lib/oxidns-installer/backups:\n'
MSG_EN[M_0519]='Available backups in /var/lib/oxidns-installer/backups:\n'
MSG_RU[M_0511]='Выберите пункт [0-16]: '
MSG_EN[M_0511]='Select an option [0-16]: '
MSG_RU[M_0512]='Некорректный выбор. Введите число от 0 до 16.\n'
MSG_EN[M_0512]='Invalid choice. Enter a number from 0 to 16.\n'
MSG_EN[HN_00]='Provider hostname for DoH and DoT: %s\n'
MSG_RU[HN_00]='Имя хоста провайдера для DoH и DoT: %s\n'
MSG_EN[HN_01]='TLS uses the existing Certbot certificate. No Cloudflare account or DNS API token is needed.\n'
MSG_RU[HN_01]='TLS использует существующий сертификат Certbot. Аккаунт Cloudflare и токен DNS API не требуются.\n'
MSG_EN[HN_02]='DoT IP authorization is enabled by default (shared with DoH).\n'
MSG_RU[HN_02]='Для DoT по умолчанию включена авторизация IP (общая с DoH).\n'
MSG_EN[HN_03]='DoT requires IP authorization through the secret DoH or Web-Auth URL.\n'
MSG_RU[HN_03]='Для DoT сначала авторизуйте IP через секретный URL DoH или Web-Auth.\n'
MSG_EN[HN_04]='ERROR: An existing installation uses %s; changing its hostname requires a separate migration.\n'
MSG_RU[HN_04]='ОШИБКА: Существующая установка использует %s; смена имени хоста требует отдельной миграции.\n'
MSG_EN[HN_05]='ERROR: Set PROVIDER_HOSTNAME and PUBLIC_IPV4 environment variables, or run interactively to enter them.\n'
MSG_RU[HN_05]='ОШИБКА: Задайте переменные окружения PROVIDER_HOSTNAME и PUBLIC_IPV4 или запустите интерактивно.\n'
MSG_EN[HN_06]='ERROR: Invalid PROVIDER_HOSTNAME syntax.\n'
MSG_RU[HN_06]='ОШИБКА: Недопустимое значение PROVIDER_HOSTNAME.\n'
MSG_EN[HN_07]='ERROR: Invalid PUBLIC_IPV4 address.\n'
MSG_RU[HN_07]='ОШИБКА: Недопустимый адрес PUBLIC_IPV4.\n'
MSG_EN[HN_08]='ERROR: Invalid PUBLIC_IPV6 address.\n'
MSG_RU[HN_08]='ОШИБКА: Недопустимый адрес PUBLIC_IPV6.\n'
MSG_EN[HN_09]='ERROR: Path "%s" must be an absolute path without "..", whitespace, or unsafe characters.\n'
MSG_RU[HN_09]='ОШИБКА: Путь "%s" должен быть абсолютным и не содержать "..", пробелов или небезопасных символов.\n'
MSG_EN[HN_10]='ERROR: Provider Hostname Profile requires ROOT_DOMAIN and DOT_HOST to equal %s.\n'
MSG_RU[HN_10]='ОШИБКА: Для Provider Hostname Profile ROOT_DOMAIN и DOT_HOST должны равняться %s.\n'
MSG_EN[HN_11]='ERROR: Provider DNS must resolve %s exclusively to %s (resolver %s, got: %s). Contact your DNS/VPS provider.\n'
MSG_RU[HN_11]='ОШИБКА: DNS провайдера должен разрешать %s только в %s (резолвер %s, получено: %s). Обратитесь к DNS/VPS-провайдеру.\n'
MSG_EN[HN_12]='ERROR: Provider AAAA record (%s) does not match configured PUBLIC_IPV6 (%s) on resolver %s.\n'
MSG_RU[HN_12]='ОШИБКА: Запись AAAA провайдера (%s) не совпадает с заданным PUBLIC_IPV6 (%s) на резолвере %s.\n'
MSG_EN[HN_13]='Provider DNS verified; no Cloudflare account or API token is used.\n'
MSG_RU[HN_13]='DNS провайдера проверен; учётная запись Cloudflare и токен API не используются.\n'
MSG_EN[HN_14]='ERROR: Certificate and private key do not match.\n'
MSG_RU[HN_14]='ОШИБКА: Сертификат и закрытый ключ не совпадают.\n'
MSG_EN[HN_15]='Certificate, private key, trust chain, and Certbot webroot renewal configuration verified.\n'
MSG_RU[HN_15]='Сертификат, закрытый ключ, цепочка доверия и настройки продления Certbot webroot проверены.\n'
MSG_EN[HN_16]='DoH/DoT hostname: %s\n'
MSG_RU[HN_16]='Имя хоста DoH/DoT: %s\n'
MSG_EN[HN_17]='Installation stopped: port %s is occupied by an existing service (%s). Plan a migration before installing.\n'
MSG_RU[HN_17]='Установка остановлена: порт %s занят существующей службой (%s). Перед установкой спланируйте миграцию.\n'
MSG_EN[HN_18]='Installation stopped: active service "%s" detected. Plan a migration before installing.\n'
MSG_RU[HN_18]='Установка остановлена: обнаружена активная служба "%s". Перед установкой спланируйте миграцию.\n'
MSG_EN[HN_19]='Existing single-host Certbot certificate deployed; lineage-specific Certbot deploy hook installed.\n'
MSG_RU[HN_19]='Существующий сертификат одного хоста Certbot применён; установлен deploy-хук для конкретного lineage.\n'
MSG_EN[HN_20]='ERROR: Provider Hostname Profile is fixed to the configured hostname. Changing hostname requires a separate migration.\n'
MSG_RU[HN_20]='ОШИБКА: Provider Hostname Profile привязан к заданному имени хоста. Смена имени хоста требует отдельной миграции.\n'
MSG_EN[HN_21]='\nProvider Hostname Profile (without Cloudflare — env variables or interactive input):\n'
MSG_RU[HN_21]='\nProvider Hostname Profile (без Cloudflare — переменные окружения или интерактивный ввод):\n'
MSG_EN[HN_22]='  Required: PROVIDER_HOSTNAME, PUBLIC_IPV4. Optional: PUBLIC_IPV6.\n'
MSG_RU[HN_22]='  Обязательные: PROVIDER_HOSTNAME, PUBLIC_IPV4. Необязательная: PUBLIC_IPV6.\n'
MSG_EN[HN_23]='  Optional paths: HOSTNAME_CERT_LINEAGE, HOSTNAME_ACME_WEBROOT, HOSTNAME_RENEWAL_CONF.\n'
MSG_RU[HN_23]='  Необязательные пути: HOSTNAME_CERT_LINEAGE, HOSTNAME_ACME_WEBROOT, HOSTNAME_RENEWAL_CONF.\n'
MSG_EN[HN_24]='  No Cloudflare account, DNS API token, or wildcard certificate is used.\n'
MSG_RU[HN_24]='  Учётная запись Cloudflare, токен DNS API и wildcard-сертификат не используются.\n'
MSG_EN[HN_25]='  --hostname-check    Read-only DNS, certificate, webroot, renewal, and port check\n'
MSG_RU[HN_25]='  --hostname-check    Проверка DNS, сертификата, webroot, renewal и портов без изменений\n'
MSG_EN[HN_HOST]='Provider hostname (e.g. dns.example.net): '
MSG_RU[HN_HOST]='Имя хоста провайдера (например dns.example.net): '
MSG_EN[HN_IPV4]='Public VPS IPv4: '
MSG_RU[HN_IPV4]='Публичный IPv4 VPS: '
MSG_EN[HN_IPV6]='Public VPS IPv6 (optional, press Enter to skip): '
MSG_RU[HN_IPV6]='Публичный IPv6 VPS (необязательно, Enter — пропустить): '
MSG_EN[HN_PROFILE_MENU]='\nSelect installation profile:\n  [1] Cloudflare DNS-01 (wildcard certificate via acme.sh — default)\n  [2] Provider Hostname Profile (without Cloudflare, existing Certbot HTTP-01 certificate)\nProfile choice [1]: '
MSG_RU[HN_PROFILE_MENU]='\nВыберите профиль установки:\n  [1] Cloudflare DNS-01 (wildcard-сертификат через acme.sh — по умолчанию)\n  [2] Provider Hostname Profile (без Cloudflare, существующий сертификат Certbot HTTP-01)\nВыбор профиля [1]: '
MSG_EN[HN_PROFILE_BAD]='Invalid profile "%s". Allowed values: cloudflare, hostname.\n'
MSG_RU[HN_PROFILE_BAD]='Недопустимый профиль "%s". Допустимые значения: cloudflare, hostname.\n'
MSG_EN[HN_SETTINGS_CORRUPT]='ERROR: Saved settings file %s is corrupted or unreadable.\n'
MSG_RU[HN_SETTINGS_CORRUPT]='ОШИБКА: Сохранённый файл настроек %s повреждён или недоступен для чтения.\n'
MSG_EN[HN_CHECK_BANNER]='         PROVIDER HOSTNAME PROFILE CHECK (READ-ONLY)                          \n'
MSG_RU[HN_CHECK_BANNER]='         ПРОВЕРКА PROVIDER HOSTNAME PROFILE (ТОЛЬКО ЧТЕНИЕ)                   \n'
MSG_EN[HN_CHECK_FAIL]='HOSTNAME CHECK FAILED: critical issues=%d, warnings=%d. Full installation blocked until critical issues are resolved.\n'
MSG_RU[HN_CHECK_FAIL]='ПРОВЕРКА НЕ ПРОЙДЕНА: критических ошибок=%d, предупреждений=%d. Полная установка заблокирована до устранения критических проблем.\n'
MSG_EN[HN_CHECK_PASS]='HOSTNAME CHECK PASSED: critical issues=0, warnings=%d. Safe to proceed.\n'
MSG_RU[HN_CHECK_PASS]='ПРОВЕРКА ПРОЙДЕНА: критических ошибок=0, предупреждений=%d. Можно безопасно продолжать.\n'
MSG_EN[HN_TEST_RENEW]='Provider Hostname TLS renewal (Certbot deploy hook + HTTP-01 route) is configured'
MSG_RU[HN_TEST_RENEW]='Автопродление TLS Provider Hostname (deploy-хук Certbot + маршрут HTTP-01) настроено'


select_interface_language() {
    if [[ "${SCRIPT_LANG:-}" != "ru" && "${SCRIPT_LANG:-}" != "en" ]]; then
        SCRIPT_LANG="ru"
    fi

    if [[ ! -t 0 ]]; then
        export SCRIPT_LANG
        LANGUAGE_SELECTED=1
        return 0
    fi

    if [[ "${LANGUAGE_SELECTED:-0}" == "1" ]]; then
        export SCRIPT_LANG
        return 0
    fi

    local choice=""
    while true; do
        printf '\nВыберите язык интерфейса / Select interface language:\n\n'
        printf '1) Русский (по умолчанию)\n'
        printf '2) English\n\n'
        printf 'Ваш выбор / Your choice [1]: '

        if ! IFS= read -r choice; then
            printf '\n'
            SCRIPT_LANG="ru"
            export SCRIPT_LANG
            return 0
        fi

        choice="${choice//$'\r'/}"
        choice="${choice#"${choice%%[![:space:]]*}"}"
        choice="${choice%"${choice##*[![:space:]]}"}"

        case "${choice}" in
            ""|"1")
                SCRIPT_LANG="ru"
                export SCRIPT_LANG
                LANGUAGE_SELECTED=1
                return 0
                ;;
            "2")
                SCRIPT_LANG="en"
                export SCRIPT_LANG
                LANGUAGE_SELECTED=1
                return 0
                ;;
            *)
                printf 'Ошибка: введите 1, 2 или нажмите Enter / Error: enter 1, 2, or press Enter.\n'
                ;;
        esac
    done
}

tr_msg() {
    local __i18n_key="$1"
    shift || true
    local __i18n_tpl=""
    if [[ "${SCRIPT_LANG:-ru}" == "en" && -n "${MSG_EN[${__i18n_key}]+x}" ]]; then
        __i18n_tpl="${MSG_EN[${__i18n_key}]}"
    elif [[ -n "${MSG_RU[${__i18n_key}]+x}" ]]; then
        __i18n_tpl="${MSG_RU[${__i18n_key}]}"
    else
        __i18n_tpl="${__i18n_key}"
    fi
    if [[ "$#" -gt 0 ]]; then
        # shellcheck disable=SC2059
        printf -- "${__i18n_tpl}" "$@"
    else
        printf '%s' "${__i18n_tpl}"
    fi
}

printf_tr() {
    local __i18n_key="$1"
    shift || true
    local __i18n_fmt=""
    if [[ "${SCRIPT_LANG:-ru}" == "en" && -n "${MSG_EN[${__i18n_key}]+x}" ]]; then
        __i18n_fmt="${MSG_EN[${__i18n_key}]}"
    elif [[ -n "${MSG_RU[${__i18n_key}]+x}" ]]; then
        __i18n_fmt="${MSG_RU[${__i18n_key}]}"
    else
        __i18n_fmt="${__i18n_key}"
    fi
    # shellcheck disable=SC2059
    printf -- "${__i18n_fmt}" "$@"
}

printf_err_tr() {
    printf_tr "$@" >&2
}

log_info_tr() {
    local __i18n_log="$1" __i18n_key="$2"
    shift 2 || true
    log_info "${__i18n_log}" "$(tr_msg "${__i18n_key}" "$@")"
}

log_warn_tr() {
    local __i18n_log="$1" __i18n_key="$2"
    shift 2 || true
    log_warn "${__i18n_log}" "$(tr_msg "${__i18n_key}" "$@")"
}

log_error_tr() {
    local __i18n_log="$1" __i18n_key="$2"
    shift 2 || true
    log_error "${__i18n_log}" "$(tr_msg "${__i18n_key}" "$@")"
}

echo_tr() {
    local __i18n_key="$1"
    shift || true
    printf '%s\n' "$(tr_msg "${__i18n_key}" "$@")"
}

echo_err_tr() {
    local __i18n_key="$1"
    shift || true
    printf '%s\n' "$(tr_msg "${__i18n_key}" "$@")" >&2
}

LAST_READ_EOF=0

read_tr() {
    local __i18n_key="$1" __i18n_var="$2"
    shift 2 || true
    local __i18n_tpl="" __i18n_prompt="" __i18n_ans=""
    if [[ "${SCRIPT_LANG:-ru}" == "en" && -n "${MSG_EN[${__i18n_key}]+x}" ]]; then
        __i18n_tpl="${MSG_EN[${__i18n_key}]}"
    elif [[ -n "${MSG_RU[${__i18n_key}]+x}" ]]; then
        __i18n_tpl="${MSG_RU[${__i18n_key}]}"
    else
        __i18n_tpl="${__i18n_key}"
    fi
    # shellcheck disable=SC2059
    printf -v __i18n_prompt -- "${__i18n_tpl}" "$@"
    LAST_READ_EOF=0
    if ! IFS= read -r -p "${__i18n_prompt}" __i18n_ans; then
        LAST_READ_EOF=1
        printf '\n'
    fi
    __i18n_ans="${__i18n_ans//$'\r'/}"
    printf -v "${__i18n_var}" '%s' "${__i18n_ans}"
}

readonly LOCK_FILE="/run/lock/unified-smartdns-installer.lock"
readonly STATE_DIR="/var/lib/oxidns-installer"
readonly BACKUP_ROOT="${STATE_DIR}/backups"
readonly INITIAL_BACKUP_DIR="${STATE_DIR}/initial-backup"
readonly INITIAL_BACKUP_MANIFEST="${INITIAL_BACKUP_DIR}/backup-manifest.tsv"
readonly INITIAL_BACKUP_SEAL="${INITIAL_BACKUP_DIR}/.sealed"
readonly INSTALL_MANIFEST_FILE="${STATE_DIR}/install-manifest.tsv"
readonly REBOOT_LOCK_FILE="${STATE_DIR}/reboot-lock.env"
readonly INITIAL_SETUP_STATE_FILE="${STATE_DIR}/initial-setup.env"
readonly SSH_BACKUP_ROOT="${STATE_DIR}/ssh-backup"
readonly SETTINGS_FILE="${STATE_DIR}/settings"
readonly VERSIONS_FILE="${STATE_DIR}/versions.env"
readonly SECRETS_FILE="${STATE_DIR}/secrets.env"
readonly IPSET_SAVE_FILE="${STATE_DIR}/ipset-whitelist.save"
readonly DNS_ASSETS_DIR="/var/lib/dns-assets"
readonly ROUTING_VARS_FILE="${DNS_ASSETS_DIR}/xray-routing-vars.env"
readonly GEOHIDE_LIST_FILE="${DNS_ASSETS_DIR}/geohide-domains.txt"
readonly GEOHIDE_HOSTS_FILE="${DNS_ASSETS_DIR}/geohide-hosts.txt"
readonly AGH_RULES_FILE="${DNS_ASSETS_DIR}/ag-smartdns-rules.txt"
readonly CUSTOM_ALLOW_FILE="${DNS_ASSETS_DIR}/custom-allow.txt"
readonly CUSTOM_DENY_FILE="${DNS_ASSETS_DIR}/custom-deny.txt"
readonly DOMAIN_GROUPS_MAP_FILE="${DNS_ASSETS_DIR}/domain-groups.map"
readonly -a DOMAIN_GROUP_IDS=("ai" "microsoft" "dev_cloud" "hardware" "media" "gaming" "tools" "lifestyle" "google_sys" "other")
readonly XRAY_CONF_DIR="/etc/xray/conf.d"
readonly XRAY_RULES_DIR="/etc/xray/rules.d"
readonly XRAY_ROUTING_JSON="${XRAY_RULES_DIR}/10-smartdns-routing.json"
readonly LOG_DIR="/var/log/oxidns-installer"
readonly CERT_DIR="/etc/ssl/smartdns"
readonly CERT_STAGE_DIR="${STATE_DIR}/cert-stage"
readonly WEB_ROOT="/var/www/studio-nord"
LAUNCH_DIR="$(pwd)"
readonly LAUNCH_DIR
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
readonly TIMESTAMP

readonly OXIDNS_REPO="https://github.com/svenshi/oxidns"
readonly OXIDNS_DEFAULT_VER="v1.7.1"
readonly OXIDNS_DEFAULT_URL="https://github.com/svenshi/oxidns/releases/download/v1.7.1/oxidns-x86_64-unknown-linux-musl.tar.gz"
readonly XRAY_DEFAULT_VER="v26.11.9"
GEOHIDE_REPO="https://github.com/Internet-Helper/GeoHideDNS"
readonly GEOHIDE_RAW_URL="https://raw.githubusercontent.com/Internet-Helper/GeoHideDNS/refs/heads/main/hosts/hosts"
readonly GEOSITE_RAW_URL="https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"

# Runtime flags
ACTION_MODE=""
TRANSACTION_ACTIVE=0
CURRENT_BACKUP_DIR=""
DOT_WHITELIST_ENABLED="false"
DOT_WHITELIST_MODE="shared"
REBOOT_LOCKED="true"
SMARTDNS_VERIFIED="false"
REBOOT_ALLOWED="false"
REBOOT_REQUIRED="false"
REBOOT_REASONS=""
INSTALL_PAUSED="false"
INSTALL_PAUSED_STAGE=""
INSTALL_PAUSED_REASON=""
EXTERNAL_REBOOT_TRIGGERS=""
UNSAFE_CONTINUE_REASON=""
INITIAL_SETUP_COMPLETED="false"
INITIAL_SETUP_OS_UPDATED="false"
INITIAL_SETUP_SUDO_OK="false"
INITIAL_SETUP_ROOT_PASS_CHANGED="false"
INITIAL_SETUP_ADMIN_USER=""
INITIAL_SETUP_ADMIN_IN_SUDO="false"
INITIAL_SETUP_SSH_PORT=""
INITIAL_SETUP_SSH_ORIG_PORT=""
INITIAL_SETUP_SSH_KEY_OK="false"
INITIAL_SETUP_SSH_KEY_CONFIRMED="false"
INITIAL_SETUP_PASSAUTH_DISABLED="false"
INITIAL_SETUP_ROOTLOGIN_DISABLED="false"
INITIAL_SETUP_ACTIONS_DONE=""
INITIAL_SETUP_CHECKS_SUMMARY=""
SSH_HARDENING_CONF="/etc/ssh/sshd_config.d/00-smartdns-hardening.conf"
SSH_SOCKET_DROPIN_DIR="/etc/systemd/system/ssh.socket.d"
SSH_SOCKET_DROPIN_FILE="${SSH_SOCKET_DROPIN_DIR}/override.conf"
SSH_SERVICE_NAME="ssh"
SSH_SOCKET_ACTIVE=0
SSH_CURRENT_PORTS="22"
SSH_DESIRED_PORTS=""
SSH_DESIRED_PUBKEY=""
SSH_DESIRED_PASSAUTH=""
SSH_DESIRED_ROOTLOGIN=""
SSH_HARDENING_CRYPTO="false"
SSH_LAST_BACKUP_DIR=""
SKIP_INITIAL_SETUP_IN_INSTALL="${SKIP_INITIAL_SETUP_IN_INSTALL:-0}"
LANGUAGE_SELECTED="${LANGUAGE_SELECTED:-0}"
LAUNCHER_LOCK_ACQUIRED=0
INSTALL_PROFILE="${INSTALL_PROFILE:-}"
DNS_PROVIDER="${DNS_PROVIDER:-}"
TLS_MODE="${TLS_MODE:-}"
HOSTNAME_PROFILE_READY=0
declare -A HOSTNAME_PROFILE=()
SELECTED_DOMAIN_GROUPS="ALL"
PENDING_CUSTOM_DOMAINS_FILE=""
PENDING_CUSTOM_DOMAINS_COUNT=0
INDEXED_GEOHIDE_RAW=""
declare -A DOMAIN_GROUP_COUNTS=()
declare -A DOMAIN_GROUP_SELECTED=()

# ------------------------------ Logging Helpers -------------------------------
init_logging() {
    if [[ "${ACTION_MODE}" == "preflight" || "${ACTION_MODE}" == "help" ]]; then
        return 0
    fi
    mkdir -p "${LOG_DIR}"
    chmod 0750 "${LOG_DIR}"
    for lf in installation.log preflight.log firewall.log dns.log xray.log certificate.log update.log rollback.log; do
        touch "${LOG_DIR}/${lf}"
        chmod 0640 "${LOG_DIR}/${lf}"
    done
}

redact_secrets() {
    local msg="$1"
    if [[ -n "${CF_API_TOKEN:-}" ]]; then
        msg="${msg//${CF_API_TOKEN}/[REDACTED_CF_TOKEN]}"
    fi
    if [[ -n "${DOH_PATH:-}" ]]; then
        msg="${msg//${DOH_PATH}/[REDACTED_DOH_PATH]}"
    fi
    if [[ -n "${AGH_ADMIN_PASS:-}" ]]; then
        msg="${msg//${AGH_ADMIN_PASS}/[REDACTED_PASS]}"
    fi
    printf '%s' "${msg}"
}

log_msg() {
    local level="$1"
    local log_file="$2"
    shift 2
    local raw_msg="$*"
    local safe_msg
    safe_msg="$(redact_secrets "${raw_msg}")"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S %z')"
    printf '[%s] [%s] %s\n' "${ts}" "${level}" "${safe_msg}" >&2
    if [[ "${ACTION_MODE}" != "preflight" && "${ACTION_MODE}" != "help" && -d "${LOG_DIR}" ]]; then
        printf '[%s] [%s] %s\n' "${ts}" "${level}" "${safe_msg}" >> "${LOG_DIR}/${log_file}"
        if [[ "${log_file}" != "installation.log" ]]; then
            printf '[%s] [%s] [%s] %s\n' "${ts}" "${level}" "${log_file}" "${safe_msg}" >> "${LOG_DIR}/installation.log"
        fi
    fi
}

log_info()  { log_msg "INFO"  "${1}" "${@:2}"; }
log_warn()  { log_msg "WARN"  "${1}" "${@:2}"; }
log_error() { log_msg "ERROR" "${1}" "${@:2}"; }

# ------------------------------ Error & Lock Trap -----------------------------
on_error_trap() {
    local exit_code=$?
    local line_no="${1:-unknown}"
    trap - ERR
    if [[ "${BASH_SUBSHELL:-0}" -gt 0 ]]; then
        exit "${exit_code}"
    fi
    log_error_tr "installation.log" "M_0001" "${line_no}" "${exit_code}"
    if [[ "${SMARTDNS_VERIFIED:-false}" != "true" && -d "${STATE_DIR}" ]]; then
        REBOOT_LOCKED="true"
        REBOOT_ALLOWED="false"
        save_reboot_lock_state 2>/dev/null || true
    fi
    if [[ "${TRANSACTION_ACTIVE}" -eq 1 && -n "${CURRENT_BACKUP_DIR}" && -d "${CURRENT_BACKUP_DIR}" ]]; then
        log_warn_tr "rollback.log" "M_0002"
        perform_rollback "${CURRENT_BACKUP_DIR}" || true
    fi
    exit "${exit_code}"
}

trap 'on_error_trap ${LINENO}' ERR

acquire_lock() {
    if [[ "${ACTION_MODE}" == "help" ]]; then
        return 0
    fi
    mkdir -p "$(dirname "${LOCK_FILE}")"
    exec 9>"${LOCK_FILE}"
    if ! flock -n 9; then
        printf_err_tr "M_0003" "${SCRIPT_NAME}" "${LOCK_FILE}"
        exit 1
    fi
}

check_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        printf_err_tr "M_0004"
        exit 1
    fi
}

# ------------------------------ System Discovery ------------------------------
detect_environment() {
    if [[ ! -f /etc/os-release ]]; then
        log_error_tr "preflight.log" "M_0005"
        exit 1
    fi
    # shellcheck disable=SC1091
    source /etc/os-release
    OS_ID="${ID:-unknown}"
    OS_VERSION_ID="${VERSION_ID:-unknown}"
    OS_CODENAME="${VERSION_CODENAME:-unknown}"
    OS_PRETTY="${PRETTY_NAME:-unknown}"

    CPU_ARCH="$(uname -m)"
    KERNEL_VER="$(uname -r)"
    CPU_CORES="$(nproc 2>/dev/null || echo 1)"
    MEM_TOTAL_MB="$(awk '/MemTotal/ {printf "%d", $2/1024}' /proc/meminfo)"
    DISK_FREE_MB="$(df -Pm / /var /usr 2>/dev/null | awk 'NR==2 {print $4}')"

    PRIMARY_IFACE="$(ip -4 route show default 2>/dev/null | awk '{print $5; exit}')"
    if [[ -z "${PRIMARY_IFACE}" ]]; then
        PRIMARY_IFACE="$(ip -o link show | awk -F': ' '$2 != "lo" {print $2; exit}')"
    fi

    SERVER_IPV4="$(ip -4 -o addr show dev "${PRIMARY_IFACE}" scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}' || true)"
    SERVER_IPV6="$(ip -6 -o addr show dev "${PRIMARY_IFACE}" scope global 2>/dev/null | awk '{split($4,a,"/"); print a[1]; exit}' || true)"
    ALL_LOCAL_IPS="$(ip -o addr show 2>/dev/null | awk '{split($4,a,"/"); print a[1]}' | paste -sd ',' -)"

    HAS_IPV6=0
    if [[ -f /proc/net/if_inet6 && -n "${SERVER_IPV6}" ]]; then
        HAS_IPV6=1
    fi

    IPTABLES_BACKEND="unknown"
    if command -v iptables >/dev/null 2>&1; then
        if iptables --version 2>/dev/null | grep -qi "nf_tables"; then
            IPTABLES_BACKEND="iptables-nft"
        else
            IPTABLES_BACKEND="iptables-legacy"
        fi
    fi

    DOCKER_PRESENT=0
    if command -v docker >/dev/null 2>&1 || systemctl is-active --quiet docker 2>/dev/null; then
        DOCKER_PRESENT=1
    fi
}

validate_os_and_resources() {
    local supported=0
    case "${OS_ID}" in
        debian)
            if [[ "${OS_VERSION_ID}" == "12" || "${OS_VERSION_ID}" == "13" || "${OS_CODENAME}" == "trixie" || "${OS_CODENAME}" == "bookworm" ]]; then
                supported=1
            fi
            ;;
        ubuntu)
            if [[ "${OS_VERSION_ID}" == "22.04" || "${OS_VERSION_ID}" == "24.04" ]]; then
                supported=1
            fi
            ;;
    esac

    if [[ "${supported}" -ne 1 ]]; then
        log_error_tr "preflight.log" "M_0006" "${OS_PRETTY}"
        exit 1
    fi

    if [[ "${MEM_TOTAL_MB}" -lt 512 ]]; then
        log_error_tr "preflight.log" "M_0007" "${MEM_TOTAL_MB}"
        exit 1
    fi

    if [[ "${DISK_FREE_MB}" -lt 1500 ]]; then
        log_error_tr "preflight.log" "M_0008" "${DISK_FREE_MB}"
        exit 1
    fi

    if [[ -z "${SERVER_IPV4}" ]]; then
        log_error_tr "preflight.log" "M_0009" "${PRIMARY_IFACE}"
        exit 1
    fi
}

# ------------------------------ Preflight Mode --------------------------------
run_preflight() {
    detect_environment
    printf '==============================================================================\n'
    printf_tr "M_0010"
    printf '==============================================================================\n'
    printf_tr "M_0011" "${OS_PRETTY}" "${OS_ID}" "${OS_CODENAME}"
    printf_tr "M_0012" "${KERNEL_VER}"
    printf_tr "M_0013" "${CPU_ARCH}" "${CPU_CORES}"
    printf_tr "M_0014" "${MEM_TOTAL_MB}"
    printf_tr "M_0015" "${DISK_FREE_MB}"
    printf_tr "M_0016" "${PRIMARY_IFACE}"
    printf_tr "M_0017" "${SERVER_IPV4:-нет}"
    printf_tr "M_0018" "${SERVER_IPV6:-нет}" "${HAS_IPV6}"
    printf_tr "M_0019" "${ALL_LOCAL_IPS}"
    printf 'Firewall backend     : %s\n' "${IPTABLES_BACKEND}"
    printf_tr "M_0022" "$( [[ "${DOCKER_PRESENT}" -eq 1 ]] && echo "$(tr_msg M_0020)" || echo "$(tr_msg M_0021)" )"
    printf -- '------------------------------------------------------------------------------\n'
    printf_tr "M_0023"
    for svc in nginx xray oxidns adguardhome ufw; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            printf_tr "M_0024" "${svc}"
        else
            printf_tr "M_0025" "${svc}"
        fi
    done
    printf -- '------------------------------------------------------------------------------\n'
    printf_tr "M_0026"
    if [[ "${CPU_ARCH}" == "x86_64" ]]; then
        printf_tr "M_0027"
    else
        printf_tr "M_0028"
    fi
    printf_tr "M_0029" "${CPU_ARCH}"
    printf -- '------------------------------------------------------------------------------\n'
    printf_tr "M_0030"
    ss -tulnp 2>/dev/null | sed 's/^/  /' || true
    printf '==============================================================================\n'
    validate_os_and_resources
    printf_tr "M_0031"
}

# ------------------------------ Crypto & Validators ---------------------------
generate_random_alnum() {
    local length="$1"
    local result=""
    while [[ "${#result}" -lt "${length}" ]]; do
        local chunk
        chunk="$(LC_ALL=C tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "${length}" || true)"
        result+="${chunk}"
    done
    printf '%s' "${result:0:${length}}"
}

generate_random_lower() {
    local length="$1"
    local result=""
    while [[ "${#result}" -lt "${length}" ]]; do
        local chunk
        chunk="$(LC_ALL=C tr -dc 'a-z0-9' < /dev/urandom | head -c "${length}" || true)"
        result+="${chunk}"
    done
    printf '%s' "${result:0:${length}}"
}

validate_domain_syntax() {
    local fqdn="$1"
    [[ "${#fqdn}" -le 253 ]] || return 1
    [[ "${fqdn}" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,63}$ ]] || return 1
    return 0
}

validate_single_ipv4() {
    local ip="$1"
    [[ "${ip}" != *"/"* ]] || return 1
    [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'
    read -r o1 o2 o3 o4 <<<"${ip}"
    [[ "${o1}" -le 255 && "${o2}" -le 255 && "${o3}" -le 255 && "${o4}" -le 255 ]] || return 1
    return 0
}

validate_single_ipv6() {
    local ip="$1"
    [[ "${ip}" != *"/"* ]] || return 1
    [[ "${ip}" == *:* ]] || return 1
    [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]] || return 1
    return 0
}

# ------------------------------ Domain Groups & Custom Import -----------------
domain_group_label() {
    local gid="$1"
    if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
        case "${gid}" in
            ai)         printf '%s' "AI Services (OpenAI, Claude, Gemini, Cursor, Grok, OpenRouter, etc.)" ;;
            microsoft)  printf '%s' "Microsoft & Xbox (Copilot, Designer, Xbox Live)" ;;
            dev_cloud)  printf '%s' "Dev, Cloud & SaaS (JetBrains, Atlassian, Notion, Slack, Tailscale, etc.)" ;;
            hardware)   printf '%s' "Hardware & Electronics (AMD, Intel, Nvidia, Dell, Arduino, Corsair, etc.)" ;;
            media)      printf '%s' "Media, Streaming & Design (Spotify, Twitch, Canva, Deezer, Crunchyroll, etc.)" ;;
            gaming)     printf '%s' "Gaming Platforms (Supercell, Chess, Guilded, Game8, Stumble Guys)" ;;
            tools)      printf '%s' "Browsers, Tools & Security (Brave, DeepL, Avast, Tuta, Web Archive, etc.)" ;;
            lifestyle)  printf '%s' "Social, Retail, Finance & Weather (Ikea, Lego, Strava, Aave, Weather, etc.)" ;;
            google_sys) printf '%s' "Google/Android Background Services (apis/clients/googleapis.com)" ;;
            other)      printf '%s' "Other & New Upstream Services (catch-all for remaining sections)" ;;
            *)          printf '%s' "${gid}" ;;
        esac
    else
        case "${gid}" in
            ai)         printf '%s' "AI-сервисы (OpenAI, Claude, Gemini, Cursor, Grok, OpenRouter и др.)" ;;
            microsoft)  printf '%s' "Microsoft и Xbox (Copilot, Designer, Xbox Live)" ;;
            dev_cloud)  printf '%s' "Разработка, облака и SaaS (JetBrains, Atlassian, Notion, Slack, Tailscale и др.)" ;;
            hardware)   printf '%s' "Железо, электроника и CAD (AMD, Intel, Nvidia, Dell, Arduino, Corsair и др.)" ;;
            media)      printf '%s' "Медиа, стриминг и дизайн (Spotify, Twitch, Canva, Deezer, Crunchyroll и др.)" ;;
            gaming)     printf '%s' "Игры и игровые сервисы (Supercell, Chess, Guilded, Game8, Stumble Guys)" ;;
            tools)      printf '%s' "Браузеры, инструменты и безопасность (Brave, DeepL, Avast, Tuta, Web Archive и др.)" ;;
            lifestyle)  printf '%s' "Соцсети, шопинг, финансы и погода (Ikea, Lego, Strava, Aave, Weather и др.)" ;;
            google_sys) printf '%s' "Фоновые сервисы Google/Android (apis/clients/googleapis.com)" ;;
            other)      printf '%s' "Остальное и новые секции upstream (авто-fallback)" ;;
            *)          printf '%s' "${gid}" ;;
        esac
    fi
}

cleanup_domain_index_tmp() {
    if [[ -n "${INDEXED_GEOHIDE_RAW:-}" && -f "${INDEXED_GEOHIDE_RAW}" ]]; then
        rm -f "${INDEXED_GEOHIDE_RAW}" "${INDEXED_GEOHIDE_RAW}.grouped" 2>/dev/null || true
    fi
    INDEXED_GEOHIDE_RAW=""
}

classify_geohide_to_tsv() {
    local src_hosts="$1"
    local out_tsv="$2"
    awk '
        function classify_section(sec,    s) {
            s = tolower(sec)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
            if (s == "" || s ~ /^geohide\.ru/ || s ~ /^последнее обновление/ || s ~ /^регион серверов/ || s ~ /^эти ip-адреса/ || s ~ /^остальные ip-адреса/ || s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
                return ""
            }
            if (s ~ /^работающие ip/ || s ~ /^остальное$/) {
                return "other"
            }
            if (s ~ /(^|[[:space:](])ai([[:space:])]|$)/ || s ~ /(chatgpt|openai|claude|gemini|grok|groq|cursor|elevenlabs|cerebras|genspark|hume|camel|dola|kaleido|manus|monica|opencode|openrouter|reve|trae\.ai|windsurf)/) {
                return "ai"
            }
            if (s ~ /(microsoft|xbox)/) {
                return "microsoft"
            }
            if (s ~ /(37signals|atlassian|autodesk|chaos|clickup|coreweave|framer|jetbrains|linear\.app|make|mongodb|notion|oracle|posthog|slack|sketchup|tableau|tailscale|teamviewer|wix|workos|zerossl)/) {
                return "dev_cloud"
            }
            if (s ~ /(amd|analog|arduino|arrow|broadcom|corsair|cummins|dell|digikey|dyson|elgato|fitbit|intel|makita|microchip|nvidia|xerox)/) {
                return "hardware"
            }
            if (s ~ /(affinity studio|canva|capcut|crunchyroll|deezer|formula 1|imgur|last\.fm|scribd|spotify|twitch)/) {
                return "media"
            }
            if (s ~ /(chess|game8|guilded|stumble guys|supercell)/) {
                return "gaming"
            }
            if (s ~ /(arkoselabs|avast|brave|deepl|fmhy|guidedhacking|qwant|tria\.ge|tuta|web archive)/) {
                return "tools"
            }
            if (s ~ /(aave|badoo|bestbuy|bike24|ikea|lego|modivo|naukri|pump\.fun|strava|truth social|weather\.com|weather underground)/) {
                return "lifestyle"
            }
            return "other"
        }
        BEGIN { cur_grp = "other" }
        {
            sub(/\r$/, "")
            if ($0 ~ /^[[:space:]]*$/) next
            if ($0 ~ /^[[:space:]]*#/) {
                hdr = $0
                sub(/^[[:space:]]*#+[[:space:]]*/, "", hdr)
                g = classify_section(hdr)
                if (g != "") cur_grp = g
                next
            }
            if ($1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || $1 ~ /:/) {
                for (i = 2; i <= NF; i++) {
                    if ($i ~ /^#/) break
                    d = tolower($i)
                    sub(/^\*\./, "", d)
                    sub(/^\./, "", d)
                    if (d ~ /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/) {
                        print cur_grp "\t" d
                    }
                }
            } else {
                d = tolower($1)
                sub(/^\*\./, "", d)
                sub(/^\./, "", d)
                if (d ~ /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/) {
                    print cur_grp "\t" d
                }
            }
        }
    ' "${src_hosts}" | sort -u > "${out_tsv}"
}

fetch_and_index_domain_groups() {
    cleanup_domain_index_tmp
    local gid
    for gid in "${DOMAIN_GROUP_IDS[@]}"; do
        DOMAIN_GROUP_COUNTS["${gid}"]=0
    done
    DOMAIN_GROUP_COUNTS["google_sys"]=8

    printf_tr "M_0333"
    INDEXED_GEOHIDE_RAW="$(mktemp /tmp/geohide-index.XXXXXX)"
    local dl_ok=0
    local dl_reason="no curl/wget/python3"

    if command -v curl >/dev/null 2>&1; then
        local http_code
        http_code="$(curl -sSL --retry 2 --connect-timeout 10 --max-time 30 -w '%{http_code}' -o "${INDEXED_GEOHIDE_RAW}" "${GEOHIDE_RAW_URL}" 2>/dev/null || echo "000")"
        if [[ "${http_code}" == "200" && -s "${INDEXED_GEOHIDE_RAW}" ]]; then
            dl_ok=1
        else
            dl_reason="curl HTTP=${http_code}"
        fi
    fi
    if [[ "${dl_ok}" -eq 0 ]] && command -v wget >/dev/null 2>&1; then
        if wget -q --timeout=15 --tries=2 -O "${INDEXED_GEOHIDE_RAW}" "${GEOHIDE_RAW_URL}" 2>/dev/null && [[ -s "${INDEXED_GEOHIDE_RAW}" ]]; then
            dl_ok=1
        else
            dl_reason="wget failed"
        fi
    fi
    if [[ "${dl_ok}" -eq 0 ]] && command -v python3 >/dev/null 2>&1; then
        if python3 -c 'import urllib.request, sys; urllib.request.urlretrieve(sys.argv[1], sys.argv[2])' "${GEOHIDE_RAW_URL}" "${INDEXED_GEOHIDE_RAW}" 2>/dev/null && [[ -s "${INDEXED_GEOHIDE_RAW}" ]]; then
            dl_ok=1
        else
            dl_reason="python3 urllib failed"
        fi
    fi

    if [[ "${dl_ok}" -eq 1 ]]; then
        classify_geohide_to_tsv "${INDEXED_GEOHIDE_RAW}" "${INDEXED_GEOHIDE_RAW}.grouped"
        local g cnt
        while read -r cnt g; do
            [[ -n "${g}" ]] && DOMAIN_GROUP_COUNTS["${g}"]="${cnt}"
        done < <(awk -F'\t' '{print $1}' "${INDEXED_GEOHIDE_RAW}.grouped" | LC_ALL=C sort | uniq -c)
    else
        printf_tr "M_0334" "${dl_reason}"
        : > "${INDEXED_GEOHIDE_RAW}.grouped"
        if [[ -s "${DOMAIN_GROUPS_MAP_FILE}" ]]; then
            local g cnt
            while IFS=$'\t' read -r g cnt; do
                [[ -z "${g}" || "${g}" == \#* ]] && continue
                DOMAIN_GROUP_COUNTS["${g}"]="${cnt}"
            done < "${DOMAIN_GROUPS_MAP_FILE}"
        fi
    fi
}

domain_group_is_selected() {
    local target="$1"
    [[ "${DOMAIN_GROUP_SELECTED[${target}]:-0}" -eq 1 ]]
}

init_domain_group_selection_from_string() {
    local csv="${1:-}"
    local gid
    for gid in "${DOMAIN_GROUP_IDS[@]}"; do
        DOMAIN_GROUP_SELECTED["${gid}"]=0
    done
    if [[ "${csv}" == "ALL" ]]; then
        for gid in "${DOMAIN_GROUP_IDS[@]}"; do
            DOMAIN_GROUP_SELECTED["${gid}"]=1
        done
    elif [[ -n "${csv}" && "${csv}" != "NONE" ]]; then
        local tok
        for tok in ${csv//,/ }; do
            if [[ -n "${DOMAIN_GROUP_SELECTED[${tok}]+x}" ]]; then
                DOMAIN_GROUP_SELECTED["${tok}"]=1
            fi
        done
    fi
}

build_selected_groups_csv() {
    local all_on=1
    local any_on=0
    local out=""
    local gid
    for gid in "${DOMAIN_GROUP_IDS[@]}"; do
        if [[ "${DOMAIN_GROUP_SELECTED[${gid}]:-0}" -eq 1 ]]; then
            any_on=1
            out+="${out:+,}${gid}"
        else
            all_on=0
        fi
    done
    if [[ "${any_on}" -eq 0 ]]; then
        printf 'NONE'
    elif [[ "${all_on}" -eq 1 ]]; then
        printf 'ALL'
    else
        printf '%s' "${out}"
    fi
}

print_domain_groups_menu() {
    printf_tr "M_0335"
    printf_tr "M_0336"
    local i=0
    local gid mark cnt label
    for gid in "${DOMAIN_GROUP_IDS[@]}"; do
        i=$((i + 1))
        mark=" "
        [[ "${DOMAIN_GROUP_SELECTED[${gid}]:-0}" -eq 1 ]] && mark="x"
        cnt="${DOMAIN_GROUP_COUNTS[${gid}]:-0}"
        label="$(domain_group_label "${gid}")"
        printf '  [%s] [%2d] %s (%s)\n' "${mark}" "${i}" "${label}" "${cnt}"
    done
}

prompt_domain_groups_selection() {
    local initial_csv="${1:-}"
    fetch_and_index_domain_groups
    init_domain_group_selection_from_string "${initial_csv}"

    local choice=""
    local gid
    while true; do
        print_domain_groups_menu
        read_tr "M_0337" choice
        choice="${choice^^}"
        choice="${choice//$'\r'/}"

        case "${choice}" in
            A)
                for gid in "${DOMAIN_GROUP_IDS[@]}"; do
                    DOMAIN_GROUP_SELECTED["${gid}"]=1
                done
                break
                ;;
            N)
                for gid in "${DOMAIN_GROUP_IDS[@]}"; do
                    DOMAIN_GROUP_SELECTED["${gid}"]=0
                done
                break
                ;;
            Q)
                printf_tr "M_0340"
                cleanup_domain_index_tmp
                return 1
                ;;
            C)
                local custom_in=""
                while true; do
                    print_domain_groups_menu
                    printf '\n'
                    read_tr "M_0338" custom_in
                    custom_in="${custom_in//$'\r'/}"
                    case "${custom_in^^}" in
                        Q)
                            printf_tr "M_0340"
                            cleanup_domain_index_tmp
                            return 1
                            ;;
                        A)
                            for gid in "${DOMAIN_GROUP_IDS[@]}"; do
                                DOMAIN_GROUP_SELECTED["${gid}"]=1
                            done
                            ;;
                        N)
                            for gid in "${DOMAIN_GROUP_IDS[@]}"; do
                                DOMAIN_GROUP_SELECTED["${gid}"]=0
                            done
                            ;;
                        D)
                            break 2
                            ;;
                        *)
                            local tok idx target_gid
                            for tok in ${custom_in//,/ }; do
                                if [[ "${tok}" =~ ^[0-9]+$ ]] && [[ "${tok}" -ge 1 && "${tok}" -le "${#DOMAIN_GROUP_IDS[@]}" ]]; then
                                    idx=$((tok - 1))
                                    target_gid="${DOMAIN_GROUP_IDS[${idx}]}"
                                    if [[ "${DOMAIN_GROUP_SELECTED[${target_gid}]:-0}" -eq 1 ]]; then
                                        DOMAIN_GROUP_SELECTED["${target_gid}"]=0
                                    else
                                        DOMAIN_GROUP_SELECTED["${target_gid}"]=1
                                    fi
                                fi
                            done
                            ;;
                    esac
                done
                ;;
            *)
                printf_tr "M_0368"
                ;;
        esac
    done

    SELECTED_DOMAIN_GROUPS="$(build_selected_groups_csv)"
    if domain_group_is_selected "google_sys"; then
        EXCLUDE_GOOGLE_SYS="N"
    else
        EXCLUDE_GOOGLE_SYS="y"
    fi

    if domain_group_is_selected "microsoft"; then
        printf_tr "M_0064"
        printf_tr "M_0065"
        printf_tr "M_0066"
        local incl_xbox=""
        read_tr "M_0067" incl_xbox
        if [[ "${incl_xbox:-N}" =~ ^[Yy]$ ]]; then
            INCLUDE_XBOX_IPIFY="y"
        else
            INCLUDE_XBOX_IPIFY="N"
        fi
    else
        INCLUDE_XBOX_IPIFY="N"
    fi

    printf_tr "M_0339" "${SELECTED_DOMAIN_GROUPS}"
    return 0
}

build_selected_baseline_domains_file() {
    local out_file="$1"
    local tmp_base
    tmp_base="$(mktemp /tmp/smartdns-base-doms.XXXXXX)"

    if [[ "${SELECTED_DOMAIN_GROUPS}" != "NONE" && -n "${INDEXED_GEOHIDE_RAW:-}" && -s "${INDEXED_GEOHIDE_RAW}.grouped" ]]; then
        awk -F'\t' -v sel="${SELECTED_DOMAIN_GROUPS}" '
            BEGIN {
                if (sel == "ALL") {
                    all_mode = 1
                } else {
                    n = split(sel, arr, ",")
                    for (i = 1; i <= n; i++) want[arr[i]] = 1
                }
            }
            all_mode || ($1 in want) { print $2 }
        ' "${INDEXED_GEOHIDE_RAW}.grouped" >> "${tmp_base}"
    fi

    if domain_group_is_selected "google_sys"; then
        cat >> "${tmp_base}" <<'GDOMS'
apis.google.com
suggestqueries.google.com
clients6.google.com
clients.google.com
withgoogle.com
o.pki.goog
googleapis.com
generativelanguage.googleapis.com
GDOMS
    fi
    if domain_group_is_selected "ai"; then
        printf 'generativelanguage.googleapis.com\n' >> "${tmp_base}"
    fi
    if domain_group_is_selected "microsoft" && [[ "${INCLUDE_XBOX_IPIFY:-N}" == "y" ]]; then
        cat >> "${tmp_base}" <<'XDOMS'
xboxlive.com
xbox.com
sfx.ms
msgamestudios.com
XDOMS
    fi
    if [[ -s "${CUSTOM_ALLOW_FILE}" ]]; then
        grep -E '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' "${CUSTOM_ALLOW_FILE}" >> "${tmp_base}" || true
    fi
    if [[ -n "${PENDING_CUSTOM_DOMAINS_FILE:-}" && -s "${PENDING_CUSTOM_DOMAINS_FILE}" ]]; then
        cat "${PENDING_CUSTOM_DOMAINS_FILE}" >> "${tmp_base}"
    fi

    sort -u "${tmp_base}" > "${out_file}"
    rm -f "${tmp_base}"
}

prompt_custom_domains_import() {
    local want_custom=""
    read_tr "M_0341" want_custom
    if [[ ! "${want_custom:-N}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    if [[ -z "${PENDING_CUSTOM_DOMAINS_FILE:-}" || ! -f "${PENDING_CUSTOM_DOMAINS_FILE}" ]]; then
        PENDING_CUSTOM_DOMAINS_FILE="$(mktemp /tmp/smartdns-custom-import.XXXXXX)"
        chmod 0600 "${PENDING_CUSTOM_DOMAINS_FILE}"
        PENDING_CUSTOM_DOMAINS_COUNT=0
    fi

    while true; do
        local src_input=""
        read_tr "M_0342" src_input
        src_input="${src_input//$'\r'/}"
        src_input="${src_input#"${src_input%%[![:space:]]*}"}"
        src_input="${src_input%"${src_input##*[![:space:]]}"}"

        if [[ -z "${src_input}" ]]; then
            break
        fi

        local raw_src=""
        local tmp_dl=""
        if [[ "${src_input}" =~ ^https?:// ]]; then
            printf_tr "M_0343" "${src_input}"
            tmp_dl="$(mktemp /tmp/smartdns-custom-dl.XXXXXX)"
            local c_dl_ok=0
            if command -v curl >/dev/null 2>&1; then
                if curl -fsSL --retry 2 --connect-timeout 10 --max-time 30 --max-filesize 10485760 -o "${tmp_dl}" "${src_input}" 2>/dev/null && [[ -s "${tmp_dl}" ]]; then
                    c_dl_ok=1
                fi
            fi
            if [[ "${c_dl_ok}" -eq 0 ]] && command -v wget >/dev/null 2>&1; then
                if wget -q --timeout=15 --tries=2 -O "${tmp_dl}" "${src_input}" 2>/dev/null && [[ -s "${tmp_dl}" ]]; then
                    local dl_sz
                    dl_sz="$(stat -c%s "${tmp_dl}" 2>/dev/null || echo 0)"
                    if [[ "${dl_sz}" -le 10485760 ]]; then c_dl_ok=1; fi
                fi
            fi
            if [[ "${c_dl_ok}" -ne 1 ]]; then
                rm -f "${tmp_dl}"
                printf_err_tr "M_0344" "${src_input}"
                continue
            fi
            raw_src="${tmp_dl}"
        else
            if [[ ! -f "${src_input}" || ! -r "${src_input}" ]]; then
                printf_err_tr "M_0345" "${src_input}"
                continue
            fi
            raw_src="${src_input}"
        fi

        local tmp_parsed tmp_valid_all tmp_valid_uniq tmp_safe_uniq tmp_base tmp_new_uniq
        tmp_parsed="$(mktemp /tmp/smartdns-cparse.XXXXXX)"
        tmp_valid_all="$(mktemp /tmp/smartdns-cvalid.XXXXXX)"
        tmp_valid_uniq="$(mktemp /tmp/smartdns-cuniq.XXXXXX)"
        tmp_safe_uniq="$(mktemp /tmp/smartdns-csafe.XXXXXX)"
        tmp_base="$(mktemp /tmp/smartdns-cbase.XXXXXX)"
        tmp_new_uniq="$(mktemp /tmp/smartdns-cnew.XXXXXX)"

        local invalid_cnt=0
        awk '
            {
                sub(/\r$/, "")
                sub(/#.*$/, "")
                gsub(/^[[:space:]]+|[[:space:]]+$/, "")
                if ($0 == "") next
                n = split($0, f, /[[:space:]]+/)
                start_i = 1
                if (f[1] ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || (f[1] ~ /^[0-9a-fA-F:]+$/ && f[1] ~ /:/)) {
                    start_i = 2
                }
                if (start_i > n) {
                    print "INVALID"
                    next
                }
                for (i = start_i; i <= n; i++) {
                    d = tolower(f[i])
                    sub(/^(domain:|full:)/, "", d)
                    sub(/^\*\./, "", d)
                    sub(/^\./, "", d)
                    sub(/\.$/, "", d)
                    if (d ~ /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/ && length(d) <= 253) {
                        print "OK\t" d
                    } else {
                        print "INVALID"
                    }
                }
            }
        ' "${raw_src}" > "${tmp_parsed}"

        invalid_cnt="$(grep -c '^INVALID$' "${tmp_parsed}" || true)"
        invalid_cnt="${invalid_cnt:-0}"
        awk -F'\t' '$1 == "OK" { print $2 }' "${tmp_parsed}" > "${tmp_valid_all}"
        LC_ALL=C sort -u "${tmp_valid_all}" > "${tmp_valid_uniq}"

        local valid_all_cnt valid_uniq_cnt internal_dups
        valid_all_cnt="$(wc -l < "${tmp_valid_all}" | tr -d ' ')"
        valid_uniq_cnt="$(wc -l < "${tmp_valid_uniq}" | tr -d ' ')"
        internal_dups=$((valid_all_cnt - valid_uniq_cnt))

        # Фильтруем безусловные системные исключения и custom-deny.txt
        awk '
            $0 == "x.com" || $0 ~ /\.x\.com$/ { next }
            $0 == "meta.ai" || $0 ~ /\.meta\.ai$/ { next }
            $0 == "connectivitycheck.gstatic.com" || $0 == "connectivitycheck.android.com" { next }
            $0 ~ /^clients[0-9]*\.google\.com$/ { next }
            $0 == "captive.apple.com" || $0 == "connect.rom.miui.com" { next }
            $0 == "msftconnecttest.com" || $0 ~ /\.msftconnecttest\.com$/ { next }
            $0 == "msftncsi.com" || $0 ~ /\.msftncsi\.com$/ { next }
            { print }
        ' "${tmp_valid_uniq}" > "${tmp_safe_uniq}.1"

        if [[ -s "${CUSTOM_DENY_FILE}" ]]; then
            grep -vFf "${CUSTOM_DENY_FILE}" "${tmp_safe_uniq}.1" | LC_ALL=C sort -u > "${tmp_safe_uniq}" || true
        else
            LC_ALL=C sort -u "${tmp_safe_uniq}.1" > "${tmp_safe_uniq}"
        fi
        rm -f "${tmp_safe_uniq}.1"

        local safe_uniq_cnt blocked_sys_cnt
        safe_uniq_cnt="$(wc -l < "${tmp_safe_uniq}" | tr -d ' ')"
        blocked_sys_cnt=$((valid_uniq_cnt - safe_uniq_cnt))

        # Сравнение с выбранными группами + существующим custom-allow + уже подготовленными доменами
        build_selected_baseline_domains_file "${tmp_base}"
        LC_ALL=C sort -u "${tmp_base}" -o "${tmp_base}"
        LC_ALL=C comm -23 "${tmp_safe_uniq}" "${tmp_base}" > "${tmp_new_uniq}"

        local new_uniq_cnt overlap_cnt
        new_uniq_cnt="$(wc -l < "${tmp_new_uniq}" | tr -d ' ')"
        overlap_cnt=$((safe_uniq_cnt - new_uniq_cnt))

        printf_tr "M_0346"
        printf_tr "M_0347" "${src_input}"
        printf_tr "M_0348" "${valid_uniq_cnt}"
        printf_tr "M_0349" "${internal_dups}"
        printf_tr "M_0350" "${invalid_cnt}"
        printf_tr "M_0351" "${overlap_cnt}"
        printf_tr "M_0352" "${blocked_sys_cnt}"
        printf_tr "M_0353" "${new_uniq_cnt}"
        printf_tr "M_0354"

        if [[ "${new_uniq_cnt}" -eq 0 ]]; then
            printf_tr "M_0355"
        else
            local confirm_add=""
            read_tr "M_0356" confirm_add "${new_uniq_cnt}"
            if [[ "${confirm_add:-Y}" =~ ^[Yy]$ ]]; then
                cat "${tmp_new_uniq}" >> "${PENDING_CUSTOM_DOMAINS_FILE}"
                sort -u "${PENDING_CUSTOM_DOMAINS_FILE}" -o "${PENDING_CUSTOM_DOMAINS_FILE}"
                PENDING_CUSTOM_DOMAINS_COUNT="$(wc -l < "${PENDING_CUSTOM_DOMAINS_FILE}" | tr -d ' ')"
                printf_tr "M_0357" "${PENDING_CUSTOM_DOMAINS_COUNT}"
            fi
        fi

        rm -f "${tmp_parsed}" "${tmp_valid_all}" "${tmp_valid_uniq}" "${tmp_safe_uniq}" "${tmp_base}" "${tmp_new_uniq}"
        if [[ -n "${tmp_dl}" ]]; then rm -f "${tmp_dl}"; fi

        local add_more=""
        read_tr "M_0358" add_more
        if [[ ! "${add_more:-N}" =~ ^[Yy]$ ]]; then
            break
        fi
    done
}

apply_pending_custom_domains() {
    if [[ -z "${PENDING_CUSTOM_DOMAINS_FILE:-}" || ! -s "${PENDING_CUSTOM_DOMAINS_FILE}" ]]; then
        rm -f "${PENDING_CUSTOM_DOMAINS_FILE:-}" 2>/dev/null || true
        PENDING_CUSTOM_DOMAINS_FILE=""
        PENDING_CUSTOM_DOMAINS_COUNT=0
        return 0
    fi

    local added_cnt
    added_cnt="$(wc -l < "${PENDING_CUSTOM_DOMAINS_FILE}" | tr -d ' ')"
    local tmp_merge="${CUSTOM_ALLOW_FILE}.merge.tmp"
    touch "${CUSTOM_ALLOW_FILE}"
    cat "${CUSTOM_ALLOW_FILE}" "${PENDING_CUSTOM_DOMAINS_FILE}" | \
        grep -E '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' | sort -u > "${tmp_merge}" || true
    chown "${DNS_USER}:xray" "${tmp_merge}"
    chmod 0640 "${tmp_merge}"
    mv -f "${tmp_merge}" "${CUSTOM_ALLOW_FILE}"

    local total_cnt
    total_cnt="$(wc -l < "${CUSTOM_ALLOW_FILE}" | tr -d ' ')"
    rm -f "${PENDING_CUSTOM_DOMAINS_FILE}"
    PENDING_CUSTOM_DOMAINS_FILE=""
    PENDING_CUSTOM_DOMAINS_COUNT=0
    log_info_tr "dns.log" "M_0359" "${CUSTOM_ALLOW_FILE}" "${added_cnt}" "${total_cnt}"
}

get_test_proxied_domain() {
    if [[ ! -s "${GEOHIDE_LIST_FILE}" ]]; then
        printf ''
        return 0
    fi
    if grep -qx 'generativelanguage.googleapis.com' "${GEOHIDE_LIST_FILE}" 2>/dev/null; then
        printf 'generativelanguage.googleapis.com'
        return 0
    fi
    grep -E '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' "${GEOHIDE_LIST_FILE}" | sed -n '1p' || true
}

# ------------------------------ Interactive Wizard ----------------------------
# ------------------------------ Provider Hostname Profile (No Cloudflare) -----
is_hostname_profile() {
    [[ "${INSTALL_PROFILE:-}" == "hostname" || "${TLS_MODE:-}" == "existing-certbot" || "${DNS_PROVIDER:-}" == "external" ]]
}

validate_safe_abs_path() {
    local p="$1"
    [[ -n "${p}" ]] || return 1
    [[ "${p}" == /* ]] || return 1
    [[ "${p}" =~ ^/[A-Za-z0-9_./-]+$ ]] || return 1
    [[ "${p}" != *"//"* ]] || return 1
    [[ "${p}" != *"/../"* && "${p}" != *"/.." && "${p}" != "../*" && "${p}" != ".." ]] || return 1
    case "${p}" in
        /|/etc|/var|/usr|/root|/tmp|/dev|/proc|/sys) return 1 ;;
    esac
    return 0
}

validate_strict_ipv6() {
    local ip="$1"
    [[ -n "${ip}" ]] || return 1
    [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]] || return 1
    [[ "${ip}" == *:* ]] || return 1
    [[ "${ip}" != *":::"* ]] || return 1
    if [[ "${ip}" == :* && "${ip}" != ::* ]]; then
        return 1
    fi
    if [[ "${ip}" == *: && "${ip}" != *:: ]]; then
        return 1
    fi

    local rest="${ip#*::}"
    local has_double=0
    if [[ "${rest}" != "${ip}" ]]; then
        has_double=1
        if [[ "${rest}" == *"::"* ]]; then
            return 1
        fi
    fi

    local left="" right=""
    if [[ "${has_double}" -eq 1 ]]; then
        left="${ip%%::*}"
        right="${ip#*::}"
    else
        left="${ip}"
        right=""
    fi

    local group_count=0
    local part g
    for part in "${left}" "${right}"; do
        [[ -n "${part}" ]] || continue
        local IFS=':'
        local -a groups=()
        read -r -a groups <<< "${part}"
        for g in "${groups[@]}"; do
            [[ "${g}" =~ ^[0-9a-fA-F]{1,4}$ ]] || return 1
            group_count=$((group_count + 1))
        done
    done

    if [[ "${has_double}" -eq 1 ]]; then
        [[ "${group_count}" -le 7 ]] || return 1
    else
        [[ "${group_count}" -eq 8 ]] || return 1
    fi
    return 0
}

load_settings_safely() {
    local sf="${1:-${SETTINGS_FILE}}"
    [[ -f "${sf}" ]] || return 1
    if [[ ! -r "${sf}" ]] || ! bash -n "${sf}" >/dev/null 2>&1; then
        printf_err_tr "HN_SETTINGS_CORRUPT" "${sf}"
        return 1
    fi
    # shellcheck disable=SC1090
    source "${sf}"
    return 0
}

detect_install_profile_from_context() {
    if [[ -n "${INSTALL_PROFILE:-}" ]]; then
        INSTALL_PROFILE="${INSTALL_PROFILE,,}"
        if [[ "${INSTALL_PROFILE}" != "cloudflare" && "${INSTALL_PROFILE}" != "hostname" ]]; then
            printf_err_tr "HN_PROFILE_BAD" "${INSTALL_PROFILE}"
            return 1
        fi
        return 0
    fi

    if [[ -f "${SETTINGS_FILE}" ]]; then
        local saved_prof saved_tls saved_dns
        saved_prof="$(awk -F'"' '/^INSTALL_PROFILE=/ {print $2; exit}' "${SETTINGS_FILE}" 2>/dev/null || true)"
        saved_tls="$(awk -F'"' '/^TLS_MODE=/ {print $2; exit}' "${SETTINGS_FILE}" 2>/dev/null || true)"
        saved_dns="$(awk -F'"' '/^DNS_PROVIDER=/ {print $2; exit}' "${SETTINGS_FILE}" 2>/dev/null || true)"
        if [[ "${saved_prof}" == "hostname" || "${saved_tls}" == "existing-certbot" || "${saved_dns}" == "external" ]]; then
            INSTALL_PROFILE="hostname"
            return 0
        fi
        if [[ "${saved_prof}" == "cloudflare" ]]; then
            INSTALL_PROFILE="cloudflare"
            return 0
        fi
    fi

    if [[ -n "${PROVIDER_HOSTNAME:-}" ]]; then
        INSTALL_PROFILE="hostname"
        return 0
    fi
    return 0
}

prompt_install_profile_choice() {
    detect_install_profile_from_context || return 1
    if [[ -n "${INSTALL_PROFILE:-}" ]]; then
        return 0
    fi
    if [[ ! -t 0 ]]; then
        INSTALL_PROFILE="cloudflare"
        return 0
    fi
    local pchoice=""
    while true; do
        read_tr "HN_PROFILE_MENU" pchoice
        pchoice="${pchoice//$'\r'/}"
        pchoice="${pchoice:-1}"
        case "${pchoice}" in
            1)
                INSTALL_PROFILE="cloudflare"
                return 0
                ;;
            2)
                INSTALL_PROFILE="hostname"
                return 0
                ;;
            *)
                printf_tr "M_0042"
                ;;
        esac
    done
}

initialize_hostname_profile() {
    # Explicit environment inputs override settings saved by an earlier install.
    local input_host="${PROVIDER_HOSTNAME:-}"
    local input_v4="${PUBLIC_IPV4:-}"
    local input_v6="${PUBLIC_IPV6-}"
    local has_input_v6="${PUBLIC_IPV6+x}"
    local input_cert="${HOSTNAME_CERT_LINEAGE:-}"
    local input_webroot="${HOSTNAME_ACME_WEBROOT:-}"
    local input_renewal="${HOSTNAME_RENEWAL_CONF:-}"
    local path=""

    if [[ -f "${SETTINGS_FILE}" ]]; then
        load_settings_safely "${SETTINGS_FILE}" || return 1
        restore_hostname_profile
    fi

    if [[ -n "${input_host}" && -n "${ROOT_DOMAIN:-}" ]]; then
        local norm_in="${input_host,,}"
        norm_in="${norm_in%.}"
        local norm_root="${ROOT_DOMAIN,,}"
        norm_root="${norm_root%.}"
        if [[ "${norm_in}" != "${norm_root}" ]]; then
            printf_err_tr "HN_04" "${ROOT_DOMAIN}"
            return 1
        fi
    fi

    PROVIDER_HOSTNAME="${input_host:-${PROVIDER_HOSTNAME:-${ROOT_DOMAIN:-}}}"
    PUBLIC_IPV4="${input_v4:-${PUBLIC_IPV4:-${SERVER_IPV4:-}}}"

    local prompted_interactive=0
    if [[ -t 0 ]]; then
        if [[ -z "${PROVIDER_HOSTNAME}" ]]; then
            read_tr "HN_HOST" PROVIDER_HOSTNAME
            prompted_interactive=1
        fi
        if [[ -z "${PUBLIC_IPV4}" ]]; then
            read_tr "HN_IPV4" PUBLIC_IPV4
            prompted_interactive=1
        fi
        if [[ "${prompted_interactive}" -eq 1 && -z "${has_input_v6}" && -z "${PUBLIC_IPV6:-}" && -z "${SERVER_IPV6:-}" && ! -f "${SETTINGS_FILE}" ]]; then
            read_tr "HN_IPV6" input_v6
            has_input_v6="x"
        fi
    fi

    PROVIDER_HOSTNAME="${PROVIDER_HOSTNAME//$'\r'/}"
    PUBLIC_IPV4="${PUBLIC_IPV4//$'\r'/}"
    input_v6="${input_v6//$'\r'/}"

    if [[ -z "${PROVIDER_HOSTNAME}" || -z "${PUBLIC_IPV4}" ]]; then
        printf_err_tr "HN_05"
        return 1
    fi

    PROVIDER_HOSTNAME="${PROVIDER_HOSTNAME,,}"
    PROVIDER_HOSTNAME="${PROVIDER_HOSTNAME%.}"
    if ! validate_domain_syntax "${PROVIDER_HOSTNAME}"; then
        printf_err_tr "HN_06"
        return 1
    fi
    if ! validate_single_ipv4 "${PUBLIC_IPV4}"; then
        printf_err_tr "HN_07"
        return 1
    fi

    if [[ -n "${has_input_v6}" ]]; then
        PUBLIC_IPV6="${input_v6}"
    else
        PUBLIC_IPV6="${PUBLIC_IPV6:-${SERVER_IPV6:-}}"
    fi
    if [[ -n "${PUBLIC_IPV6}" ]]; then
        if ! validate_strict_ipv6 "${PUBLIC_IPV6}"; then
            printf_err_tr "HN_08"
            return 1
        fi
    fi

    # A different hostname gets its own default paths, not the previous lineage.
    if [[ -n "${input_host}" && "${PROVIDER_HOSTNAME}" != "${ROOT_DOMAIN:-}" ]]; then
        HOSTNAME_CERT_LINEAGE="${input_cert:-/etc/letsencrypt/live/${PROVIDER_HOSTNAME}}"
        HOSTNAME_ACME_WEBROOT="${input_webroot:-/var/www/${PROVIDER_HOSTNAME}}"
        HOSTNAME_RENEWAL_CONF="${input_renewal:-/etc/letsencrypt/renewal/${HOSTNAME_CERT_LINEAGE##*/}.conf}"
    else
        HOSTNAME_CERT_LINEAGE="${input_cert:-${HOSTNAME_CERT_LINEAGE:-/etc/letsencrypt/live/${PROVIDER_HOSTNAME}}}"
        HOSTNAME_ACME_WEBROOT="${input_webroot:-${HOSTNAME_ACME_WEBROOT:-/var/www/${PROVIDER_HOSTNAME}}}"
        HOSTNAME_RENEWAL_CONF="${input_renewal:-${HOSTNAME_RENEWAL_CONF:-/etc/letsencrypt/renewal/${HOSTNAME_CERT_LINEAGE##*/}.conf}}"
    fi

    HOSTNAME_CERT_LINEAGE="${HOSTNAME_CERT_LINEAGE%/}"
    HOSTNAME_ACME_WEBROOT="${HOSTNAME_ACME_WEBROOT%/}"

    for path in "${HOSTNAME_CERT_LINEAGE}" "${HOSTNAME_ACME_WEBROOT}" "${HOSTNAME_RENEWAL_CONF}"; do
        if ! validate_safe_abs_path "${path}"; then
            printf_err_tr "HN_09" "${path}"
            return 1
        fi
    done

    INSTALL_PROFILE="hostname"
    DNS_PROVIDER="external"
    TLS_MODE="existing-certbot"
    ROOT_DOMAIN="${PROVIDER_HOSTNAME}"
    DOH_HOST="${PROVIDER_HOSTNAME}"
    DOT_HOST="${PROVIDER_HOSTNAME}"
    SERVER_IPV4="${PUBLIC_IPV4}"
    SERVER_IPV6="${PUBLIC_IPV6}"
    HAS_IPV6=0
    if [[ -n "${PUBLIC_IPV6}" ]]; then
        HAS_IPV6=1
    fi

    HOSTNAME_PROFILE=()
    local key
    for key in INSTALL_PROFILE DNS_PROVIDER TLS_MODE PROVIDER_HOSTNAME PUBLIC_IPV4 PUBLIC_IPV6 \
               HOSTNAME_CERT_LINEAGE HOSTNAME_ACME_WEBROOT HOSTNAME_RENEWAL_CONF \
               ROOT_DOMAIN DOH_HOST DOT_HOST SERVER_IPV4 SERVER_IPV6 HAS_IPV6; do
        HOSTNAME_PROFILE["${key}"]="${!key}"
    done
    HOSTNAME_PROFILE_READY=1
    return 0
}

restore_hostname_profile() {
    [[ "${HOSTNAME_PROFILE_READY:-0}" == "1" ]] || return 0
    local key
    for key in "${!HOSTNAME_PROFILE[@]}"; do
        printf -v "${key}" '%s' "${HOSTNAME_PROFILE[${key}]}"
    done
}

validate_hostname_profile() {
    if [[ "${ROOT_DOMAIN:-}" != "${PROVIDER_HOSTNAME:-}" || "${DOT_HOST:-}" != "${ROOT_DOMAIN:-}" ]]; then
        printf_err_tr "HN_10" "${PROVIDER_HOSTNAME:-unknown}"
        return 1
    fi
    return 0
}

# External DNS belongs to the hostname provider. Read-only validation only.
verify_provider_hostname_dns() {
    local target_ipv4="$1"
    local target_ipv6="${2:-}"
    local resolver records

    validate_hostname_profile || return 1
    validate_single_ipv4 "${target_ipv4}" || return 1
    if [[ -n "${target_ipv6}" ]]; then
        validate_strict_ipv6 "${target_ipv6}" || return 1
    fi

    for resolver in 1.1.1.1 8.8.8.8; do
        if ! records="$(dig +time=5 +tries=1 +short @"${resolver}" A "${ROOT_DOMAIN}" 2>/dev/null)"; then
            printf_err_tr "HN_11" "${ROOT_DOMAIN}" "${target_ipv4}" "${resolver}" "dig-error"
            return 1
        fi
        records="$(printf '%s\n' "${records}" | awk 'NF' | sort -u | paste -sd ',' -)"
        if [[ "${records}" != "${target_ipv4}" ]]; then
            printf_err_tr "HN_11" "${ROOT_DOMAIN}" "${target_ipv4}" "${resolver}" "${records:-empty}"
            return 1
        fi

        if ! records="$(dig +time=5 +tries=1 +short @"${resolver}" AAAA "${ROOT_DOMAIN}" 2>/dev/null)"; then
            printf_err_tr "HN_12" "dig-error" "${target_ipv6:-none}" "${resolver}"
            return 1
        fi
        records="$(printf '%s\n' "${records}" | awk 'NF' | sort -u | paste -sd ',' -)"
        if [[ -n "${target_ipv6}" ]]; then
            if [[ "${records}" != "${target_ipv6}" ]]; then
                printf_err_tr "HN_12" "${records:-empty}" "${target_ipv6}" "${resolver}"
                return 1
            fi
        elif [[ -n "${records}" ]]; then
            printf_err_tr "HN_12" "${records}" "none" "${resolver}"
            return 1
        fi
    done
    printf_tr "HN_13"
    return 0
}

verify_hostname_source_certificate() {
    local lineage="${HOSTNAME_CERT_LINEAGE}"
    local cert_hash key_hash

    [[ -s "${lineage}/fullchain.pem" && -s "${lineage}/privkey.pem" && -s "${lineage}/cert.pem" && -s "${lineage}/chain.pem" ]] || return 1
    openssl x509 -in "${lineage}/fullchain.pem" -noout -checkend 86400 >/dev/null 2>&1 || return 1

    cert_hash="$(openssl x509 -in "${lineage}/fullchain.pem" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}')" || return 1
    key_hash="$(openssl pkey -in "${lineage}/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}')" || return 1
    if [[ -z "${cert_hash}" || "${cert_hash}" != "${key_hash}" ]]; then
        printf_err_tr "HN_14"
        return 1
    fi

    openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
        -verify_hostname "${PROVIDER_HOSTNAME}" \
        -untrusted "${lineage}/chain.pem" "${lineage}/cert.pem" >/dev/null 2>&1 || return 1
    return 0
}

# Prevent overwriting an existing unmanaged stack on shared ports/services.
assert_fresh_install_target() {
    [[ ! -f "${SETTINGS_FILE}" ]] || return 0
    local port svc proc_info
    for port in 80 443 853 5353 8053 8443 8444 8853 9443 9444; do
        proc_info="$(ss -H -lntup "sport = :${port}" 2>/dev/null || ss -H -lntu "sport = :${port}" 2>/dev/null || true)"
        if [[ -n "${proc_info}" ]]; then
            printf_err_tr "HN_17" "${port}" "$(printf '%s' "${proc_info}" | sed -n '1p')"
            return 1
        fi
    done
    for svc in nginx apache2 caddy xray oxidns adguardhome AdGuardHome caddy-naive sing-box; do
        if systemctl is-active --quiet "${svc}" 2>/dev/null; then
            printf_err_tr "HN_18" "${svc}"
            return 1
        fi
    done
    return 0
}

run_hostname_check() {
    ROOT_DOMAIN="${PROVIDER_HOSTNAME}"
    DOH_HOST="${PROVIDER_HOSTNAME}"
    DOT_HOST="${PROVIDER_HOSTNAME}"

    local critical=0
    local warnings=0
    local lineage="${HOSTNAME_CERT_LINEAGE}"
    local webroot="${HOSTNAME_ACME_WEBROOT}"
    local renewal_conf="${HOSTNAME_RENEWAL_CONF}"

    _hc_ok()   { printf '[  OK  ] %s\n' "$1"; }
    _hc_warn() { printf '[ WARN ] %s\n' "$1"; warnings=$((warnings + 1)); }
    _hc_crit() { printf '[ CRIT ] %s\n' "$1"; critical=$((critical + 1)); }

    printf '==============================================================================\n'
    printf_tr "HN_CHECK_BANNER"
    printf '==============================================================================\n'
    printf '  PROVIDER_HOSTNAME     : %s\n' "${PROVIDER_HOSTNAME}"
    printf '  PUBLIC_IPV4           : %s\n' "${PUBLIC_IPV4}"
    printf '  PUBLIC_IPV6           : %s\n' "${PUBLIC_IPV6:-disabled}"
    printf '  HOSTNAME_CERT_LINEAGE : %s\n' "${lineage}"
    printf '  HOSTNAME_ACME_WEBROOT : %s\n' "${webroot}"
    printf '  HOSTNAME_RENEWAL_CONF : %s\n' "${renewal_conf}"
    printf -- '------------------------------------------------------------------------------\n'

    # 1-3. Public DNS A / AAAA and IP matching
    if verify_provider_hostname_dns "${PUBLIC_IPV4}" "${PUBLIC_IPV6:-}" >/dev/null 2>&1; then
        _hc_ok "DNS A/AAAA records match ${PUBLIC_IPV4}${PUBLIC_IPV6:+ / ${PUBLIC_IPV6}} on 1.1.1.1 & 8.8.8.8"
    else
        _hc_crit "DNS A/AAAA mismatch for ${PROVIDER_HOSTNAME} (expected IPv4=${PUBLIC_IPV4}, IPv6=${PUBLIC_IPV6:-none})"
    fi

    # 10-11. Required files, directories, and permissions
    local files_ok=1
    local req_f
    for req_f in "${lineage}/fullchain.pem" "${lineage}/privkey.pem" "${lineage}/cert.pem" "${lineage}/chain.pem"; do
        if [[ ! -s "${req_f}" || ! -r "${req_f}" ]]; then
            _hc_crit "Missing or unreadable certificate file: ${req_f}"
            files_ok=0
        fi
    done
    if [[ "${files_ok}" -eq 1 ]]; then
        _hc_ok "Certificate lineage files exist and are readable (${lineage})"
        local key_mode
        key_mode="$(stat -L -c '%a' "${lineage}/privkey.pem" 2>/dev/null || echo '')"
        if [[ -n "${key_mode}" && "${key_mode: -1}" != "0" ]]; then
            _hc_warn "Private key ${lineage}/privkey.pem is world-accessible (mode ${key_mode}); recommend 0600 or 0640"
        else
            _hc_ok "Private key permissions look safe (mode ${key_mode:-n/a})"
        fi
    fi

    if [[ -d "${webroot}" && -r "${webroot}" ]]; then
        _hc_ok "Certbot webroot directory exists: ${webroot}"
    else
        _hc_crit "Certbot webroot directory missing or unreadable: ${webroot}"
    fi

    # 4-8. Certificate hostname coverage, expiry, key match, chain & CA trust
    if [[ "${files_ok}" -eq 1 ]]; then
        if openssl x509 -in "${lineage}/fullchain.pem" -noout -checkend 86400 >/dev/null 2>&1; then
            if openssl x509 -in "${lineage}/fullchain.pem" -noout -checkend 1209600 >/dev/null 2>&1; then
                _hc_ok "Certificate validity > 14 days"
            else
                _hc_warn "Certificate expires within 14 days (check Certbot auto-renewal)"
            fi
        else
            _hc_crit "Certificate is expired or expires within 24 hours"
        fi

        local cert_hash key_hash
        cert_hash="$(openssl x509 -in "${lineage}/fullchain.pem" -pubkey -noout 2>/dev/null | openssl pkey -pubin -outform DER 2>/dev/null | sha256sum | awk '{print $1}' || true)"
        key_hash="$(openssl pkey -in "${lineage}/privkey.pem" -pubout -outform DER 2>/dev/null | sha256sum | awk '{print $1}' || true)"
        if [[ -n "${cert_hash}" && "${cert_hash}" == "${key_hash}" ]]; then
            _hc_ok "Certificate public key matches private key (SHA-256 DER verified)"
        else
            _hc_crit "Certificate and private key mismatch"
        fi

        if openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
            -verify_hostname "${PROVIDER_HOSTNAME}" \
            -untrusted "${lineage}/chain.pem" "${lineage}/cert.pem" >/dev/null 2>&1; then
            _hc_ok "Certificate chain, CA trust, and hostname coverage (${PROVIDER_HOSTNAME}) verified"
        else
            _hc_crit "Certificate chain, CA trust, or hostname coverage failed for ${PROVIDER_HOSTNAME}"
        fi
    fi

    # 9, 12, 15. Certbot renewal configuration & HTTP-01 readiness
    if [[ -s "${renewal_conf}" && -r "${renewal_conf}" ]]; then
        local ren_ok=1
        if ! grep -q '^authenticator = webroot$' "${renewal_conf}" 2>/dev/null; then
            _hc_crit "Certbot renewal config (${renewal_conf}) does not use 'authenticator = webroot'"
            ren_ok=0
        fi
        if ! grep -Fq "webroot_path = ${webroot}" "${renewal_conf}" 2>/dev/null; then
            _hc_crit "Certbot renewal config (${renewal_conf}) does not reference webroot_path = ${webroot}"
            ren_ok=0
        fi
        if [[ "${ren_ok}" -eq 1 ]]; then
            _hc_ok "Certbot renewal config uses webroot (${webroot}) for HTTP-01 challenge"
        fi
    else
        _hc_crit "Certbot renewal configuration missing or unreadable: ${renewal_conf}"
    fi

    if command -v certbot >/dev/null 2>&1; then
        _hc_ok "Certbot binary detected ($(command -v certbot))"
    else
        _hc_warn "Certbot binary not found in PATH; automatic renewal timer may not run"
    fi

    # 13-14, 16. Occupied ports & conflicting services (read-only)
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        local port occupied_ports="" proc_info
        for port in 80 443 853 5353 8053 8443 8444 8853 9443 9444; do
            proc_info="$(ss -H -lntu "sport = :${port}" 2>/dev/null || true)"
            if [[ -n "${proc_info}" ]]; then
                occupied_ports+="${port} "
            fi
        done
        if [[ -n "${occupied_ports}" ]]; then
            _hc_crit "Required ports occupied on fresh target: ${occupied_ports% } (migration required)"
        else
            _hc_ok "All required SmartDNS ports (80/443/853/5353/8053/8443/8444/8853/9443/9444) are free"
        fi

        local svc active_svcs=""
        for svc in nginx apache2 caddy xray oxidns adguardhome AdGuardHome caddy-naive sing-box; do
            if systemctl is-active --quiet "${svc}" 2>/dev/null; then
                active_svcs+="${svc} "
            fi
        done
        if [[ -n "${active_svcs}" ]]; then
            _hc_crit "Active conflicting services detected on fresh target: ${active_svcs% } (migration required)"
        else
            _hc_ok "No conflicting web/DNS/proxy services active"
        fi
    else
        _hc_ok "Existing SmartDNS installation detected (${SETTINGS_FILE}); port/service check in maintenance mode"
    fi

    printf '==============================================================================\n'
    if [[ "${critical}" -gt 0 ]]; then
        printf_err_tr "HN_CHECK_FAIL" "${critical}" "${warnings}"
        return 1
    fi
    printf_tr "HN_15"
    printf_tr "HN_16" "${PROVIDER_HOSTNAME}"
    printf_tr "HN_CHECK_PASS" "${warnings}"
    return 0
}

# Alias kept for parity with PR #1 tests
hostname_check() {
    run_hostname_check
}

# Dedicated single-host TLS verifier (never overwrites Cloudflare's /usr/local/bin/verify-tls-keys.sh)
install_hostname_tls_verification_helper() {
    cat > /usr/local/bin/verify-hostname-tls-keys.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CERT_FILE="${1:?Specify fullchain.pem path}"
KEY_FILE="${2:?Specify privkey.pem path}"
ROOT_DOM="${3:?Specify PROVIDER_HOSTNAME}"

if [[ ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
    echo "ERROR: Certificate or private key file is missing or empty." >&2
    exit 1
fi

CERT_PUB_HASH="$(openssl x509 -in "${CERT_FILE}" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | awk '{print $1}')"
KEY_PUB_HASH="$(openssl pkey -in "${KEY_FILE}" -pubout -outform DER | sha256sum | awk '{print $1}')"

if [[ -z "${CERT_PUB_HASH}" || "${CERT_PUB_HASH}" != "${KEY_PUB_HASH}" ]]; then
    echo "CRITICAL ERROR: Public key SHA-256 mismatch between fullchain.pem (${CERT_PUB_HASH}) and privkey.pem (${KEY_PUB_HASH})!" >&2
    exit 1
fi

if ! openssl x509 -in "${CERT_FILE}" -noout -checkend 86400 >/dev/null 2>&1; then
    echo "ERROR: Certificate is expired or expires in less than 24 hours." >&2
    exit 1
fi

if ! openssl verify -CAfile /etc/ssl/certs/ca-certificates.crt \
    -verify_hostname "${ROOT_DOM}" -untrusted "${CERT_FILE}" "${CERT_FILE}" >/dev/null 2>&1; then
    echo "ERROR: Certificate chain or hostname verification failed for ${ROOT_DOM}." >&2
    exit 1
fi

echo "OK: Single-host certificate, key, and trust chain verified (SHA-256 PubKey DER: ${CERT_PUB_HASH})."
EOF
    chmod 0755 /usr/local/bin/verify-hostname-tls-keys.sh
}

# Isolated Certbot certificate deployment & lineage-specific renewal hook for Provider Hostname Profile.
# Does NOT touch acme.sh, smartdns-cert-renew.timer, smartdns-cert-deploy.sh, or Cloudflare lineages.
deploy_existing_hostname_certificate() {
    validate_hostname_profile || return 1
    verify_hostname_source_certificate || return 1
    backup_file_before_modify "${CERT_DIR}/fullchain.pem" "certificates" || return 1
    backup_file_before_modify "${CERT_DIR}/privkey.pem" "certificates" || return 1

    install_hostname_tls_verification_helper
    /usr/local/bin/verify-hostname-tls-keys.sh "${HOSTNAME_CERT_LINEAGE}/fullchain.pem" \
        "${HOSTNAME_CERT_LINEAGE}/privkey.pem" "${ROOT_DOMAIN}" >> "${LOG_DIR}/certificate.log" 2>&1

    install -d -m 0750 -o root -g ssl-smartdns "${CERT_DIR}"
    install -m 0644 -o root -g ssl-smartdns "${HOSTNAME_CERT_LINEAGE}/fullchain.pem" "${CERT_DIR}/fullchain.pem.new"
    install -m 0640 -o root -g ssl-smartdns "${HOSTNAME_CERT_LINEAGE}/privkey.pem" "${CERT_DIR}/privkey.pem.new"
    mv -f "${CERT_DIR}/fullchain.pem.new" "${CERT_DIR}/fullchain.pem"
    mv -f "${CERT_DIR}/privkey.pem.new" "${CERT_DIR}/privkey.pem"

    # Certbot continues to own renewal. This hook deploys ONLY the saved hostname lineage.
    cat > /usr/local/bin/smartdns-hostname-cert-deploy.sh <<'HOOK'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

[[ -f /var/lib/oxidns-installer/settings ]] || exit 0
# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings

# Strict profile guard: never run for Cloudflare / acme.sh installations.
[[ "${TLS_MODE:-}" == "existing-certbot" ]] || exit 0

lineage="${HOSTNAME_CERT_LINEAGE:?Missing saved certificate lineage}"
provider_host="${PROVIDER_HOSTNAME:?Missing saved hostname}"

# Strict lineage guard: ignore renewals for any other certificate lineage.
[[ "${RENEWED_LINEAGE:-}" == "${lineage}" ]] || exit 0

exec 9>/run/lock/smartdns-hostname-cert.lock
flock -x 9

LOG_FILE="/var/log/oxidns-installer/certificate.log"
CERT_DIR="/etc/ssl/smartdns"
mkdir -p "$(dirname "${LOG_FILE}")"

log() {
    printf '[%s] [HOSTNAME-CERT-DEPLOY] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" >> "${LOG_FILE}"
}

if ! /usr/local/bin/verify-hostname-tls-keys.sh "${lineage}/fullchain.pem" "${lineage}/privkey.pem" "${provider_host}" >> "${LOG_FILE}" 2>&1; then
    log "ERROR: New certificate verification failed for ${provider_host}; active certificates unchanged."
    exit 1
fi

install -d -m 0750 -o root -g ssl-smartdns "${CERT_DIR}"
install -m 0644 -o root -g ssl-smartdns "${lineage}/fullchain.pem" "${CERT_DIR}/fullchain.pem.new"
install -m 0640 -o root -g ssl-smartdns "${lineage}/privkey.pem" "${CERT_DIR}/privkey.pem.new"

had_prev=0
if [[ -f "${CERT_DIR}/fullchain.pem" && -f "${CERT_DIR}/privkey.pem" ]]; then
    cp -p "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/fullchain.pem.previous"
    cp -p "${CERT_DIR}/privkey.pem" "${CERT_DIR}/privkey.pem.previous"
    had_prev=1
fi

mv -f "${CERT_DIR}/fullchain.pem.new" "${CERT_DIR}/fullchain.pem"
mv -f "${CERT_DIR}/privkey.pem.new" "${CERT_DIR}/privkey.pem"

reload_failed=0
if ! nginx -t >> "${LOG_FILE}" 2>&1; then
    reload_failed=1
elif systemctl is-active --quiet nginx 2>/dev/null; then
    if ! systemctl reload nginx >> "${LOG_FILE}" 2>&1; then
        reload_failed=1
    fi
fi

if [[ "${reload_failed}" -ne 0 ]]; then
    if [[ "${had_prev}" -eq 1 ]]; then
        mv -f "${CERT_DIR}/fullchain.pem.previous" "${CERT_DIR}/fullchain.pem"
        mv -f "${CERT_DIR}/privkey.pem.previous" "${CERT_DIR}/privkey.pem"
        nginx -t >> "${LOG_FILE}" 2>&1 || true
        if systemctl is-active --quiet nginx 2>/dev/null; then
            systemctl reload nginx >> "${LOG_FILE}" 2>&1 || true
        fi
    fi
    log "ERROR: Nginx validation/reload failed for ${provider_host}; previous certificates restored."
    echo 'SmartDNS hostname certificate deployment failed; previous files restored.' >&2
    exit 1
fi

rm -f "${CERT_DIR}/fullchain.pem.previous" "${CERT_DIR}/privkey.pem.previous"
log "Successfully deployed renewed certificate for ${provider_host} and reloaded Nginx."
HOOK
    chmod 0750 /usr/local/bin/smartdns-hostname-cert-deploy.sh

    install -d -m 0755 /etc/letsencrypt/renewal-hooks/deploy
    # Add dedicated hook file without touching any existing hooks in /etc/letsencrypt/renewal-hooks/deploy/.
    install -m 0750 /usr/local/bin/smartdns-hostname-cert-deploy.sh \
        /etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh

    if systemctl list-unit-files certbot.timer >/dev/null 2>&1; then
        systemctl enable --now certbot.timer >/dev/null 2>&1 || true
    fi
    log_info_tr "certificate.log" "HN_19"
    printf_tr "HN_19"
}

run_noninteractive_hostname_wizard() {
    if [[ -z "${DNS_ENGINE:-}" ]]; then
        if [[ "${CPU_ARCH}" == "x86_64" ]]; then
            DNS_ENGINE="oxidns"
        else
            DNS_ENGINE="adguardhome"
        fi
    fi
    if [[ "${DNS_ENGINE}" == "oxidns" && "${CPU_ARCH}" != "x86_64" ]]; then
        log_error_tr "installation.log" "M_0041" "${CPU_ARCH}"
        return 1
    fi
    if [[ "${DNS_ENGINE}" == "adguardhome" ]]; then
        DNS_USER="adguard"
    else
        DNS_ENGINE="oxidns"
        DNS_USER="oxidns"
    fi

    ROOT_DOMAIN="${PROVIDER_HOSTNAME}"
    DOH_HOST="${ROOT_DOMAIN}"
    DOT_HOST="${ROOT_DOMAIN}"
    CF_API_TOKEN=""
    ACME_EMAIL=""

    if [[ -z "${DOH_PATH:-}" ]]; then
        DOH_PATH="$(generate_random_alnum 52)"
    elif [[ "${#DOH_PATH}" -lt 48 || ! "${DOH_PATH}" =~ ^[A-Za-z0-9]+$ ]]; then
        printf_err_tr "M_0051"
        return 1
    fi

    DOT_WHITELIST_ENABLED="true"
    DOT_WHITELIST_MODE="shared"
    SELECTED_DOMAIN_GROUPS="${SELECTED_DOMAIN_GROUPS:-ALL}"
    EXCLUDE_GOOGLE_SYS="${EXCLUDE_GOOGLE_SYS:-N}"
    INCLUDE_XBOX_IPIFY="${INCLUDE_XBOX_IPIFY:-N}"
    return 0
}

run_interactive_wizard() {
    local existing_dot_wl=""
    local existing_dot_mode="shared"
    if [[ -f "${SETTINGS_FILE}" ]]; then
        existing_dot_wl="$(awk -F'"' '/^DOT_WHITELIST_ENABLED=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || true)"
        existing_dot_mode="$(awk -F'"' '/^DOT_WHITELIST_MODE=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || echo "shared")"
    fi

    printf '\n==============================================================================\n'
    printf_tr "M_0032"
    printf '==============================================================================\n\n'

    printf_tr "M_0033"
    printf '+------------------------+-------------------------------+-------------------------------+\n'
    printf_tr "M_0034"
    printf '+------------------------+-------------------------------+-------------------------------+\n'
    printf_tr "M_0035"
    printf_tr "M_0036"
    printf_tr "M_0037"
    printf_tr "M_0038"
    printf_tr "M_0039"
    printf '+------------------------+-------------------------------+-------------------------------+\n\n'

    while true; do
        read_tr "M_0040" engine_choice
        engine_choice="${engine_choice:-1}"
        if [[ "${engine_choice}" == "1" ]]; then
            if [[ "${CPU_ARCH}" != "x86_64" ]]; then
                printf_tr "M_0041" "${CPU_ARCH}"
                continue
            fi
            DNS_ENGINE="oxidns"
            DNS_USER="oxidns"
            break
        elif [[ "${engine_choice}" == "2" ]]; then
            DNS_ENGINE="adguardhome"
            DNS_USER="adguard"
            break
        else
            printf_tr "M_0042"
        fi
    done

    if is_hostname_profile; then
        ROOT_DOMAIN="${PROVIDER_HOSTNAME}"
        DOH_HOST="${ROOT_DOMAIN}"
        DOT_HOST="${ROOT_DOMAIN}"
        CF_API_TOKEN=""
        ACME_EMAIL=""
        printf_tr "HN_00" "${ROOT_DOMAIN}"
        printf_tr "HN_01"
    else
        while true; do
            read_tr "M_0043" ROOT_DOMAIN
            ROOT_DOMAIN="${ROOT_DOMAIN,,}"
            if validate_domain_syntax "${ROOT_DOMAIN}"; then
                break
            fi
            printf_tr "M_0044"
        done

        DOH_HOST="${ROOT_DOMAIN}"
        printf_tr "M_0045" "${DOH_HOST}"

        local default_dot_prefix
        default_dot_prefix="$(generate_random_lower 10)"
        while true; do
            read_tr "M_0046" DOT_HOST "${default_dot_prefix}" "${ROOT_DOMAIN}"
            DOT_HOST="${DOT_HOST:-${default_dot_prefix}.${ROOT_DOMAIN}}"
            DOT_HOST="${DOT_HOST,,}"
            if validate_domain_syntax "${DOT_HOST}" && [[ "${DOT_HOST}" == *".${ROOT_DOMAIN}" ]] && [[ "${DOT_HOST}" != "${ROOT_DOMAIN}" ]]; then
                break
            fi
            printf_tr "M_0047" "${ROOT_DOMAIN}"
        done
    fi

    printf_tr "M_0048"
    read_tr "M_0049" auto_doh
    auto_doh="${auto_doh:-Y}"
    if [[ "${auto_doh}" =~ ^[Yy]$ ]]; then
        DOH_PATH="$(generate_random_alnum 52)"
    else
        while true; do
            read -r -s -p "$(tr_msg M_0050)" DOH_PATH
            printf '\n'
            if [[ "${#DOH_PATH}" -ge 48 && "${DOH_PATH}" =~ ^[A-Za-z0-9]+$ ]]; then
                break
            fi
            printf_tr "M_0051"
        done
    fi

    if is_hostname_profile; then
        # The DoT SNI equals the public provider hostname, so require IP authorization.
        DOT_WHITELIST_ENABLED="true"
        DOT_WHITELIST_MODE="shared"
        printf_tr "HN_02"
        printf_tr "HN_03"
    else
        printf_tr "M_0052"
        if [[ -n "${existing_dot_wl}" ]]; then
            printf_tr "M_0053" "${existing_dot_wl}" "${existing_dot_mode}"
        fi
        local dot_wl_prompt
        dot_wl_prompt="$(tr_msg "M_0054")"
        read -r -p "${dot_wl_prompt}" dot_wl_choice
        if [[ -z "${dot_wl_choice}" && -n "${existing_dot_wl}" ]]; then
            read_tr "M_0055" keep_existing_wl "${existing_dot_wl}"
            if [[ "${keep_existing_wl:-Y}" =~ ^[Yy]$ ]]; then
                DOT_WHITELIST_ENABLED="${existing_dot_wl}"
                DOT_WHITELIST_MODE="${existing_dot_mode:-shared}"
            else
                DOT_WHITELIST_ENABLED="false"
                DOT_WHITELIST_MODE="shared"
            fi
        elif [[ "${dot_wl_choice:-N}" =~ ^[Yy]$ ]]; then
            DOT_WHITELIST_ENABLED="true"
        else
            DOT_WHITELIST_ENABLED="false"
        fi

        if [[ "${DOT_WHITELIST_ENABLED}" == "true" ]]; then
            printf_tr "M_0056"
            printf_tr "M_0057"
            printf_tr "M_0058"
            read_tr "M_0059" wl_mode_choice
            if [[ "${wl_mode_choice:-1}" == "2" ]]; then
                DOT_WHITELIST_MODE="separate"
            else
                DOT_WHITELIST_MODE="shared"
            fi
        else
            DOT_WHITELIST_MODE="${existing_dot_mode:-shared}"
        fi
    fi

    local existing_groups=""
    if [[ -f "${SETTINGS_FILE}" ]]; then
        existing_groups="$(awk -F'"' '/^SELECTED_DOMAIN_GROUPS=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || true)"
    fi
    if ! prompt_domain_groups_selection "${existing_groups}"; then
        exit 0
    fi
    prompt_custom_domains_import
    cleanup_domain_index_tmp

    if is_hostname_profile; then
        CF_API_TOKEN=""
        ACME_EMAIL=""
    else
        local saved_cf_token=""
        if [[ -f "${SECRETS_FILE}" ]]; then
            saved_cf_token="$(awk -F'"' '/^CF_API_TOKEN=/ {print $2}' "${SECRETS_FILE}" 2>/dev/null || true)"
        fi

        while true; do
            if [[ -n "${saved_cf_token}" && "${saved_cf_token}" != "REUSE_EXISTING_CERT_TOKEN" ]]; then
                read -r -s -p "$(tr_msg M_0068)" CF_API_TOKEN
                printf '\n'
                CF_API_TOKEN="${CF_API_TOKEN:-${saved_cf_token}}"
                break
            else
                read -r -s -p "Введите Cloudflare API Token (с правами Zone:DNS:Edit для синхронизации DNS и выпуска сертификата ${ROOT_DOMAIN}): " CF_API_TOKEN
                printf '\n'
                if [[ -n "${CF_API_TOKEN}" && "${#CF_API_TOKEN}" -ge 20 ]]; then
                    break
                fi
                printf_tr "M_0069"
            fi
        done

        read_tr "M_0070" ACME_EMAIL "${ROOT_DOMAIN}"
        ACME_EMAIL="${ACME_EMAIL:-admin@${ROOT_DOMAIN}}"
    fi

    printf '\n==============================================================================\n'
    printf_tr "M_0071"
    printf '==============================================================================\n'
    printf_tr "M_0072" "${DNS_ENGINE}" "${DNS_USER}"
    printf_tr "M_0073" "${ROOT_DOMAIN}"
    printf_tr "M_0074" "${DOT_HOST}"
    printf_tr "M_0075" "${#DOH_PATH}"
    printf_tr "M_0076" "${DOT_WHITELIST_ENABLED}" "${DOT_WHITELIST_MODE}"
    printf_tr "M_0360" "${SELECTED_DOMAIN_GROUPS}"
    printf_tr "M_0361" "${PENDING_CUSTOM_DOMAINS_COUNT}"
    printf 'EXCLUDE_GOOGLE_SYS         : %s\n' "${EXCLUDE_GOOGLE_SYS}"
    printf 'INCLUDE_XBOX_IPIFY         : %s\n' "${INCLUDE_XBOX_IPIFY}"
    printf_tr "M_0077"
    printf_tr "M_0078"
    printf_tr "M_0079" "${IPTABLES_BACKEND}"
    if [[ "${DOCKER_PRESENT}" -eq 1 ]]; then
        printf_tr "M_0080"
    fi
    printf '==============================================================================\n'

    read_tr "M_0081" confirm_install
    if [[ ! "${confirm_install:-N}" =~ ^[Yy]$ ]]; then
        rm -f "${PENDING_CUSTOM_DOMAINS_FILE:-}" 2>/dev/null || true
        printf_tr "M_0082"
        exit 0
    fi
}

# ------------------------------ Centralized Reboot Lock -----------------------
sanitize_env_value() {
    local val="$1"
    val="${val//$'\n'/ }"
    val="${val//$'\r'/}"
    val="${val//\"/\'}"
    val="${val//\$/}"
    val="${val//\`/}"
    printf '%s' "${val}"
}

save_reboot_lock_state() {
    install -d -m 0700 -o root -g root "${STATE_DIR}"
    local tmp_rl="${REBOOT_LOCK_FILE}.tmp"
    local safe_reasons safe_stage safe_pause_reason safe_ext
    safe_reasons="$(sanitize_env_value "${REBOOT_REASONS:-}")"
    safe_stage="$(sanitize_env_value "${INSTALL_PAUSED_STAGE:-}")"
    safe_pause_reason="$(sanitize_env_value "${INSTALL_PAUSED_REASON:-}")"
    safe_ext="$(sanitize_env_value "${EXTERNAL_REBOOT_TRIGGERS:-}")"

    cat > "${tmp_rl}" <<EOF
REBOOT_LOCKED="${REBOOT_LOCKED:-true}"
SMARTDNS_VERIFIED="${SMARTDNS_VERIFIED:-false}"
REBOOT_ALLOWED="${REBOOT_ALLOWED:-false}"
REBOOT_REQUIRED="${REBOOT_REQUIRED:-false}"
REBOOT_REASONS="${safe_reasons}"
INSTALL_PAUSED="${INSTALL_PAUSED:-false}"
INSTALL_PAUSED_STAGE="${safe_stage}"
INSTALL_PAUSED_REASON="${safe_pause_reason}"
EXTERNAL_REBOOT_TRIGGERS="${safe_ext}"
REBOOT_LOCK_UPDATED_AT="$(date -Is)"
EOF
    chmod 0600 "${tmp_rl}"
    mv -f "${tmp_rl}" "${REBOOT_LOCK_FILE}"
}

load_reboot_lock_state() {
    if [[ -f "${REBOOT_LOCK_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${REBOOT_LOCK_FILE}"
    fi
    REBOOT_LOCKED="${REBOOT_LOCKED:-true}"
    SMARTDNS_VERIFIED="${SMARTDNS_VERIFIED:-false}"
    REBOOT_ALLOWED="${REBOOT_ALLOWED:-false}"
    REBOOT_REQUIRED="${REBOOT_REQUIRED:-false}"
    REBOOT_REASONS="${REBOOT_REASONS:-}"
    INSTALL_PAUSED="${INSTALL_PAUSED:-false}"
    INSTALL_PAUSED_STAGE="${INSTALL_PAUSED_STAGE:-}"
    INSTALL_PAUSED_REASON="${INSTALL_PAUSED_REASON:-}"
    EXTERNAL_REBOOT_TRIGGERS="${EXTERNAL_REBOOT_TRIGGERS:-}"
}

audit_external_reboot_triggers() {
    local found=""
    if grep -RqsE 'Automatic-Reboot[[:space:]]+"true"' /etc/apt/apt.conf.d/ 2>/dev/null; then
        found+="unattended-upgrades:Automatic-Reboot=true; "
    fi

    if grep -RqsE '(^|[[:space:]])(reboot|shutdown[[:space:]]+-r|systemctl[[:space:]]+reboot)' /etc/crontab /etc/cron.d/ /etc/cron.daily/ /etc/cron.hourly/ /var/spool/cron/ 2>/dev/null; then
        found+="cron:reboot-entry; "
    fi
    if grep -RqsE 'ExecStart=.*(reboot|shutdown[[:space:]]+-r)' /etc/systemd/system/*.service 2>/dev/null; then
        found+="systemd:reboot-unit; "
    fi

    EXTERNAL_REBOOT_TRIGGERS="${found%; }"
    if [[ -n "${EXTERNAL_REBOOT_TRIGGERS}" ]]; then
        log_warn_tr "installation.log" "M_0378" "${EXTERNAL_REBOOT_TRIGGERS}"
    fi
}

init_reboot_lock() {
    local mode="${1:-enforce}"
    install -d -m 0700 -o root -g root "${STATE_DIR}"
    load_reboot_lock_state

    if [[ "${mode}" == "force_lock" || "${SMARTDNS_VERIFIED}" != "true" ]]; then
        REBOOT_LOCKED="true"
        SMARTDNS_VERIFIED="false"
        REBOOT_ALLOWED="false"
    fi

    audit_external_reboot_triggers
    save_reboot_lock_state
    log_info_tr "installation.log" "M_0376" "${REBOOT_LOCK_FILE}"
    check_reboot_required || true
}

check_reboot_required() {
    local quiet="${1:-0}"
    local reason_list=""
    local need_reboot=0

    if [[ -f /var/run/reboot-required ]]; then
        need_reboot=1
        if [[ -s /var/run/reboot-required.pkgs ]]; then
            local pkgs
            pkgs="$(sort -u /var/run/reboot-required.pkgs | paste -sd ',' -)"
            reason_list="reboot-required (${pkgs})"
        else
            reason_list="reboot-required (/var/run/reboot-required)"
        fi
    fi

    local running_kern
    running_kern="$(uname -r 2>/dev/null || true)"
    if [[ -n "${running_kern}" && ! -d "/lib/modules/${running_kern}" ]]; then
        need_reboot=1
        if [[ -n "${reason_list}" ]]; then
            reason_list+="; "
        fi
        reason_list+="kernel-modules-missing-for-${running_kern}"
    fi

    if [[ "${need_reboot}" -eq 1 ]]; then
        REBOOT_REQUIRED="true"
        if [[ -z "${REBOOT_REASONS}" ]]; then
            REBOOT_REASONS="${reason_list}"
        elif [[ "${REBOOT_REASONS}" != *"${reason_list}"* ]]; then
            REBOOT_REASONS="${REBOOT_REASONS}; ${reason_list}"
        fi
        save_reboot_lock_state
        if [[ "${quiet}" != "1" ]]; then
            printf_tr "M_0377" "${REBOOT_REASONS}"
        fi
        return 0
    fi
    if [[ "${REBOOT_REQUIRED}" == "true" ]]; then
        REBOOT_REQUIRED="false"
        REBOOT_REASONS=""
        save_reboot_lock_state
    fi
    return 1
}

check_safe_to_continue_without_reboot() {
    UNSAFE_CONTINUE_REASON=""
    if command -v dpkg >/dev/null 2>&1; then
        local dpkg_issues
        dpkg_issues="$(dpkg --audit 2>/dev/null || true)"
        if [[ -n "${dpkg_issues}" ]]; then
            UNSAFE_CONTINUE_REASON="dpkg --audit reported unconfigured or broken packages"
            log_error_tr "installation.log" "M_0379" "${UNSAFE_CONTINUE_REASON}"
            return 1
        fi
    fi

    local running_kern
    running_kern="$(uname -r 2>/dev/null || true)"
    if [[ -n "${running_kern}" && ! -d "/lib/modules/${running_kern}" ]]; then
        if ! grep -q '^ip_set ' /proc/modules 2>/dev/null; then
            UNSAFE_CONTINUE_REASON="modules directory /lib/modules/${running_kern} missing and ip_set not loaded"
            log_error_tr "installation.log" "M_0379" "${UNSAFE_CONTINUE_REASON}"
            return 1
        fi
    fi
    return 0
}

pause_install_for_recovery() {
    local stage="$1"
    local reason="$2"
    REBOOT_LOCKED="true"
    SMARTDNS_VERIFIED="false"
    REBOOT_ALLOWED="false"
    INSTALL_PAUSED="true"
    INSTALL_PAUSED_STAGE="${stage}"
    INSTALL_PAUSED_REASON="${reason}"
    save_reboot_lock_state
    log_warn "installation.log" "Установка приостановлена на этапе ${stage}: ${reason}"
    printf_tr "M_0380" "${stage}" "${reason}" "${REBOOT_LOCK_FILE}" "${LOG_DIR}" "${SCRIPT_NAME}"
}

assert_reboot_allowed() {
    load_reboot_lock_state
    if [[ "${REBOOT_LOCKED}" == "false" && "${SMARTDNS_VERIFIED}" == "true" && "${REBOOT_ALLOWED}" == "true" ]]; then
        return 0
    fi
    return 1
}

unlock_reboot_after_smartdns() {
    local dns_tests_passed="${1:-0}"
    local fail_reason=""

    if [[ "${dns_tests_passed}" != "1" ]]; then
        fail_reason="DNS test suite not confirmed"
    elif [[ ! -f "${SETTINGS_FILE}" ]]; then
        fail_reason="settings file missing"
    elif [[ -z "${DNS_ENGINE:-}" ]]; then
        fail_reason="DNS_ENGINE undefined"
    elif [[ "${DNS_ENGINE}" == "oxidns" && ! -s /etc/oxidns/config.yaml ]]; then
        fail_reason="OxiDNS config missing"
    elif [[ "${DNS_ENGINE}" == "adguardhome" && ! -s /etc/adguardhome/AdGuardHome.yaml ]]; then
        fail_reason="AdGuardHome config missing"
    elif [[ "${DNS_ENGINE}" == "oxidns" ]] && ! /usr/local/bin/oxidns check -c /etc/oxidns/config.yaml -d /var/lib/oxidns >/dev/null 2>&1; then
        fail_reason="OxiDNS config validation failed"
    elif ! systemctl is-active --quiet "${DNS_ENGINE}" 2>/dev/null; then
        fail_reason="service ${DNS_ENGINE} is not active"
    elif ! ss -ulnp 2>/dev/null | grep -q "127.0.0.1:5353 " || ! ss -tlnp 2>/dev/null | grep -q "127.0.0.1:8053 "; then
        fail_reason="SmartDNS local sockets 5353/8053 not listening"
    else
        local live_a
        live_a="$(dig +time=3 +tries=1 +short @127.0.0.1 -p 5353 example.com A 2>/dev/null | sed -n '1p' || true)"
        if ! validate_single_ipv4 "${live_a}"; then
            fail_reason="live DNS resolution check failed"
        fi
    fi

    if [[ -n "${fail_reason}" ]]; then
        REBOOT_LOCKED="true"
        SMARTDNS_VERIFIED="false"
        REBOOT_ALLOWED="false"
        save_reboot_lock_state
        log_error_tr "installation.log" "M_0381" "${fail_reason}"
        return 1
    fi

    REBOOT_LOCKED="false"
    SMARTDNS_VERIFIED="true"
    REBOOT_ALLOWED="true"
    INSTALL_PAUSED="false"
    INSTALL_PAUSED_STAGE=""
    INSTALL_PAUSED_REASON=""
    save_reboot_lock_state
    log_info_tr "installation.log" "M_0382" "${DNS_ENGINE}"
    return 0
}

prompt_deferred_reboot_if_needed() {
    check_reboot_required 1 || true
    load_reboot_lock_state

    if [[ "${REBOOT_REQUIRED}" != "true" ]]; then
        return 0
    fi

    if ! assert_reboot_allowed; then
        log_error_tr "installation.log" "M_0386"
        return 0
    fi

    if [[ ! -t 0 ]]; then
        printf_tr "M_0384"
        return 0
    fi

    local confirm_reboot=""
    read_tr "M_0383" confirm_reboot "${REBOOT_REASONS:-system updates}"
    if [[ "${LAST_READ_EOF}" -eq 1 || "${confirm_reboot}" != "YES" ]]; then
        printf_tr "M_0384"
        return 0
    fi

    if ! assert_reboot_allowed; then
        log_error_tr "installation.log" "M_0386"
        return 1
    fi

    log_warn_tr "installation.log" "M_0385"
    systemctl reboot
}

# ------------------------------ Initial Server Setup (State & Modules 2-4) ----
load_initial_setup_state() {
    if [[ -f "${INITIAL_SETUP_STATE_FILE}" ]]; then
        # shellcheck disable=SC1090
        source "${INITIAL_SETUP_STATE_FILE}"
    fi
    INITIAL_SETUP_COMPLETED="${INITIAL_SETUP_COMPLETED:-false}"
    INITIAL_SETUP_OS_UPDATED="${INITIAL_SETUP_OS_UPDATED:-false}"
    INITIAL_SETUP_SUDO_OK="${INITIAL_SETUP_SUDO_OK:-false}"
    INITIAL_SETUP_ROOT_PASS_CHANGED="${INITIAL_SETUP_ROOT_PASS_CHANGED:-false}"
    INITIAL_SETUP_ADMIN_USER="${INITIAL_SETUP_ADMIN_USER:-}"
    INITIAL_SETUP_ADMIN_IN_SUDO="${INITIAL_SETUP_ADMIN_IN_SUDO:-false}"
    INITIAL_SETUP_SSH_PORT="${INITIAL_SETUP_SSH_PORT:-}"
    INITIAL_SETUP_SSH_ORIG_PORT="${INITIAL_SETUP_SSH_ORIG_PORT:-}"
    INITIAL_SETUP_SSH_KEY_OK="${INITIAL_SETUP_SSH_KEY_OK:-false}"
    INITIAL_SETUP_SSH_KEY_CONFIRMED="${INITIAL_SETUP_SSH_KEY_CONFIRMED:-false}"
    INITIAL_SETUP_PASSAUTH_DISABLED="${INITIAL_SETUP_PASSAUTH_DISABLED:-false}"
    INITIAL_SETUP_ROOTLOGIN_DISABLED="${INITIAL_SETUP_ROOTLOGIN_DISABLED:-false}"
    SSH_HARDENING_CRYPTO="${SSH_HARDENING_CRYPTO:-false}"
    INITIAL_SETUP_ACTIONS_DONE="${INITIAL_SETUP_ACTIONS_DONE:-}"
    INITIAL_SETUP_CHECKS_SUMMARY="${INITIAL_SETUP_CHECKS_SUMMARY:-}"
}

save_initial_setup_state() {
    install -d -m 0700 -o root -g root "${STATE_DIR}"
    local tmp_is="${INITIAL_SETUP_STATE_FILE}.tmp"
    local safe_actions safe_checks safe_user
    safe_actions="$(sanitize_env_value "${INITIAL_SETUP_ACTIONS_DONE:-}")"
    safe_checks="$(sanitize_env_value "${INITIAL_SETUP_CHECKS_SUMMARY:-}")"
    safe_user="$(sanitize_env_value "${INITIAL_SETUP_ADMIN_USER:-}")"

    cat > "${tmp_is}" <<EOF
INITIAL_SETUP_COMPLETED="${INITIAL_SETUP_COMPLETED:-false}"
INITIAL_SETUP_OS_UPDATED="${INITIAL_SETUP_OS_UPDATED:-false}"
INITIAL_SETUP_SUDO_OK="${INITIAL_SETUP_SUDO_OK:-false}"
INITIAL_SETUP_ROOT_PASS_CHANGED="${INITIAL_SETUP_ROOT_PASS_CHANGED:-false}"
INITIAL_SETUP_ADMIN_USER="${safe_user}"
INITIAL_SETUP_ADMIN_IN_SUDO="${INITIAL_SETUP_ADMIN_IN_SUDO:-false}"
INITIAL_SETUP_SSH_PORT="${INITIAL_SETUP_SSH_PORT:-}"
INITIAL_SETUP_SSH_ORIG_PORT="${INITIAL_SETUP_SSH_ORIG_PORT:-}"
INITIAL_SETUP_SSH_KEY_OK="${INITIAL_SETUP_SSH_KEY_OK:-false}"
INITIAL_SETUP_SSH_KEY_CONFIRMED="${INITIAL_SETUP_SSH_KEY_CONFIRMED:-false}"
INITIAL_SETUP_PASSAUTH_DISABLED="${INITIAL_SETUP_PASSAUTH_DISABLED:-false}"
INITIAL_SETUP_ROOTLOGIN_DISABLED="${INITIAL_SETUP_ROOTLOGIN_DISABLED:-false}"
SSH_HARDENING_CRYPTO="${SSH_HARDENING_CRYPTO:-false}"
INITIAL_SETUP_ACTIONS_DONE="${safe_actions}"
INITIAL_SETUP_CHECKS_SUMMARY="${safe_checks}"
INITIAL_SETUP_UPDATED_AT="$(date -Is)"
EOF
    chmod 0600 "${tmp_is}"
    mv -f "${tmp_is}" "${INITIAL_SETUP_STATE_FILE}"
}

initial_setup_record_action() {
    local act="$1"
    if [[ ",${INITIAL_SETUP_ACTIONS_DONE}," != *",${act},"* ]]; then
        if [[ -n "${INITIAL_SETUP_ACTIONS_DONE}" ]]; then
            INITIAL_SETUP_ACTIONS_DONE="${INITIAL_SETUP_ACTIONS_DONE},${act}"
        else
            INITIAL_SETUP_ACTIONS_DONE="${act}"
        fi
    fi
    save_initial_setup_state
}

initial_setup_record_check() {
    local kv="$1"
    if [[ "; ${INITIAL_SETUP_CHECKS_SUMMARY}; " != *"; ${kv}; "* ]]; then
        if [[ -n "${INITIAL_SETUP_CHECKS_SUMMARY}" ]]; then
            INITIAL_SETUP_CHECKS_SUMMARY="${INITIAL_SETUP_CHECKS_SUMMARY}; ${kv}"
        else
            INITIAL_SETUP_CHECKS_SUMMARY="${kv}"
        fi
    fi
    save_initial_setup_state
}

# --- Step 1: Full OS Update (no reboot, non-interactive) ---
initial_setup_os_update() {
    printf_tr "M_0387"

    if [[ "${INITIAL_SETUP_OS_UPDATED}" == "true" ]]; then
        local rerun_upd=""
        read_tr "M_0388" rerun_upd
        if [[ "${LAST_READ_EOF}" -eq 1 || ! "${rerun_upd:-N}" =~ ^[Yy]$ ]]; then
            return 0
        fi
    fi

    local free_mb
    free_mb="$(df -Pm / /var /usr 2>/dev/null | awk 'NR==2 {print $4}')"
    free_mb="${free_mb:-0}"
    if [[ "${free_mb}" -lt 1500 ]]; then
        printf_err_tr "M_0389" "${free_mb}"
        log_error "installation.log" "Недостаточно места для обновления ОС: ${free_mb} MB."
        return 1
    fi

    printf_tr "M_0390"
    if ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -y -q; then
        printf_err_tr "M_0391"
        log_error "installation.log" "Ошибка apt-get update на этапе Initial Server Setup."
        pause_install_for_recovery "initial-setup:os-update" "apt-get update failed"
        return 2
    fi

    local upgradable_cnt
    upgradable_cnt="$(apt list --upgradable 2>/dev/null | grep -c 'upgradable' || true)"
    upgradable_cnt="${upgradable_cnt:-0}"

    if [[ "${upgradable_cnt}" -eq 0 ]]; then
        printf_tr "M_0392"
        INITIAL_SETUP_OS_UPDATED="true"
        initial_setup_record_action "os_update_checked_clean"
        check_reboot_required || true
        return 0
    fi

    printf_tr "M_0393" "${upgradable_cnt}"
    local confirm_upd=""
    read_tr "M_0394" confirm_upd
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_upd:-N}" =~ ^[Yy]$ ]]; then
        printf_tr "M_0395"
        return 0
    fi

    printf_tr "M_0396"
    log_info "installation.log" "Запуск non-interactive apt-get upgrade (пакетов: ${upgradable_cnt}, reboot заблокирован)."
    if ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 \
        apt-get -y -q -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold" upgrade; then
        log_error "installation.log" "Ошибка выполнения apt-get upgrade."
        pause_install_for_recovery "initial-setup:os-update" "apt-get upgrade failed; resolve with dpkg --configure -a"
        return 2
    fi

    printf_tr "M_0397"
    INITIAL_SETUP_OS_UPDATED="true"
    initial_setup_record_action "os_updated(${upgradable_cnt})"

    # Безопасная проверка autoremove без удаления критических пакетов
    local autoremove_pkgs
    autoremove_pkgs="$(apt-get --simulate autoremove 2>/dev/null | awk '/^Remv / {print $2}' | paste -sd ' ' - || true)"
    if [[ -n "${autoremove_pkgs}" ]]; then
        local crit_hits
        crit_hits="$(tr ' ' '\n' <<<"${autoremove_pkgs}" | grep -E '^(openssh-server|openssh-client|sudo|systemd|ufw|nginx|iptables|linux-image|libc6|bash)$' | paste -sd ',' - || true)"
        if [[ -n "${crit_hits}" ]]; then
            printf_tr "M_0400" "${crit_hits}"
            log_warn "installation.log" "autoremove пропущен: найдены критические пакеты (${crit_hits})."
        else
            printf_tr "M_0398" "${autoremove_pkgs}"
            local confirm_ar=""
            read_tr "M_0399" confirm_ar
            if [[ "${LAST_READ_EOF}" -eq 0 && "${confirm_ar:-N}" =~ ^[Yy]$ ]]; then
                DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get autoremove -y -q || true
                initial_setup_record_action "apt_autoremove"
            fi
        fi
    fi

    check_reboot_required || true
    if ! check_safe_to_continue_without_reboot; then
        pause_install_for_recovery "initial-setup:os-update" "${UNSAFE_CONTINUE_REASON}"
        return 2
    fi
    return 0
}

# --- Step 2: Check / Install sudo ---
initial_setup_check_sudo() {
    printf_tr "M_0401"

    local sudo_bin=""
    sudo_bin="$(command -v sudo 2>/dev/null || true)"
    if [[ -n "${sudo_bin}" ]] && dpkg-query -W -f='${Status}' sudo 2>/dev/null | grep -q 'install ok installed'; then
        if sudo -V >/dev/null 2>&1; then
            printf_tr "M_0402" "${sudo_bin}"
            INITIAL_SETUP_SUDO_OK="true"
            initial_setup_record_check "sudo=installed"
            return 0
        fi
    fi

    printf_tr "M_0403"
    local confirm_sudo=""
    read_tr "M_0404" confirm_sudo
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_sudo:-Y}" =~ ^[Yy]$ ]]; then
        initial_setup_record_check "sudo=skipped"
        return 0
    fi

    if ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -y -q \
        || ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get install -y -q sudo; then
        printf_err_tr "M_0406"
        log_error "installation.log" "Не удалось установить пакет sudo."
        return 1
    fi

    if command -v sudo >/dev/null 2>&1 && sudo -V >/dev/null 2>&1; then
        printf_tr "M_0405"
        INITIAL_SETUP_SUDO_OK="true"
        initial_setup_record_action "sudo_installed"
        initial_setup_record_check "sudo=installed"
        return 0
    fi

    printf_err_tr "M_0406"
    return 1
}

# --- Step 3: Root Password Change ---
initial_setup_root_password() {
    printf_tr "M_0407"
    local confirm_rp=""
    read_tr "M_0408" confirm_rp
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_rp:-N}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    if [[ ! -t 0 ]]; then
        printf_tr "M_0409"
        return 0
    fi

    if passwd root; then
        printf_tr "M_0410"
        INITIAL_SETUP_ROOT_PASS_CHANGED="true"
        initial_setup_record_action "root_password_changed"
        log_info "installation.log" "Пароль учётной записи root успешно обновлён (интерактивно через passwd)."
    else
        printf_tr "M_0411"
        log_warn "installation.log" "Смена пароля root не завершена."
    fi
    return 0
}

# --- Step 4: Admin User Creation / Selection & Sudo Membership ---
validate_admin_username() {
    local uname="$1"
    [[ "${uname}" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] || return 1
    case "${uname}" in
        root|daemon|bin|sys|sync|games|man|lp|mail|news|uucp|proxy|www-data|backup|list|irc|gnats|nobody|_apt|sshd|xray|oxidns|adguard|systemd-*)
            return 1
            ;;
    esac
    return 0
}

user_in_sudo_group() {
    local uname="$1"
    id -nG "${uname}" 2>/dev/null | tr ' ' '\n' | grep -qx 'sudo'
}

initial_setup_add_user_sudo() {
    local target_user="${1:-${INITIAL_SETUP_ADMIN_USER:-}}"
    printf_tr "M_0425"

    if [[ -z "${target_user}" ]]; then
        read_tr "M_0431" target_user
        if [[ "${LAST_READ_EOF}" -eq 1 || -z "${target_user}" ]]; then
            return 0
        fi
    fi

    if ! validate_admin_username "${target_user}"; then
        printf_err_tr "M_0416" "${target_user}"
        return 1
    fi
    if ! id -u "${target_user}" >/dev/null 2>&1; then
        printf_err_tr "M_0432" "${target_user}"
        return 1
    fi

    local target_uid
    target_uid="$(id -u "${target_user}")"
    if [[ "${target_uid}" -lt 1000 ]]; then
        printf_err_tr "M_0418" "${target_user}" "${target_uid}"
        return 1
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        initial_setup_check_sudo || return 1
    fi
    if ! getent group sudo >/dev/null 2>&1; then
        printf_err_tr "M_0429"
        return 1
    fi

    if user_in_sudo_group "${target_user}"; then
        printf_tr "M_0426" "${target_user}"
        INITIAL_SETUP_ADMIN_USER="${target_user}"
        INITIAL_SETUP_ADMIN_IN_SUDO="true"
        initial_setup_record_check "sudo_user=${target_user}"
        return 0
    fi

    local confirm_add_sudo=""
    read_tr "M_0427" confirm_add_sudo "${target_user}"
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_add_sudo:-Y}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    usermod -aG sudo "${target_user}"

    # Проверяем наличие активного правила %sudo и целостность sudoers
    if ! grep -Eq '^[[:space:]]*%sudo[[:space:]]+' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
        install -d -m 0750 /etc/sudoers.d
        printf '%%sudo\tALL=(ALL:ALL) ALL\n' > /etc/sudoers.d/90-smartdns-sudo-group
        chmod 0440 /etc/sudoers.d/90-smartdns-sudo-group
        if command -v visudo >/dev/null 2>&1 && ! visudo -cf /etc/sudoers.d/90-smartdns-sudo-group >/dev/null 2>&1; then
            rm -f /etc/sudoers.d/90-smartdns-sudo-group
            printf_err_tr "M_0430"
            return 1
        fi
    fi

    if command -v visudo >/dev/null 2>&1 && ! visudo -c >/dev/null 2>&1; then
        rm -f /etc/sudoers.d/90-smartdns-sudo-group 2>/dev/null || true
        printf_err_tr "M_0430"
        return 1
    fi

    if user_in_sudo_group "${target_user}"; then
        printf_tr "M_0428" "${target_user}"
        INITIAL_SETUP_ADMIN_USER="${target_user}"
        INITIAL_SETUP_ADMIN_IN_SUDO="true"
        initial_setup_record_action "user_added_to_sudo(${target_user})"
        initial_setup_record_check "sudo_user=${target_user}"
        log_info "installation.log" "Пользователь ${target_user} добавлен в группу sudo."
        return 0
    fi
    return 1
}

initial_setup_admin_user() {
    printf_tr "M_0412"

    if [[ -n "${INITIAL_SETUP_ADMIN_USER}" ]] && id -u "${INITIAL_SETUP_ADMIN_USER}" >/dev/null 2>&1; then
        local keep_u=""
        read_tr "M_0413" keep_u "${INITIAL_SETUP_ADMIN_USER}"
        if [[ "${LAST_READ_EOF}" -eq 1 || "${keep_u:-Y}" =~ ^[Yy]$ ]]; then
            initial_setup_add_user_sudo "${INITIAL_SETUP_ADMIN_USER}" || true
            return 0
        fi
    fi

    local want_user=""
    read_tr "M_0414" want_user
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${want_user:-N}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    local new_user=""
    while true; do
        read_tr "M_0415" new_user
        if [[ "${LAST_READ_EOF}" -eq 1 || -z "${new_user}" ]]; then
            return 0
        fi
        new_user="${new_user,,}"
        if ! validate_admin_username "${new_user}"; then
            printf_err_tr "M_0416" "${new_user}"
            continue
        fi

        if id -u "${new_user}" >/dev/null 2>&1; then
            local ex_uid ex_home ex_shell ex_sudo="no"
            ex_uid="$(id -u "${new_user}")"
            ex_home="$(getent passwd "${new_user}" | cut -d: -f6)"
            ex_shell="$(getent passwd "${new_user}" | cut -d: -f7)"
            if user_in_sudo_group "${new_user}"; then ex_sudo="yes"; fi

            if [[ "${ex_uid}" -lt 1000 ]]; then
                printf_err_tr "M_0418" "${new_user}" "${ex_uid}"
                continue
            fi

            printf_tr "M_0417" "${new_user}" "${ex_uid}" "${ex_home}" "${ex_shell}" "${ex_sudo}"
            local use_ex=""
            read_tr "M_0419" use_ex "${new_user}"
            if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
                return 0
            fi
            if [[ "${use_ex:-Y}" =~ ^[Yy]$ ]]; then
                INITIAL_SETUP_ADMIN_USER="${new_user}"
                if [[ "${ex_sudo}" == "yes" ]]; then
                    INITIAL_SETUP_ADMIN_IN_SUDO="true"
                else
                    INITIAL_SETUP_ADMIN_IN_SUDO="false"
                fi
                save_initial_setup_state
                initial_setup_add_user_sudo "${new_user}" || true
                return 0
            fi
            continue
        fi

        local full_name=""
        read_tr "M_0420" full_name
        if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
            return 0
        fi
        full_name="${full_name//:/ }"

        local confirm_create=""
        read_tr "M_0421" confirm_create "${new_user}"
        if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_create:-Y}" =~ ^[Yy]$ ]]; then
            return 0
        fi

        if [[ -n "${full_name}" ]]; then
            if ! useradd -m -s /bin/bash -c "${full_name}" "${new_user}"; then
                printf_err_tr "M_0424" "${new_user}"
                return 1
            fi
        else
            if ! useradd -m -s /bin/bash "${new_user}"; then
                printf_err_tr "M_0424" "${new_user}"
                return 1
            fi
        fi

        local created_uid created_home
        created_uid="$(id -u "${new_user}")"
        created_home="$(getent passwd "${new_user}" | cut -d: -f6)"
        if [[ -d "${created_home}" ]]; then
            chmod 0750 "${created_home}" 2>/dev/null || true
        fi

        if [[ -t 0 ]]; then
            printf_tr "M_0422" "${new_user}"
            local pass_try=0
            while [[ "${pass_try}" -lt 3 ]]; do
                if passwd "${new_user}"; then
                    break
                fi
                pass_try=$((pass_try + 1))
            done
        else
            printf_tr "M_0409"
        fi

        printf_tr "M_0423" "${new_user}" "${created_uid}" "${created_home}"
        INITIAL_SETUP_ADMIN_USER="${new_user}"
        INITIAL_SETUP_ADMIN_IN_SUDO="false"
        initial_setup_record_action "user_created(${new_user})"
        log_info "installation.log" "Создан административный пользователь ${new_user} (UID=${created_uid})."
        initial_setup_add_user_sudo "${new_user}" || true
        return 0
    done
}

# ------------------------------ SSH Hardening Engine (Module 5) ---------------
ssh_is_installed() {
    command -v sshd >/dev/null 2>&1 && [[ -f /etc/ssh/sshd_config ]]
}

ssh_ensure_runtime_dir() {
    if [[ ! -d /run/sshd ]]; then
        install -d -m 0755 -o root -g root /run/sshd
    fi
}

ssh_get_effective_param() {
    local param_name="$1"
    local test_user="${2:-}"
    ssh_ensure_runtime_dir
    local out=""
    if [[ -n "${test_user}" ]]; then
        out="$(sshd -T -C "user=${test_user},host=localhost,addr=127.0.0.1" 2>/dev/null || sshd -T 2>/dev/null || true)"
    else
        out="$(sshd -T 2>/dev/null || true)"
    fi
    awk -v k="${param_name,,}" 'tolower($1) == k { $1=""; sub(/^[[:space:]]+/, ""); print; exit }' <<<"${out}"
}

ssh_get_all_effective_ports() {
    ssh_ensure_runtime_dir
    local ports=""
    if command -v sshd >/dev/null 2>&1; then
        ports="$(sshd -T 2>/dev/null | awk 'tolower($1) == "port" { print $2 }' | sort -nu | paste -sd ' ' - || true)"
    fi
    if [[ "${SSH_SOCKET_ACTIVE:-0}" -eq 1 ]]; then
        local sock_ports
        sock_ports="$(systemctl cat ssh.socket 2>/dev/null | awk -F= '/^[[:space:]]*ListenStream=/ {
            v=$2; gsub(/^[[:space:]]+|[[:space:]]+$/, "", v);
            if (v == "") { delete p; next }
            sub(/^.*:/, "", v);
            if (v ~ /^[0-9]+$/) p[v]=1
        } END { for (k in p) print k }' | sort -nu | paste -sd ' ' - || true)"
        if [[ -n "${sock_ports}" ]]; then
            ports="${sock_ports}"
        fi
    fi
    if [[ -z "${ports}" ]]; then
        ports="$(ss -tlnp 2>/dev/null | awk '/(sshd|ssh\.socket)/ {split($4,a,":"); print a[length(a)]}' | sort -nu | paste -sd ' ' - || true)"
    fi
    printf '%s' "${ports:-22}"
}

ssh_detect_state() {
    SSH_SERVICE_NAME="ssh"
    if systemctl list-unit-files sshd.service 2>/dev/null | grep -q '^sshd\.service'; then
        if ! systemctl list-unit-files ssh.service 2>/dev/null | grep -q '^ssh\.service'; then
            SSH_SERVICE_NAME="sshd"
        fi
    fi

    SSH_SOCKET_ACTIVE=0
    if systemctl is-active --quiet ssh.socket 2>/dev/null || systemctl is-enabled --quiet ssh.socket 2>/dev/null; then
        SSH_SOCKET_ACTIVE=1
    fi

    SSH_CURRENT_PORTS="$(ssh_get_all_effective_ports)"
    if [[ -z "${INITIAL_SETUP_SSH_ORIG_PORT}" ]]; then
        INITIAL_SETUP_SSH_ORIG_PORT="$(awk '{print $1}' <<<"${SSH_CURRENT_PORTS}")"
    fi
    if [[ -z "${INITIAL_SETUP_SSH_PORT}" ]]; then
        INITIAL_SETUP_SSH_PORT="$(awk '{print $1}' <<<"${SSH_CURRENT_PORTS}")"
    fi

    if [[ -z "${SSH_DESIRED_PORTS}" ]]; then
        SSH_DESIRED_PORTS="${SSH_CURRENT_PORTS}"
    fi
    if [[ -z "${SSH_DESIRED_PUBKEY}" ]]; then
        SSH_DESIRED_PUBKEY="$(ssh_get_effective_param "pubkeyauthentication")"
        SSH_DESIRED_PUBKEY="${SSH_DESIRED_PUBKEY:-yes}"
    fi
    if [[ -z "${SSH_DESIRED_PASSAUTH}" ]]; then
        SSH_DESIRED_PASSAUTH="$(ssh_get_effective_param "passwordauthentication")"
        SSH_DESIRED_PASSAUTH="${SSH_DESIRED_PASSAUTH:-yes}"
    fi
    if [[ -z "${SSH_DESIRED_ROOTLOGIN}" ]]; then
        SSH_DESIRED_ROOTLOGIN="$(ssh_get_effective_param "permitrootlogin")"
        SSH_DESIRED_ROOTLOGIN="${SSH_DESIRED_ROOTLOGIN:-prohibit-password}"
    fi
}

ssh_backup_single_dir_to() {
    local target_dir="$1"
    install -d -m 0700 -o root -g root "${target_dir}" "${target_dir}/fs"
    local mf="${target_dir}/manifest.tsv"
    cat > "${mf}" <<EOF
# SSH_BACKUP_CREATED=$(date -Is)
# INSTALLER_VERSION=${INSTALLER_VERSION}
# PATH	TYPE	MODE	OWNER	GROUP	LINK_TARGET	SHA256	REL_PATH
EOF
    chmod 0600 "${mf}"

    local count=0
    local src_item entry rel dest ftype mode_v own_v grp_v lt sha_v
    for src_item in /etc/ssh/sshd_config /etc/ssh/sshd_config.d "${SSH_SOCKET_DROPIN_DIR}"; do
        if [[ ! -e "${src_item}" && ! -L "${src_item}" ]]; then
            continue
        fi
        while IFS= read -r -d '' entry; do
            rel="${entry#/}"
            dest="${target_dir}/fs/${rel}"
            mkdir -p "$(dirname "${dest}")"
            mode_v="$(stat -c '%a' "${entry}" 2>/dev/null || echo "0644")"
            own_v="$(stat -c '%U' "${entry}" 2>/dev/null || echo "root")"
            grp_v="$(stat -c '%G' "${entry}" 2>/dev/null || echo "root")"
            lt="-"
            if [[ -L "${entry}" ]]; then
                ftype="symlink"
                lt="$(readlink "${entry}")"
                sha_v="symlink"
                cp -a --no-dereference "${entry}" "${dest}" || return 1
            elif [[ -f "${entry}" ]]; then
                ftype="file"
                sha_v="$(sha256sum "${entry}" | awk '{print $1}')"
                cp -a "${entry}" "${dest}" || return 1
                local chk_sha
                chk_sha="$(sha256sum "${dest}" | awk '{print $1}')"
                if [[ "${chk_sha}" != "${sha_v}" ]]; then
                    return 1
                fi
            else
                continue
            fi
            printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
                "${entry}" "${ftype}" "${mode_v}" "${own_v}" "${grp_v}" "${lt}" "${sha_v}" "fs/${rel}" >> "${mf}"
            count=$((count + 1))
        done < <(find "${src_item}" \( -type f -o -type l \) -print0 2>/dev/null)
    done
    log_info_tr "installation.log" "M_0433" "${target_dir}" "${count}"
    return 0
}

ssh_backup_config() {
    install -d -m 0700 -o root -g root "${SSH_BACKUP_ROOT}"
    if [[ ! -f "${SSH_BACKUP_ROOT}/initial/.sealed" ]]; then
        if ! ssh_backup_single_dir_to "${SSH_BACKUP_ROOT}/initial"; then
            log_error_tr "installation.log" "M_0434"
            return 1
        fi
        printf 'SEALED_AT=%s\n' "$(date -Is)" > "${SSH_BACKUP_ROOT}/initial/.sealed"
        chmod 0400 "${SSH_BACKUP_ROOT}/initial/.sealed"
    fi

    local ts_now
    ts_now="$(date +%Y%m%d-%H%M%S)"
    SSH_LAST_BACKUP_DIR="${SSH_BACKUP_ROOT}/backup-${ts_now}-$$"
    if ! ssh_backup_single_dir_to "${SSH_LAST_BACKUP_DIR}"; then
        log_error_tr "installation.log" "M_0434"
        return 1
    fi
    return 0
}

ssh_rollback_config() {
    local bdir="${1:-${SSH_LAST_BACKUP_DIR:-}}"
    if [[ -z "${bdir}" || ! -d "${bdir}" ]]; then
        return 1
    fi

    # Удаляем управляемые файлы, если их не было в этом backup
    if [[ ! -e "${bdir}/fs${SSH_HARDENING_CONF}" ]]; then
        rm -f "${SSH_HARDENING_CONF}"
    fi
    if [[ ! -e "${bdir}/fs${SSH_SOCKET_DROPIN_FILE}" ]]; then
        rm -f "${SSH_SOCKET_DROPIN_FILE}"
        rmdir "${SSH_SOCKET_DROPIN_DIR}" 2>/dev/null || true
    fi

    if [[ -d "${bdir}/fs" ]]; then
        local orig_p ftype mode_v own_v grp_v lt sha_v rel_p
        while IFS=$'\t' read -r orig_p ftype mode_v own_v grp_v lt sha_v rel_p; do
            [[ -z "${orig_p}" || "${orig_p}" == \#* ]] && continue
            mkdir -p "$(dirname "${orig_p}")"
            if [[ "${ftype}" == "file" && -f "${bdir}/${rel_p}" ]]; then
                cp -a "${bdir}/${rel_p}" "${orig_p}.rb.tmp"
                mv -f "${orig_p}.rb.tmp" "${orig_p}"
                chown "${own_v}:${grp_v}" "${orig_p}" 2>/dev/null || true
                chmod "${mode_v}" "${orig_p}" 2>/dev/null || true
            elif [[ "${ftype}" == "symlink" ]]; then
                rm -f "${orig_p}"
                ln -s "${lt}" "${orig_p}"
            fi
        done < "${bdir}/manifest.tsv"
    fi

    systemctl daemon-reload 2>/dev/null || true
    ssh_ensure_runtime_dir
    if sshd -t >/dev/null 2>&1; then
        if [[ "${SSH_SOCKET_ACTIVE:-0}" -eq 1 ]]; then
            systemctl restart ssh.socket 2>/dev/null || true
        fi
        systemctl reload "${SSH_SERVICE_NAME}" 2>/dev/null || systemctl restart "${SSH_SERVICE_NAME}" 2>/dev/null || true
        log_info_tr "installation.log" "M_0436" "${bdir}"
        return 0
    fi
    return 1
}

ssh_ensure_include_directive() {
    if [[ ! -f /etc/ssh/sshd_config ]]; then
        return 1
    fi
    install -d -m 0755 -o root -g root /etc/ssh/sshd_config.d

    if grep -Eq '^[[:space:]]*Match[[:space:]]+' /etc/ssh/sshd_config /etc/ssh/sshd_config.d/*.conf 2>/dev/null; then
        log_warn_tr "installation.log" "M_0438"
    fi

    if ! grep -Eq '^[[:space:]]*Include[[:space:]]+/etc/ssh/sshd_config\.d/\*\.conf' /etc/ssh/sshd_config 2>/dev/null; then
        local tmp_main="/etc/ssh/sshd_config.v3.tmp"
        {
            printf 'Include /etc/ssh/sshd_config.d/*.conf\n'
            cat /etc/ssh/sshd_config
        } > "${tmp_main}"
        chmod 0644 "${tmp_main}"
        mv -f "${tmp_main}" /etc/ssh/sshd_config
    fi
    return 0
}

ssh_validate_and_apply() {
    local verify_key="${1:-}"
    local verify_expected="${2:-}"
    local verify_user="${3:-}"

    if ! ssh_backup_config; then
        return 1
    fi

    ssh_ensure_include_directive || {
        ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
        return 1
    }

    local tmp_hc="${SSH_HARDENING_CONF}.tmp"
    {
        printf '# Managed by Unified SmartDNS Installer v3.0 (Initial Server Setup)\n'
        printf '# Do not edit manually if managing SSH via installer\n'
        local p
        for p in ${SSH_DESIRED_PORTS}; do
            if [[ "${p}" =~ ^[0-9]+$ ]]; then
                printf 'Port %s\n' "${p}"
            fi
        done
        if [[ -n "${SSH_DESIRED_PUBKEY}" ]]; then
            printf 'PubkeyAuthentication %s\n' "${SSH_DESIRED_PUBKEY}"
        fi
        if [[ -n "${SSH_DESIRED_PASSAUTH}" ]]; then
            printf 'PasswordAuthentication %s\n' "${SSH_DESIRED_PASSAUTH}"
            if [[ "${SSH_DESIRED_PASSAUTH}" == "no" ]]; then
                printf 'KbdInteractiveAuthentication no\n'
                printf 'ChallengeResponseAuthentication no\n'
            fi
        fi
        if [[ -n "${SSH_DESIRED_ROOTLOGIN}" ]]; then
            printf 'PermitRootLogin %s\n' "${SSH_DESIRED_ROOTLOGIN}"
        fi
        if [[ "${SSH_HARDENING_CRYPTO:-false}" == "true" ]]; then
            printf 'KexAlgorithms sntrup761x25519-sha512@openssh.com,curve25519-sha256,curve25519-sha256@libssh.org\n'
            printf 'Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com\n'
            printf 'MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com\n'
        fi
    } > "${tmp_hc}"
    chmod 0644 "${tmp_hc}"
    mv -f "${tmp_hc}" "${SSH_HARDENING_CONF}"

    if [[ "${SSH_SOCKET_ACTIVE:-0}" -eq 1 ]]; then
        install -d -m 0755 -o root -g root "${SSH_SOCKET_DROPIN_DIR}"
        local tmp_sd="${SSH_SOCKET_DROPIN_FILE}.tmp"
        {
            printf '[Socket]\n'
            printf 'ListenStream=\n'
            local sp
            for sp in ${SSH_DESIRED_PORTS}; do
                if [[ "${sp}" =~ ^[0-9]+$ ]]; then
                    printf 'ListenStream=%s\n' "${sp}"
                fi
            done
        } > "${tmp_sd}"
        chmod 0644 "${tmp_sd}"
        mv -f "${tmp_sd}" "${SSH_SOCKET_DROPIN_FILE}"
    fi

    ssh_ensure_runtime_dir
    if ! sshd -t >> "${LOG_DIR}/installation.log" 2>&1; then
        log_error_tr "installation.log" "M_0435" "sshd -t failed" "${SSH_LAST_BACKUP_DIR}"
        ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
        return 1
    fi

    if [[ -n "${verify_key}" && -n "${verify_expected}" ]]; then
        local actual_val
        actual_val="$(ssh_get_effective_param "${verify_key}" "${verify_user}")"
        if [[ "${actual_val,,}" != "${verify_expected,,}" ]]; then
            log_error_tr "installation.log" "M_0488" "${verify_key}" "${verify_expected}" "${actual_val:-empty}"
            log_error_tr "installation.log" "M_0435" "sshd -T verification mismatch" "${SSH_LAST_BACKUP_DIR}"
            ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
            return 1
        fi
    fi

    if [[ "${SSH_SOCKET_ACTIVE:-0}" -eq 1 ]]; then
        systemctl daemon-reload
        if ! systemctl restart ssh.socket; then
            log_error_tr "installation.log" "M_0435" "systemctl restart ssh.socket failed" "${SSH_LAST_BACKUP_DIR}"
            ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
            return 1
        fi
        if systemctl is-active --quiet "${SSH_SERVICE_NAME}" 2>/dev/null; then
            systemctl reload "${SSH_SERVICE_NAME}" 2>/dev/null || true
        fi
    else
        if systemctl is-active --quiet "${SSH_SERVICE_NAME}" 2>/dev/null; then
            if ! systemctl reload "${SSH_SERVICE_NAME}" 2>/dev/null; then
                if ! systemctl restart "${SSH_SERVICE_NAME}"; then
                    log_error_tr "installation.log" "M_0435" "systemctl reload/restart ${SSH_SERVICE_NAME} failed" "${SSH_LAST_BACKUP_DIR}"
                    ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
                    return 1
                fi
            fi
        else
            if ! systemctl enable --now "${SSH_SERVICE_NAME}"; then
                log_error_tr "installation.log" "M_0435" "systemctl start ${SSH_SERVICE_NAME} failed" "${SSH_LAST_BACKUP_DIR}"
                ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
                return 1
            fi
        fi
    fi

    SSH_CURRENT_PORTS="$(ssh_get_all_effective_ports)"
    log_info_tr "installation.log" "M_0437"
    return 0
}

# --- Step 5: Base SSH Audit & Setup ---
initial_setup_ssh_base() {
    printf_tr "M_0439"

    if ! ssh_is_installed; then
        printf_tr "M_0440"
        local inst_ssh=""
        read_tr "M_0441" inst_ssh
        if [[ "${LAST_READ_EOF}" -eq 1 || ! "${inst_ssh:-Y}" =~ ^[Yy]$ ]]; then
            return 0
        fi
        if ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -y -q \
            || ! DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get install -y -q openssh-server; then
            log_error "installation.log" "Не удалось установить openssh-server."
            return 1
        fi
        systemctl enable --now ssh 2>/dev/null || systemctl enable --now sshd 2>/dev/null || true
        initial_setup_record_action "openssh_installed"
    fi

    ssh_detect_state
    local svc_state sock_label pub_v pass_v root_v authf_v confd_list
    svc_state="$(systemctl is-active "${SSH_SERVICE_NAME}" 2>/dev/null || echo inactive)"
    sock_label="no"
    if [[ "${SSH_SOCKET_ACTIVE}" -eq 1 ]]; then sock_label="yes (ssh.socket)"; fi
    pub_v="$(ssh_get_effective_param "pubkeyauthentication")"
    pass_v="$(ssh_get_effective_param "passwordauthentication")"
    root_v="$(ssh_get_effective_param "permitrootlogin")"
    authf_v="$(ssh_get_effective_param "authorizedkeysfile")"
    confd_list="$(find /etc/ssh/sshd_config.d -maxdepth 1 -type f 2>/dev/null | sort | paste -sd ',' - || true)"
    confd_list="${confd_list:-none}"

    printf_tr "M_0442" "${SSH_SERVICE_NAME}:${svc_state}" "${sock_label}" "${SSH_CURRENT_PORTS}" \
        "${pub_v:-unknown}" "${pass_v:-unknown}" "${root_v:-unknown}" "${authf_v:-default}" "${confd_list}"

    if [[ "${pub_v,,}" != "yes" ]]; then
        local en_pub=""
        read_tr "M_0443" en_pub
        if [[ "${LAST_READ_EOF}" -eq 0 && "${en_pub:-Y}" =~ ^[Yy]$ ]]; then
            SSH_DESIRED_PUBKEY="yes"
            if ssh_validate_and_apply "pubkeyauthentication" "yes"; then
                initial_setup_record_action "ssh_pubkey_enabled"
            fi
        fi
    fi

    initial_setup_record_check "ssh_ports=${SSH_CURRENT_PORTS// /,}"
    return 0
}

# --- Step 7: SSH Key Authentication ---
ssh_count_valid_keys() {
    local auth_file="$1"
    if [[ ! -s "${auth_file}" ]]; then
        printf '0'
        return 0
    fi
    local valid=0
    local line tmp_k
    tmp_k="$(mktemp /tmp/ssh-key-chk.XXXXXX)"
    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="${line//$'\r'/}"
        [[ -z "${line}" || "${line}" =~ ^[[:space:]]*# ]] && continue
        printf '%s\n' "${line}" > "${tmp_k}"
        if ssh-keygen -lf "${tmp_k}" >/dev/null 2>&1; then
            valid=$((valid + 1))
        fi
    done < "${auth_file}"
    rm -f "${tmp_k}"
    printf '%s' "${valid}"
}

ssh_append_pubkey_safe() {
    local pub_line="$1"
    local auth_file="$2"
    local target_user="$3"

    pub_line="${pub_line//$'\r'/}"
    local tmp_k
    tmp_k="$(mktemp /tmp/ssh-key-val.XXXXXX)"
    printf '%s\n' "${pub_line}" > "${tmp_k}"
    local fp=""
    if ! fp="$(ssh-keygen -lf "${tmp_k}" 2>/dev/null)"; then
        rm -f "${tmp_k}"
        printf_err_tr "M_0449"
        return 1
    fi
    rm -f "${tmp_k}"

    local key_body
    key_body="$(awk '{print $1 " " $2}' <<<"${pub_line}")"
    if [[ -f "${auth_file}" ]] && grep -Fq "${key_body}" "${auth_file}" 2>/dev/null; then
        printf_tr "M_0450" "${auth_file}"
        return 0
    fi

    printf '%s\n' "${pub_line}" >> "${auth_file}"
    chown "${target_user}:${target_user}" "${auth_file}" 2>/dev/null || chown "${target_user}" "${auth_file}"
    chmod 0600 "${auth_file}"
    printf_tr "M_0451" "${auth_file}" "${fp}"
    return 0
}

print_ssh_key_transfer_instructions() {
    local target_user="$1"
    local priv_path="$2"
    local pub_path="$3"
    local ssh_port="$4"
    local key_base
    key_base="$(basename "${priv_path}")"
    local srv_ip="${SERVER_IPV4:-<SERVER_IP>}"

    if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
        cat <<EOF

==============================================================================
  INSTRUCTIONS TO COPY THE GENERATED SSH KEY TO YOUR LOCAL COMPUTER
==============================================================================
Private key on server : ${priv_path}
Public key on server  : ${pub_path}

SECURITY WARNING:
  - NEVER share your private key with third parties.
  - Store the private key securely (mode 0600) and protect it with a passphrase.
  - After copying the private key to your local machine, consider removing
    ${priv_path} from the server (keeping the public key in authorized_keys).

--- Windows (PowerShell / Windows Terminal / OpenSSH Client) ---
  mkdir \$HOME\\.ssh -Force
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} "\$HOME\\.ssh\\${key_base}"
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} "\$HOME\\.ssh\\${key_base}.pub"
  icacls "\$HOME\\.ssh\\${key_base}" /inheritance:r /grant:r "\$env:USERNAME:R"
  # Connect:
  ssh -i "\$HOME\\.ssh\\${key_base}" -p ${ssh_port} ${target_user}@${srv_ip}
  # PuTTY users: open PuTTYgen -> Conversions -> Import key (${key_base}) -> Save private key (.ppk).

--- Linux ---
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} ~/.ssh/${key_base}
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} ~/.ssh/${key_base}.pub
  chmod 600 ~/.ssh/${key_base} && chmod 644 ~/.ssh/${key_base}.pub
  # Connect:
  ssh -i ~/.ssh/${key_base} -p ${ssh_port} ${target_user}@${srv_ip}

--- macOS ---
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} ~/.ssh/${key_base}
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} ~/.ssh/${key_base}.pub
  chmod 600 ~/.ssh/${key_base} && chmod 644 ~/.ssh/${key_base}.pub
  # Connect:
  ssh -i ~/.ssh/${key_base} -p ${ssh_port} ${target_user}@${srv_ip}
==============================================================================
EOF
    else
        cat <<EOF

==============================================================================
  ИНСТРУКЦИЯ ПО КОПИРОВАНИЮ СГЕНЕРИРОВАННОГО SSH-КЛЮЧА НА ЛОКАЛЬНЫЙ ПК
==============================================================================
Приватный ключ на сервере : ${priv_path}
Публичный ключ на сервере : ${pub_path}

ПРАВИЛА БЕЗОПАСНОСТИ:
  - НИКОГДА не передавайте приватный ключ третьим лицам.
  - Храните приватный ключ в защищённом месте (права 0600) и используйте passphrase.
  - После успешного копирования и проверки входа рекомендуется удалить
    приватный ключ ${priv_path} с сервера (оставив публичный в authorized_keys).

--- Windows (PowerShell / Windows Terminal / OpenSSH Client) ---
  mkdir \$HOME\\.ssh -Force
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} "\$HOME\\.ssh\\${key_base}"
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} "\$HOME\\.ssh\\${key_base}.pub"
  icacls "\$HOME\\.ssh\\${key_base}" /inheritance:r /grant:r "\$env:USERNAME:R"
  # Подключение:
  ssh -i "\$HOME\\.ssh\\${key_base}" -p ${ssh_port} ${target_user}@${srv_ip}
  # Для PuTTY: откройте PuTTYgen -> Conversions -> Import key (${key_base}) -> Save private key (.ppk).

--- Linux ---
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} ~/.ssh/${key_base}
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} ~/.ssh/${key_base}.pub
  chmod 600 ~/.ssh/${key_base} && chmod 644 ~/.ssh/${key_base}.pub
  # Подключение:
  ssh -i ~/.ssh/${key_base} -p ${ssh_port} ${target_user}@${srv_ip}

--- macOS ---
  mkdir -p ~/.ssh && chmod 700 ~/.ssh
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${priv_path} ~/.ssh/${key_base}
  scp -P ${ssh_port} ${target_user}@${srv_ip}:${pub_path} ~/.ssh/${key_base}.pub
  chmod 600 ~/.ssh/${key_base} && chmod 644 ~/.ssh/${key_base}.pub
  # Подключение:
  ssh -i ~/.ssh/${key_base} -p ${ssh_port} ${target_user}@${srv_ip}
==============================================================================
EOF
    fi
}

initial_setup_ssh_keys() {
    printf_tr "M_0444"
    if ! ssh_is_installed; then
        initial_setup_ssh_base || return 1
    fi
    ssh_detect_state

    local target_user="${INITIAL_SETUP_ADMIN_USER:-}"
    if [[ -z "${target_user}" ]] || ! id -u "${target_user}" >/dev/null 2>&1; then
        target_user="root"
        printf_tr "M_0446"
    fi

    local target_home target_group
    target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
    target_group="$(id -gn "${target_user}")"
    local ssh_dir="${target_home}/.ssh"
    local auth_file="${ssh_dir}/authorized_keys"

    printf_tr "M_0445" "${target_user}" "${target_home}"

    install -d -m 0700 -o "${target_user}" -g "${target_group}" "${ssh_dir}"
    if [[ ! -f "${auth_file}" ]]; then
        touch "${auth_file}"
    fi
    chown "${target_user}:${target_group}" "${auth_file}"
    chmod 0600 "${auth_file}"

    local key_mode=""
    read_tr "M_0447" key_mode
    if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
        return 0
    fi
    key_mode="${key_mode:-1}"

    local key_added_or_present=0
    case "${key_mode}" in
        1)
            local pasted_key=""
            while true; do
                read_tr "M_0448" pasted_key
                if [[ "${LAST_READ_EOF}" -eq 1 || -z "${pasted_key}" ]]; then
                    break
                fi
                if ssh_append_pubkey_safe "${pasted_key}" "${auth_file}" "${target_user}"; then
                    key_added_or_present=1
                    break
                fi
            done
            ;;
        2)
            local ktype_choice=""
            read_tr "M_0452" ktype_choice
            if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
                return 0
            fi
            local ktype="ed25519"
            local kbits_args=()
            local def_kname="id_ed25519_${target_user}"
            if [[ "${ktype_choice}" == "2" ]]; then
                ktype="rsa"
                kbits_args=(-b 4096)
                def_kname="id_rsa_${target_user}"
            fi

            local kname=""
            while true; do
                read_tr "M_0453" kname "${def_kname}"
                if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
                    return 0
                fi
                kname="${kname:-${def_kname}}"
                if [[ "${kname}" =~ ^[A-Za-z0-9._-]+$ ]]; then
                    break
                fi
                printf_err_tr "M_0454"
            done

            local priv_file="${ssh_dir}/${kname}"
            local pub_file="${priv_file}.pub"
            if [[ -e "${priv_file}" || -e "${pub_file}" ]]; then
                local ovw=""
                read_tr "M_0455" ovw "${priv_file}"
                if [[ "${LAST_READ_EOF}" -eq 1 || ! "${ovw:-N}" =~ ^[Yy]$ ]]; then
                    return 0
                fi
                rm -f "${priv_file}" "${pub_file}"
            fi

            printf_tr "M_0456"
            if [[ -t 0 ]]; then
                if ! ssh-keygen -t "${ktype}" "${kbits_args[@]}" -f "${priv_file}" -C "${target_user}@$(hostname -s 2>/dev/null || echo server)"; then
                    printf_err_tr "M_0457"
                    return 1
                fi
            else
                if ! ssh-keygen -t "${ktype}" "${kbits_args[@]}" -f "${priv_file}" -N "" -C "${target_user}@server" >/dev/null; then
                    printf_err_tr "M_0457"
                    return 1
                fi
            fi

            chown "${target_user}:${target_group}" "${priv_file}" "${pub_file}"
            chmod 0600 "${priv_file}"
            chmod 0644 "${pub_file}"

            local gen_pub
            gen_pub="$(cat "${pub_file}")"
            if ssh_append_pubkey_safe "${gen_pub}" "${auth_file}" "${target_user}"; then
                key_added_or_present=1
                local active_p
                active_p="$(awk '{print $1}' <<<"${SSH_CURRENT_PORTS}")"
                print_ssh_key_transfer_instructions "${target_user}" "${priv_file}" "${pub_file}" "${active_p:-22}"
            fi
            ;;
        3)
            local existing_cnt
            existing_cnt="$(ssh_count_valid_keys "${auth_file}")"
            printf_tr "M_0458" "${auth_file}" "${existing_cnt}"
            if [[ "${target_user}" != "root" && -s /root/.ssh/authorized_keys ]]; then
                local root_cnt
                root_cnt="$(ssh_count_valid_keys /root/.ssh/authorized_keys)"
                if [[ "${root_cnt}" -gt 0 ]]; then
                    local copy_rk=""
                    read_tr "M_0459" copy_rk "${root_cnt}" "${auth_file}"
                    if [[ "${LAST_READ_EOF}" -eq 0 && "${copy_rk:-Y}" =~ ^[Yy]$ ]]; then
                        local rk_line
                        while IFS= read -r rk_line || [[ -n "${rk_line}" ]]; do
                            [[ -z "${rk_line}" || "${rk_line}" =~ ^[[:space:]]*# ]] && continue
                            ssh_append_pubkey_safe "${rk_line}" "${auth_file}" "${target_user}" || true
                        done < /root/.ssh/authorized_keys
                        existing_cnt="$(ssh_count_valid_keys "${auth_file}")"
                    fi
                fi
            fi
            if [[ "${existing_cnt}" -gt 0 ]]; then
                key_added_or_present=1
            else
                printf_tr "M_0460" "${auth_file}"
            fi
            ;;
        4|*)
            return 0
            ;;
    esac

    local final_key_cnt
    final_key_cnt="$(ssh_count_valid_keys "${auth_file}")"
    if [[ "${key_added_or_present}" -eq 1 || "${final_key_cnt}" -gt 0 ]]; then
        SSH_DESIRED_PUBKEY="yes"
        if ssh_validate_and_apply "pubkeyauthentication" "yes" "${target_user}"; then
            INITIAL_SETUP_SSH_KEY_OK="true"
            initial_setup_record_action "ssh_keys_configured(${target_user})"
            local test_port
            test_port="$(awk '{print $1}' <<<"${SSH_CURRENT_PORTS}")"
            local conf_login=""
            read_tr "M_0461" conf_login "${test_port:-22}" "${target_user}" "${SERVER_IPV4:-<SERVER_IP>}"
            if [[ "${LAST_READ_EOF}" -eq 0 && "${conf_login:-N}" =~ ^[Yy]$ ]]; then
                INITIAL_SETUP_SSH_KEY_CONFIRMED="true"
                initial_setup_record_check "ssh_key_login=confirmed(${target_user})"
                printf_tr "M_0462"
            else
                INITIAL_SETUP_SSH_KEY_CONFIRMED="false"
                save_initial_setup_state
                printf_tr "M_0463"
            fi
        fi
    fi
    return 0
}

# --- Step 6: SSH Port Configuration (Two-Phase Safe Switch) ---
ssh_port_is_reserved_by_stack() {
    local p="$1"
    case "${p}" in
        80|443|853|3000|5353|8053|8443|8444|8853|9443|9444)
            return 0
            ;;
    esac
    return 1
}

initial_setup_ssh_port() {
    printf_tr "M_0464"
    if ! ssh_is_installed; then
        initial_setup_ssh_base || return 1
    fi
    ssh_detect_state

    local cur_port
    cur_port="$(awk '{print $1}' <<<"${SSH_CURRENT_PORTS}")"
    printf_tr "M_0465" "${SSH_CURRENT_PORTS}"

    local want_change=""
    read_tr "M_0466" want_change
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${want_change:-N}" =~ ^[Yy]$ ]]; then
        INITIAL_SETUP_SSH_PORT="${cur_port}"
        save_initial_setup_state
        return 0
    fi

    local new_port=""
    while true; do
        read_tr "M_0467" new_port
        if [[ "${LAST_READ_EOF}" -eq 1 || -z "${new_port}" ]]; then
            return 0
        fi
        if [[ ! "${new_port}" =~ ^[0-9]+$ ]] || [[ "${new_port}" -lt 1024 || "${new_port}" -gt 65535 ]]; then
            printf_err_tr "M_0468"
            continue
        fi
        if [[ "${new_port}" == "${cur_port}" ]]; then
            printf_tr "M_0471" "${new_port}"
            return 0
        fi
        if ssh_port_is_reserved_by_stack "${new_port}"; then
            printf_err_tr "M_0469" "${new_port}"
            continue
        fi
        if ss -tulnp 2>/dev/null | awk '{print $5}' | grep -Eq "(^|:)${new_port}$"; then
            printf_err_tr "M_0470" "${new_port}"
            continue
        fi
        break
    done

    local confirm_dual=""
    read_tr "M_0472" confirm_dual "${new_port}" "${cur_port}" "${new_port}"
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${confirm_dual:-Y}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    local prev_ports="${SSH_DESIRED_PORTS}"
    SSH_DESIRED_PORTS="${cur_port} ${new_port}"
    if ! ssh_validate_and_apply; then
        SSH_DESIRED_PORTS="${prev_ports}"
        return 1
    fi

    local login_user="${INITIAL_SETUP_ADMIN_USER:-root}"
    local confirm_new_conn=""
    read_tr "M_0473" confirm_new_conn "${cur_port}" "${new_port}" "${new_port}" "${login_user}" "${SERVER_IPV4:-<SERVER_IP>}" "${new_port}"
    if [[ "${LAST_READ_EOF}" -eq 0 && "${confirm_new_conn:-N}" =~ ^[Yy]$ ]]; then
        local disable_old=""
        read_tr "M_0474" disable_old "${cur_port}" "${new_port}"
        if [[ "${LAST_READ_EOF}" -eq 0 && "${disable_old:-N}" =~ ^[Yy]$ ]]; then
            SSH_DESIRED_PORTS="${new_port}"
            if ssh_validate_and_apply "port" "${new_port}"; then
                INITIAL_SETUP_SSH_PORT="${new_port}"
                initial_setup_record_action "ssh_port_changed(${cur_port}->${new_port})"
                initial_setup_record_check "ssh_port=${new_port}"
                printf_tr "M_0475" "${new_port}" "${cur_port}"
            else
                SSH_DESIRED_PORTS="${prev_ports}"
            fi
        else
            INITIAL_SETUP_SSH_PORT="${new_port}"
            initial_setup_record_action "ssh_port_dual(${cur_port},${new_port})"
            printf_tr "M_0477" "${cur_port}" "${new_port}"
        fi
    else
        local do_rb=""
        read_tr "M_0476" do_rb "${new_port}" "${cur_port}"
        if [[ "${LAST_READ_EOF}" -eq 1 || "${do_rb:-Y}" =~ ^[Yy]$ ]]; then
            SSH_DESIRED_PORTS="${cur_port}"
            ssh_rollback_config "${SSH_LAST_BACKUP_DIR}" || true
            INITIAL_SETUP_SSH_PORT="${cur_port}"
            save_initial_setup_state
        else
            INITIAL_SETUP_SSH_PORT="${new_port}"
            initial_setup_record_action "ssh_port_dual(${cur_port},${new_port})"
            printf_tr "M_0477" "${cur_port}" "${new_port}"
        fi
    fi
    return 0
}

# --- Step 8: Disable PasswordAuthentication ---
initial_setup_disable_password_auth() {
    printf_tr "M_0478"
    if ! ssh_is_installed; then
        initial_setup_ssh_base || return 1
    fi
    ssh_detect_state

    local target_user="${INITIAL_SETUP_ADMIN_USER:-root}"
    local cur_pass
    cur_pass="$(ssh_get_effective_param "passwordauthentication" "${target_user}")"
    if [[ "${cur_pass,,}" == "no" ]]; then
        printf_tr "M_0479"
        INITIAL_SETUP_PASSAUTH_DISABLED="true"
        save_initial_setup_state
        return 0
    fi

    local cur_pub
    cur_pub="$(ssh_get_effective_param "pubkeyauthentication" "${target_user}")"
    if [[ "${cur_pub,,}" != "yes" ]]; then
        printf_err_tr "M_0480" "PubkeyAuthentication != yes"
        return 1
    fi

    local target_home
    target_home="$(getent passwd "${target_user}" | cut -d: -f6)"
    local auth_file="${target_home}/.ssh/authorized_keys"
    local key_cnt
    key_cnt="$(ssh_count_valid_keys "${auth_file}")"
    if [[ "${key_cnt}" -lt 1 ]]; then
        printf_err_tr "M_0480" "no valid keys in ${auth_file}"
        return 1
    fi

    if [[ "${INITIAL_SETUP_SSH_KEY_CONFIRMED}" != "true" ]]; then
        printf_err_tr "M_0480" "SSH key login has not been confirmed by user (run step [7] first)"
        return 1
    fi

    local conf_dp=""
    read_tr "M_0481" conf_dp
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${conf_dp:-N}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    local prev_pa="${SSH_DESIRED_PASSAUTH}"
    SSH_DESIRED_PASSAUTH="no"
    if ssh_validate_and_apply "passwordauthentication" "no" "${target_user}"; then
        INITIAL_SETUP_PASSAUTH_DISABLED="true"
        initial_setup_record_action "ssh_password_auth_disabled"
        initial_setup_record_check "passwordauth=no"
        printf_tr "M_0482"
        return 0
    else
        SSH_DESIRED_PASSAUTH="${prev_pa}"
        return 1
    fi
}

# --- Step 9: Disable SSH Root Login ---
initial_setup_disable_root_login() {
    printf_tr "M_0483"
    if ! ssh_is_installed; then
        initial_setup_ssh_base || return 1
    fi
    ssh_detect_state

    local cur_rl
    cur_rl="$(ssh_get_effective_param "permitrootlogin" "root")"
    if [[ "${cur_rl,,}" == "no" ]]; then
        printf_tr "M_0484"
        INITIAL_SETUP_ROOTLOGIN_DISABLED="true"
        save_initial_setup_state
        return 0
    fi

    if [[ -z "${INITIAL_SETUP_ADMIN_USER}" ]] || ! id -u "${INITIAL_SETUP_ADMIN_USER}" >/dev/null 2>&1; then
        printf_err_tr "M_0485" "no alternative administrative user configured (run step [4] first)"
        return 1
    fi
    if ! user_in_sudo_group "${INITIAL_SETUP_ADMIN_USER}"; then
        printf_err_tr "M_0485" "user ${INITIAL_SETUP_ADMIN_USER} is not in the sudo group"
        return 1
    fi

    local admin_home
    admin_home="$(getent passwd "${INITIAL_SETUP_ADMIN_USER}" | cut -d: -f6)"
    local admin_keys
    admin_keys="$(ssh_count_valid_keys "${admin_home}/.ssh/authorized_keys")"
    if [[ "${admin_keys}" -lt 1 ]]; then
        printf_err_tr "M_0485" "no valid SSH key found for ${INITIAL_SETUP_ADMIN_USER}"
        return 1
    fi
    if [[ "${INITIAL_SETUP_SSH_KEY_CONFIRMED}" != "true" ]]; then
        printf_err_tr "M_0485" "SSH key login for ${INITIAL_SETUP_ADMIN_USER} has not been confirmed"
        return 1
    fi

    local conf_dr=""
    read_tr "M_0486" conf_dr "${INITIAL_SETUP_ADMIN_USER}"
    if [[ "${LAST_READ_EOF}" -eq 1 || ! "${conf_dr:-N}" =~ ^[Yy]$ ]]; then
        return 0
    fi

    local prev_rl="${SSH_DESIRED_ROOTLOGIN}"
    SSH_DESIRED_ROOTLOGIN="no"
    if ssh_validate_and_apply "permitrootlogin" "no" "root"; then
        INITIAL_SETUP_ROOTLOGIN_DISABLED="true"
        initial_setup_record_action "ssh_root_login_disabled"
        initial_setup_record_check "permitrootlogin=no"
        printf_tr "M_0487"
        return 0
    else
        SSH_DESIRED_ROOTLOGIN="${prev_rl}"
        return 1
    fi
}

# ------------------------------ Extra Security Measures (Module 6) ------------
initial_setup_extra_security() {
    printf_tr "M_0489"
    ssh_detect_state

    local ufw_state="not-installed"
    if command -v ufw >/dev/null 2>&1; then
        ufw_state="$(LC_ALL=C ufw status 2>/dev/null | head -n1 || echo installed)"
    fi
    local nft_state="missing"
    if command -v nft >/dev/null 2>&1; then nft_state="available"; fi

    local f2b_state="not-installed"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        f2b_state="active"
    elif dpkg-query -W -f='${Status}' fail2ban 2>/dev/null | grep -q 'install ok installed'; then
        f2b_state="installed (inactive)"
    fi

    local ua_state="not-installed"
    if dpkg-query -W -f='${Status}' unattended-upgrades 2>/dev/null | grep -q 'install ok installed'; then
        local ar_val
        ar_val="$(grep -RhE 'Automatic-Reboot[[:space:]]+' /etc/apt/apt.conf.d/ 2>/dev/null | tail -n1 | tr -d ' ";' || echo "unset")"
        ua_state="installed (${ar_val})"
    fi

    local extra_svcs
    extra_svcs="$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | awk '{print $1}' | grep -E '^(rpcbind|avahi-daemon|cups|telnet|vsftpd|smbd|nmbd)\.service$' | paste -sd ',' - || true)"
    extra_svcs="${extra_svcs:-none}"

    local open_ports
    open_ports="$(ss -tulnp 2>/dev/null | awk 'NR>1 {print $1 ":" $5}' | sort -u | paste -sd ' ' - || true)"

    local ipv6_disabled="0"
    ipv6_disabled="$(sysctl -n net.ipv6.conf.all.disable_ipv6 2>/dev/null || echo 0)"
    local ipv6_info="enabled"
    if [[ "${ipv6_disabled}" == "1" ]]; then ipv6_info="disabled via sysctl"; fi

    local ssh_perm_ok="OK"
    local users_to_chk=(root)
    if [[ -n "${INITIAL_SETUP_ADMIN_USER}" ]]; then
        users_to_chk+=("${INITIAL_SETUP_ADMIN_USER}")
    fi
    local chk_u
    for chk_u in "${users_to_chk[@]}"; do
        id -u "${chk_u}" >/dev/null 2>&1 || continue
        local h_dir
        h_dir="$(getent passwd "${chk_u}" | cut -d: -f6)"
        if [[ -d "${h_dir}/.ssh" ]]; then
            local dm
            dm="$(stat -c '%a' "${h_dir}/.ssh" 2>/dev/null || echo 0)"
            if [[ "${dm}" != "700" ]]; then
                ssh_perm_ok="WARN(${h_dir}/.ssh=${dm})"
            fi
        fi
        if [[ -f "${h_dir}/.ssh/authorized_keys" ]]; then
            local fm
            fm="$(stat -c '%a' "${h_dir}/.ssh/authorized_keys" 2>/dev/null || echo 0)"
            if [[ "${fm}" != "600" ]]; then
                ssh_perm_ok="WARN(authorized_keys=${fm})"
            fi
        fi
    done

    local visudo_st="OK"
    if command -v visudo >/dev/null 2>&1 && ! visudo -c >/dev/null 2>&1; then
        visudo_st="WARN"
    fi

    local kex_v
    kex_v="$(ssh_get_effective_param "kexalgorithms" | cut -c1-48)"
    kex_v="${kex_v:-n/a}"

    local human_users
    human_users="$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1 "(" $3 ")"}' /etc/passwd | paste -sd ',' - || true)"
    human_users="${human_users:-none}"

    local ntp_st="unknown"
    if command -v timedatectl >/dev/null 2>&1; then
        ntp_st="$(timedatectl show -p NTPSynchronized --value 2>/dev/null || timedatectl status 2>/dev/null | awk -F: '/NTP|synchronized/ {gsub(/^[ \t]+/,"",$2); print $2; exit}' || echo unknown)"
    fi

    local jrnl_st="inactive"
    if systemctl is-active --quiet systemd-journald 2>/dev/null; then jrnl_st="active"; fi

    local disk_free_mb swap_total_mb
    disk_free_mb="$(df -Pm / 2>/dev/null | awk 'NR==2 {print $4}')"
    swap_total_mb="$(free -m 2>/dev/null | awk '/^Swap:/ {print $2}')"
    swap_total_mb="${swap_total_mb:-0}"

    local rb_st="no"
    if [[ -f /var/run/reboot-required ]] || [[ "${REBOOT_REQUIRED}" == "true" ]]; then
        rb_st="YES (deferred until SmartDNS)"
    fi

    local psym phard aslr
    psym="$(sysctl -n fs.protected_symlinks 2>/dev/null || echo ?)"
    phard="$(sysctl -n fs.protected_hardlinks 2>/dev/null || echo ?)"
    aslr="$(sysctl -n kernel.randomize_va_space 2>/dev/null || echo ?)"

    cat <<EOF
==============================================================================
  SECURITY & SYSTEM READINESS AUDIT (16 CHECKS)
==============================================================================
  [ 1] Firewall readiness       : ufw=${ufw_state}, nftables=${nft_state} (configured in main phase)
  [ 2] Brute-force protection   : fail2ban=${f2b_state}
  [ 3] Auto security updates    : unattended-upgrades=${ua_state}
  [ 4] Unnecessary services     : ${extra_svcs}
  [ 5] Open listening ports     : ${open_ports}
  [ 6] IPv6 status              : ${ipv6_info}
  [ 7] SSH key permissions      : ${ssh_perm_ok}
  [ 8] Sudo configuration       : visudo=${visudo_st}, sudo_user=${INITIAL_SETUP_ADMIN_USER:-none}
  [ 9] SSH cryptography         : hardened=${SSH_HARDENING_CRYPTO}, kex=${kex_v}...
  [10] Non-system users (>=1000): ${human_users}
  [11] System time & NTP        : NTPSynchronized=${ntp_st}
  [12] Logging                  : systemd-journald=${jrnl_st}
  [13] Free disk space (/)      : ${disk_free_mb:-0} MB
  [14] Swap memory              : ${swap_total_mb} MB
  [15] Kernel & reboot state    : kernel=$(uname -r), reboot_required=${rb_st}
  [16] OS kernel protections    : protected_symlinks=${psym}, protected_hardlinks=${phard}, ASLR=${aslr}
==============================================================================
EOF

    while true; do
        local opt=""
        read_tr "M_0490" opt
        if [[ "${LAST_READ_EOF}" -eq 1 || -z "${opt}" || "${opt}" == "0" ]]; then
            break
        fi
        case "${opt}" in
            1)
                local p_list="${SSH_CURRENT_PORTS// /,}"
                local c_f2b=""
                read_tr "M_0491" c_f2b "${p_list}"
                if [[ "${LAST_READ_EOF}" -eq 0 && "${c_f2b:-N}" =~ ^[Yy]$ ]]; then
                    if DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -y -q \
                        && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get install -y -q fail2ban; then
                        install -d -m 0755 /etc/fail2ban/jail.d
                        cat > /etc/fail2ban/jail.d/smartdns-sshd.local <<F2B_EOF
[sshd]
enabled = true
port = ${p_list}
backend = systemd
maxretry = 5
findtime = 10m
bantime = 1h
F2B_EOF
                        chmod 0644 /etc/fail2ban/jail.d/smartdns-sshd.local
                        if systemctl enable --now fail2ban 2>/dev/null; then
                            initial_setup_record_action "fail2ban_enabled(ports=${p_list})"
                            printf_tr "M_0492" "${p_list}"
                        else
                            systemctl enable fail2ban 2>/dev/null || true
                            initial_setup_record_action "fail2ban_configured(ports=${p_list})"
                            printf_tr "M_0510"
                        fi
                        check_reboot_required 1 || true
                    fi
                fi
                ;;
            2)
                local c_ua=""
                read_tr "M_0493" c_ua
                if [[ "${LAST_READ_EOF}" -eq 0 && "${c_ua:-N}" =~ ^[Yy]$ ]]; then
                    if DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get update -y -q \
                        && DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 apt-get install -y -q unattended-upgrades; then
                        install -d -m 0755 /etc/apt/apt.conf.d
                        cat > /etc/apt/apt.conf.d/51smartdns-unattended-upgrades <<UA_EOF
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Automatic-Reboot-WithUsers "false";
UA_EOF
                        chmod 0644 /etc/apt/apt.conf.d/51smartdns-unattended-upgrades
                        initial_setup_record_action "unattended_upgrades_enabled(no_reboot)"
                        printf_tr "M_0494"
                        check_reboot_required 1 || true
                    fi
                fi
                ;;
            3)
                local c_cr=""
                read_tr "M_0495" c_cr
                if [[ "${LAST_READ_EOF}" -eq 0 && "${c_cr:-N}" =~ ^[Yy]$ ]]; then
                    local prev_cr="${SSH_HARDENING_CRYPTO}"
                    SSH_HARDENING_CRYPTO="true"
                    if ssh_validate_and_apply; then
                        initial_setup_record_action "ssh_crypto_hardened"
                    else
                        SSH_HARDENING_CRYPTO="${prev_cr}"
                    fi
                fi
                ;;
            4)
                local u_fix
                for u_fix in "${users_to_chk[@]}"; do
                    id -u "${u_fix}" >/dev/null 2>&1 || continue
                    local hd ug
                    hd="$(getent passwd "${u_fix}" | cut -d: -f6)"
                    ug="$(id -gn "${u_fix}")"
                    if [[ -d "${hd}/.ssh" ]]; then
                        chown -R "${u_fix}:${ug}" "${hd}/.ssh"
                        chmod 0700 "${hd}/.ssh"
                        if [[ -f "${hd}/.ssh/authorized_keys" ]]; then
                            chmod 0600 "${hd}/.ssh/authorized_keys"
                        fi
                    fi
                done
                initial_setup_record_action "ssh_permissions_fixed"
                printf_tr "M_0496"
                ;;
            5)
                if command -v timedatectl >/dev/null 2>&1; then
                    timedatectl set-ntp true 2>/dev/null || true
                    initial_setup_record_action "ntp_enabled"
                    printf_tr "M_0497"
                fi
                ;;
            6)
                local cur_sw df_m
                cur_sw="$(free -m 2>/dev/null | awk '/^Swap:/ {print $2}')"
                df_m="$(df -Pm / 2>/dev/null | awk 'NR==2 {print $4}')"
                if [[ "${cur_sw:-0}" -gt 0 || "${df_m:-0}" -lt 3000 || -e /swapfile ]]; then
                    printf_tr "M_0498" "${cur_sw:-0}"
                else
                    local c_sw=""
                    read_tr "M_0499" c_sw
                    if [[ "${LAST_READ_EOF}" -eq 0 && "${c_sw:-N}" =~ ^[Yy]$ ]]; then
                        if dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none \
                            && chmod 0600 /swapfile \
                            && mkswap /swapfile >/dev/null \
                            && swapon /swapfile; then
                            if ! grep -q '^/swapfile ' /etc/fstab 2>/dev/null; then
                                printf '/swapfile none swap sw 0 0\n' >> /etc/fstab
                            fi
                            initial_setup_record_action "swapfile_1024m_created"
                            printf_tr "M_0500"
                        fi
                    fi
                fi
                ;;
        esac
    done
    return 0
}

# ------------------------------ Initial Server Setup Menu (Module 2) ----------
initial_setup_item_title() {
    local item_id="$1"
    if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
        case "${item_id}" in
            1)  printf 'Full system update' ;;
            2)  printf 'Check / install sudo' ;;
            3)  printf 'Change root password' ;;
            4)  printf 'Create / select administrative user' ;;
            5)  printf 'SSH server audit & base setup' ;;
            6)  printf 'Configure SSH port' ;;
            7)  printf 'Configure SSH key authentication' ;;
            8)  printf 'Disable PasswordAuthentication' ;;
            9)  printf 'Disable Root Login over SSH' ;;
            10) printf 'Additional security measures' ;;
        esac
    else
        case "${item_id}" in
            1)  printf 'Полное обновление системы' ;;
            2)  printf 'Проверка / установка sudo' ;;
            3)  printf 'Изменение пароля root' ;;
            4)  printf 'Создание / выбор административного пользователя' ;;
            5)  printf 'Настройка и аудит SSH' ;;
            6)  printf 'Настройка SSH port' ;;
            7)  printf 'Настройка SSH key authentication' ;;
            8)  printf 'Отключение PasswordAuthentication' ;;
            9)  printf 'Отключение Root Login по SSH' ;;
            10) printf 'Дополнительные меры безопасности' ;;
        esac
    fi
}

print_initial_server_setup_menu() {
    ssh_detect_state
    local st_upd="[ ]" st_sudo="[ ]" st_rp="[ ]" st_usr="[ ]" st_ssh="[ ]"
    local st_port="[ ]" st_key="[ ]" st_pa="[ ]" st_rl="[ ]" st_ext="[ ]"

    if [[ "${INITIAL_SETUP_OS_UPDATED}" == "true" ]]; then st_upd="[x]"; fi
    if [[ "${INITIAL_SETUP_SUDO_OK}" == "true" ]] || command -v sudo >/dev/null 2>&1; then st_sudo="[x]"; fi
    if [[ "${INITIAL_SETUP_ROOT_PASS_CHANGED}" == "true" ]]; then st_rp="[x]"; fi
    if [[ -n "${INITIAL_SETUP_ADMIN_USER}" ]] && id -u "${INITIAL_SETUP_ADMIN_USER}" >/dev/null 2>&1; then st_usr="[x]"; fi
    if ssh_is_installed; then st_ssh="[x]"; fi
    if [[ -n "${INITIAL_SETUP_SSH_PORT}" && "${INITIAL_SETUP_SSH_PORT}" != "22" ]]; then st_port="[x]"; fi
    if [[ "${INITIAL_SETUP_SSH_KEY_OK}" == "true" ]]; then st_key="[x]"; fi
    if [[ "${INITIAL_SETUP_PASSAUTH_DISABLED}" == "true" ]]; then st_pa="[x]"; fi
    if [[ "${INITIAL_SETUP_ROOTLOGIN_DISABLED}" == "true" ]]; then st_rl="[x]"; fi
    if [[ "${INITIAL_SETUP_ACTIONS_DONE}" == *"fail2ban"* || "${INITIAL_SETUP_ACTIONS_DONE}" == *"unattended_upgrades"* || "${INITIAL_SETUP_ACTIONS_DONE}" == *"ssh_crypto"* ]]; then
        st_ext="[x]"
    fi

    if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
        cat <<EOF

==============================================================================
  INITIAL SERVER SETUP & SECURITY HARDENING (v${INSTALLER_VERSION})
==============================================================================
Before installing the main SmartDNS + SNI Proxy stack, it is recommended
to perform initial server setup and SSH security hardening.
Reboot lock is ACTIVE (REBOOT_LOCKED=${REBOOT_LOCKED}) until SmartDNS passes checks.

  ${st_upd} [ 1] Full system update (non-interactive, no reboot)
  ${st_sudo} [ 2] Check / install sudo
  ${st_rp} [ 3] Change root password
  ${st_usr} [ 4] Create / select administrative user (current: ${INITIAL_SETUP_ADMIN_USER:-none}, sudo: ${INITIAL_SETUP_ADMIN_IN_SUDO})
  ${st_ssh} [ 5] SSH server audit & base setup
  ${st_port} [ 6] Configure SSH port (current: ${SSH_CURRENT_PORTS})
  ${st_key} [ 7] Configure SSH key authentication (confirmed: ${INITIAL_SETUP_SSH_KEY_CONFIRMED})
  ${st_pa} [ 8] Disable PasswordAuthentication (disabled: ${INITIAL_SETUP_PASSAUTH_DISABLED})
  ${st_rl} [ 9] Disable Root Login over SSH (disabled: ${INITIAL_SETUP_ROOTLOGIN_DISABLED})
  ${st_ext} [10] Additional security measures (16-point audit & optional tools)
==============================================================================
EOF
    else
        cat <<EOF

==============================================================================
  INITIAL SERVER SETUP & SECURITY HARDENING (v${INSTALLER_VERSION})
==============================================================================
Перед установкой основного функционала SmartDNS + SNI Proxy рекомендуется
выполнить первоначальную настройку и усиление безопасности сервера.
Запрет перезагрузки АКТИВЕН (REBOOT_LOCKED=${REBOOT_LOCKED}) до проверки SmartDNS.

  ${st_upd} [ 1] Полное обновление системы (non-interactive, без reboot)
  ${st_sudo} [ 2] Проверка / установка sudo
  ${st_rp} [ 3] Изменение пароля root
  ${st_usr} [ 4] Создание / выбор административного пользователя (текущий: ${INITIAL_SETUP_ADMIN_USER:-нет}, sudo: ${INITIAL_SETUP_ADMIN_IN_SUDO})
  ${st_ssh} [ 5] Настройка и аудит SSH
  ${st_port} [ 6] Настройка SSH port (активные: ${SSH_CURRENT_PORTS})
  ${st_key} [ 7] Настройка SSH key authentication (подтверждено: ${INITIAL_SETUP_SSH_KEY_CONFIRMED})
  ${st_pa} [ 8] Отключение PasswordAuthentication (отключено: ${INITIAL_SETUP_PASSAUTH_DISABLED})
  ${st_rl} [ 9] Отключение Root Login по SSH (отключено: ${INITIAL_SETUP_ROOTLOGIN_DISABLED})
  ${st_ext} [10] Дополнительные меры безопасности (аудит 16 пунктов и опции)
==============================================================================
EOF
    fi
}

run_initial_setup_item() {
    local item_id="$1"
    local rc=0
    case "${item_id}" in
        1) initial_setup_os_update || rc=$? ;;
        2) initial_setup_check_sudo || rc=$? ;;
        3) initial_setup_root_password || rc=$? ;;
        4) initial_setup_admin_user || rc=$? ;;
        5) initial_setup_ssh_base || rc=$? ;;
        6) initial_setup_ssh_port || rc=$? ;;
        7) initial_setup_ssh_keys || rc=$? ;;
        8) initial_setup_disable_password_auth || rc=$? ;;
        9) initial_setup_disable_root_login || rc=$? ;;
        10) initial_setup_extra_security || rc=$? ;;
    esac
    if [[ "${rc}" -eq 2 || "${INSTALL_PAUSED}" == "true" ]]; then
        exit 0
    fi
    return 0
}

run_initial_setup_selective_loop() {
    while true; do
        print_initial_server_setup_menu
        local sub_choice=""
        read_tr "M_0503" sub_choice
        if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
            save_initial_setup_state
            return 0
        fi
        case "${sub_choice^^}" in
            D)
                INITIAL_SETUP_COMPLETED="true"
                save_initial_setup_state
                printf_tr "M_0505" "${INITIAL_SETUP_STATE_FILE}"
                return 0
                ;;
            Q)
                printf_tr "M_0507"
                exit 0
                ;;
            1|2|3|4|5|6|7|8|9|10)
                run_initial_setup_item "${sub_choice}"
                ;;
        esac
    done
}

run_initial_server_setup() {
    local call_context="${1:-install}"
    load_initial_setup_state
    ssh_detect_state
    log_info "installation.log" "Запуск этапа Initial Server Setup (context=${call_context}, completed=${INITIAL_SETUP_COMPLETED})."

    # Non-interactive / закрытый stdin: безопасно пропускаем интерактивное меню
    if [[ ! -t 0 ]]; then
        save_initial_setup_state
        return 0
    fi

    if [[ "${INITIAL_SETUP_COMPLETED}" == "true" ]]; then
        print_initial_server_setup_menu
        local prev_choice=""
        read_tr "M_0502" prev_choice "${INITIAL_SETUP_UPDATED_AT:-previous run}"
        if [[ "${LAST_READ_EOF}" -eq 1 || "${prev_choice^^}" == "S" || -z "${prev_choice}" ]]; then
            return 0
        elif [[ "${prev_choice^^}" == "Q" ]]; then
            printf_tr "M_0507"
            exit 0
        elif [[ "${prev_choice^^}" == "C" ]]; then
            run_initial_setup_selective_loop
            return 0
        fi
    fi

    while true; do
        print_initial_server_setup_menu
        local main_choice=""
        read_tr "M_0501" main_choice
        if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
            save_initial_setup_state
            return 0
        fi
        main_choice="${main_choice:-A}"

        case "${main_choice^^}" in
            A)
                # Рекомендуемый безопасный порядок: сначала ключи (7), затем смена порта (6), затем отключение паролей (8) и root (9)
                local rec_steps=(1 2 3 4 5 7 6 8 9 10)
                local idx=0
                local total="${#rec_steps[@]}"
                while [[ "${idx}" -lt "${total}" ]]; do
                    local step_num=$((idx + 1))
                    local target_item="${rec_steps[${idx}]}"
                    local item_title
                    item_title="$(initial_setup_item_title "${target_item}")"
                    local nav=""
                    read_tr "M_0504" nav "${step_num}" "${target_item}" "${item_title}"
                    if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
                        break
                    fi
                    case "${nav^^}" in
                        S)
                            idx=$((idx + 1))
                            continue
                            ;;
                        B)
                            if [[ "${idx}" -gt 0 ]]; then
                                idx=$((idx - 1))
                            fi
                            continue
                            ;;
                        Q)
                            printf_tr "M_0507"
                            exit 0
                            ;;
                        *)
                            run_initial_setup_item "${target_item}"
                            idx=$((idx + 1))
                            ;;
                    esac
                done
                INITIAL_SETUP_COMPLETED="true"
                save_initial_setup_state
                printf_tr "M_0505" "${INITIAL_SETUP_STATE_FILE}"
                return 0
                ;;
            S)
                save_initial_setup_state
                printf_tr "M_0506"
                return 0
                ;;
            C)
                run_initial_setup_selective_loop
                return 0
                ;;
            Q)
                printf_tr "M_0507"
                exit 0
                ;;
        esac
    done
}

# ------------------------------ Firewall SSH Guard & Report (Module 7) --------
firewall_collect_all_ssh_ports() {
    load_initial_setup_state
    ssh_detect_state
    local raw_ports="${SSH_CURRENT_PORTS} ${INITIAL_SETUP_SSH_PORT:-}"
    local ss_ports
    ss_ports="$(ss -tlnp 2>/dev/null | awk '/(sshd|ssh\.socket)/ {split($4,a,":"); print a[length(a)]}' | paste -sd ' ' - || true)"
    raw_ports="${raw_ports} ${ss_ports}"
    tr ' ' '\n' <<<"${raw_ports}" | awk '/^[0-9]+$/ && $1 >= 1 && $1 <= 65535' | sort -nu | paste -sd ' ' -
}

firewall_allow_all_ssh_ports_ufw() {
    command -v ufw >/dev/null 2>&1 || return 0
    local all_ssh_ports
    all_ssh_ports="$(firewall_collect_all_ssh_ports)"
    all_ssh_ports="${all_ssh_ports:-22}"
    local -a ssh_port_arr=()
    read -r -a ssh_port_arr <<<"${all_ssh_ports}"
    local sp
    for sp in "${ssh_port_arr[@]}"; do
        ufw allow "${sp}/tcp" comment 'SSH Access' >/dev/null 2>&1 || ufw allow "${sp}/tcp" >/dev/null 2>&1 || true
        if ! LC_ALL=C ufw show added 2>/dev/null | grep -Eq "allow[[:space:]]+${sp}/tcp"; then
            ufw allow "${sp}/tcp" >/dev/null 2>&1 || true
        fi
        log_info_tr "installation.log" "M_0508" "${sp}"
    done
}

firewall_verify_ssh_ports_open() {
    command -v ufw >/dev/null 2>&1 || return 0
    local all_ssh_ports
    all_ssh_ports="$(firewall_collect_all_ssh_ports)"
    all_ssh_ports="${all_ssh_ports:-22}"
    local -a ssh_port_arr=()
    read -r -a ssh_port_arr <<<"${all_ssh_ports}"
    local sp
    for sp in "${ssh_port_arr[@]}"; do
        if ! LC_ALL=C ufw status 2>/dev/null | grep -Eq "^${sp}/tcp([[:space:]]+\(v6\))?[[:space:]]+ALLOW"; then
            log_warn_tr "installation.log" "M_0509" "${sp}"
            ufw allow "${sp}/tcp" >/dev/null 2>&1 || true
        fi
        if ! ss -tlnp 2>/dev/null | grep -Eq ":${sp}[[:space:]]"; then
            log_warn_tr "installation.log" "M_0509" "${sp}"
        fi
    done
}

print_initial_setup_report_summary() {
    load_initial_setup_state
    load_reboot_lock_state
    ssh_detect_state
    local pa_eff rl_eff
    pa_eff="$(ssh_get_effective_param "passwordauthentication")"
    rl_eff="$(ssh_get_effective_param "permitrootlogin")"
    cat <<EOF
------------------------------------------------------------------------------
Initial Server Setup & Security Hardening:
  Completed              : ${INITIAL_SETUP_COMPLETED}
  Admin user (sudo)      : ${INITIAL_SETUP_ADMIN_USER:-none} (in sudo: ${INITIAL_SETUP_ADMIN_IN_SUDO})
  Active SSH ports       : ${SSH_CURRENT_PORTS}
  SSH key auth confirmed : ${INITIAL_SETUP_SSH_KEY_CONFIRMED}
  PasswordAuthentication : ${pa_eff:-n/a}
  PermitRootLogin        : ${rl_eff:-n/a}
  Reboot lock state      : REBOOT_LOCKED=${REBOOT_LOCKED}, SMARTDNS_VERIFIED=${SMARTDNS_VERIFIED}
  Deferred reboot needed : ${REBOOT_REQUIRED} (${REBOOT_REASONS:-none})
------------------------------------------------------------------------------
EOF
}

# ------------------------------ Interactive Main Launcher Menu ----------------
run_launcher_exec() {
    check_root
    local rc=0
    LANGUAGE_SELECTED=1 SCRIPT_LANG="${SCRIPT_LANG:-ru}" \
        SKIP_INITIAL_SETUP_IN_INSTALL="${SKIP_INITIAL_SETUP_IN_INSTALL:-0}" \
        bash "${BASH_SOURCE[0]}" "$@" || rc=$?
    SKIP_INITIAL_SETUP_IN_INSTALL=0
    if [[ "${rc}" -ne 0 ]]; then
        printf_tr "M_0515" "${rc}"
    fi
    local _pause=""
    read_tr "M_0514" _pause
    if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
        return 1
    fi
    return 0
}

run_launcher_switch_engine_submenu() {
    local eng_choice=""
    read_tr "M_0516" eng_choice
    if [[ "${LAST_READ_EOF}" -eq 1 || -z "${eng_choice}" || "${eng_choice}" == "0" ]]; then
        return 0
    fi
    case "${eng_choice}" in
        1) run_launcher_exec --switch-engine oxidns ;;
        2) run_launcher_exec --switch-engine adguardhome ;;
        *) printf_tr "M_0512" ;;
    esac
}

run_launcher_whitelist_submenu() {
    local wl_choice=""
    read_tr "M_0517" wl_choice
    if [[ "${LAST_READ_EOF}" -eq 1 || -z "${wl_choice}" || "${wl_choice}" == "0" ]]; then
        return 0
    fi
    case "${wl_choice}" in
        1) run_launcher_exec --whitelist-toggle on ;;
        2) run_launcher_exec --whitelist-toggle off ;;
        3) run_launcher_exec --whitelist-mode shared ;;
        4) run_launcher_exec --whitelist-mode separate ;;
        *) printf_tr "M_0512" ;;
    esac
}

run_launcher_rollback_submenu() {
    if [[ -d "${BACKUP_ROOT}" ]]; then
        printf_tr "M_0519"
        ls -1dt "${BACKUP_ROOT}"/backup-* 2>/dev/null | head -n 10 | sed 's/^/  - /' || true
    fi
    local rb_path=""
    read_tr "M_0518" rb_path
    if [[ "${LAST_READ_EOF}" -eq 1 || "${rb_path}" == "0" ]]; then
        return 0
    fi
    if [[ -n "${rb_path}" ]]; then
        run_launcher_exec --rollback "${rb_path}"
    else
        run_launcher_exec --rollback
    fi
}

run_main_launcher_menu() {
    while true; do
        if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
            cat <<MENU_EN

==============================================================================
  UNIFIED SMARTDNS INSTALLER (v${INSTALLER_VERSION})
==============================================================================
  Setup & Installation:
    [ 1] Initial server setup & SSH hardening (--initial-setup)
    [ 2] Install SmartDNS + SNI Proxy         (--install)

  Diagnostics & Maintenance:
    [ 3] Service status & DoT whitelist       (--status)
    [ 4] Run full verification test suite     (--test)
    [ 5] Server preflight check               (--preflight)
    [16] Provider Hostname check (read-only)  (--hostname-check)
    [ 6] Update binaries, rules & TLS renewal (--update)

  Configuration Management:
    [ 7] Manage proxied domain groups         (--domain-groups)
    [ 8] Switch DNS backend (OxiDNS/AdGuard)  (--switch-engine)
    [ 9] Manage DoT IP-whitelist              (--whitelist-*)
    [10] Sync server IP & Cloudflare DNS      (--sync-ip)
    [11] Change root domain & certificate     (--change-domain)
    [12] Regenerate procedural Cover Site     (--regenerate-cover)

  Backup & Removal:
    [13] Create full system backup            (--backup)
    [14] Rollback to a previous backup        (--rollback)
    [15] Selective / full uninstall           (--uninstall)

    [ 0] Exit
==============================================================================
MENU_EN
        else
            cat <<MENU_RU

==============================================================================
  УСТАНОВЩИК UNIFIED SMARTDNS (v${INSTALLER_VERSION})
==============================================================================
  Настройка и установка:
    [ 1] Начальная настройка сервера и SSH    (--initial-setup)
    [ 2] Установка SmartDNS + SNI Proxy       (--install)

  Диагностика и обслуживание:
    [ 3] Статус служб и DoT whitelist         (--status)
    [ 4] Комплексное тестирование стека       (--test)
    [ 5] Предварительная проверка сервера     (--preflight)
    [16] Проверка Provider Hostname (R/O)     (--hostname-check)
    [ 6] Обновление компонентов, правил и TLS (--update)

  Управление конфигурацией:
    [ 7] Группы проксируемых доменов и импорт (--domain-groups)
    [ 8] Переключение DNS backend             (--switch-engine)
    [ 9] Управление DoT IP-whitelist          (--whitelist-*)
    [10] Синхронизация IP и Cloudflare DNS    (--sync-ip)
    [11] Смена корневого домена и сертификата (--change-domain)
    [12] Перегенерация сайта-заглушки         (--regenerate-cover)

  Резервные копии и удаление:
    [13] Создать резервную копию              (--backup)
    [14] Откат к резервной копии              (--rollback)
    [15] Выборочное / полное удаление         (--uninstall)

    [ 0] Выход
==============================================================================
MENU_RU
        fi

        local menu_choice=""
        read_tr "M_0511" menu_choice
        if [[ "${LAST_READ_EOF}" -eq 1 ]]; then
            return 0
        fi

        case "${menu_choice}" in
            1)  run_launcher_exec --initial-setup || return 0 ;;
            2)
                SKIP_INITIAL_SETUP_IN_INSTALL=1
                run_launcher_exec --install || return 0
                ;;
            3)  run_launcher_exec --status || return 0 ;;
            4)  run_launcher_exec --test || return 0 ;;
            5)  run_launcher_exec --preflight || return 0 ;;
            6)  run_launcher_exec --update || return 0 ;;
            7)  run_launcher_exec --domain-groups || return 0 ;;
            8)  run_launcher_switch_engine_submenu || return 0 ;;
            9)  run_launcher_whitelist_submenu || return 0 ;;
            10) run_launcher_exec --sync-ip || return 0 ;;
            11) run_launcher_exec --change-domain || return 0 ;;
            12) run_launcher_exec --regenerate-cover || return 0 ;;
            13) run_launcher_exec --backup || return 0 ;;
            14) run_launcher_rollback_submenu || return 0 ;;
            15) run_launcher_exec --uninstall || return 0 ;;
            16) run_launcher_exec --hostname-check || return 0 ;;
            0|q|Q)
                printf_tr "M_0513"
                return 0
                ;;
            *)
                printf_tr "M_0512"
                ;;
        esac
    done
}

# ------------------------------ Initial Backup & Manifest ---------------------

init_install_manifest() {
    install -d -m 0700 -o root -g root "${STATE_DIR}"
    if [[ ! -f "${INSTALL_MANIFEST_FILE}" ]]; then
        cat > "${INSTALL_MANIFEST_FILE}" <<EOF
# FORMAT=v1
# INSTALLER_VERSION=${INSTALLER_VERSION}
# INSTALL_DATE=$(date -Is)
# TYPE	COMPONENT	OBJECT	META	SHA256
EOF
        chmod 0600 "${INSTALL_MANIFEST_FILE}"
        log_info_tr "installation.log" "M_0282" "${INSTALL_MANIFEST_FILE}"
    fi
}

manifest_record() {
    local rec_type="$1"
    local rec_comp="$2"
    local rec_obj="$3"
    local rec_meta="${4:--}"
    local rec_sha="${5:-}"

    [[ -f "${INSTALL_MANIFEST_FILE}" ]] || init_install_manifest

    if [[ -z "${rec_sha}" ]]; then
        if [[ -L "${rec_obj}" ]]; then
            rec_sha="symlink:$(readlink "${rec_obj}" 2>/dev/null || echo unknown)"
        elif [[ -f "${rec_obj}" ]]; then
            rec_sha="$(sha256sum "${rec_obj}" 2>/dev/null | awk '{print $1}' || echo "-")"
        else
            rec_sha="-"
        fi
    fi

    local tmp_mf="${INSTALL_MANIFEST_FILE}.tmp"
    awk -F'\t' -v t="${rec_type}" -v c="${rec_comp}" -v o="${rec_obj}" '
        /^#/ { print; next }
        ($1 == t && $2 == c && $3 == o) { next }
        { print }
    ' "${INSTALL_MANIFEST_FILE}" > "${tmp_mf}"
    printf '%s\t%s\t%s\t%s\t%s\n' "${rec_type}" "${rec_comp}" "${rec_obj}" "${rec_meta}" "${rec_sha}" >> "${tmp_mf}"
    chmod 0600 "${tmp_mf}"
    mv -f "${tmp_mf}" "${INSTALL_MANIFEST_FILE}"
}

init_initial_backup_store() {
    install -d -m 0700 -o root -g root "${STATE_DIR}" "${BACKUP_ROOT}"
    if [[ -f "${INITIAL_BACKUP_SEAL}" ]]; then
        log_info_tr "rollback.log" "M_0276" "${INITIAL_BACKUP_DIR}"
        return 0
    fi

    log_info_tr "rollback.log" "M_0275" "${INITIAL_BACKUP_DIR}"
    install -d -m 0700 -o root -g root "${INITIAL_BACKUP_DIR}" "${INITIAL_BACKUP_DIR}/fs"

    if [[ ! -f "${INITIAL_BACKUP_MANIFEST}" ]]; then
        cat > "${INITIAL_BACKUP_MANIFEST}" <<EOF
# FORMAT=v1
# INSTALLER_VERSION=${INSTALLER_VERSION}
# CREATED_AT=$(date -Is)
# TIMESTAMP	PATH	TYPE	MODE	OWNER	GROUP	LINK_TARGET	SHA256	BACKUP_REL
EOF
        chmod 0600 "${INITIAL_BACKUP_MANIFEST}"
    fi

    if [[ ! -f "${INITIAL_BACKUP_DIR}/meta.env" ]]; then
        cat > "${INITIAL_BACKUP_DIR}/meta.env" <<EOF
INITIAL_BACKUP_DATE="$(date -Is)"
INSTALLER_VERSION="${INSTALLER_VERSION}"
OS_ID="${OS_ID:-unknown}"
OS_VERSION_ID="${OS_VERSION_ID:-unknown}"
KERNEL_VER="${KERNEL_VER:-unknown}"
EOF
        chmod 0600 "${INITIAL_BACKUP_DIR}/meta.env"
    fi

    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-packages.list" ]]; then
        dpkg-query -W -f='${Package}\n' 2>/dev/null | sort -u > "${INITIAL_BACKUP_DIR}/preinstall-packages.list" || true
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-packages.list"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-users.list" ]]; then
        getent passwd | cut -d: -f1 | sort -u > "${INITIAL_BACKUP_DIR}/preinstall-users.list"
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-users.list"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-groups.list" ]]; then
        getent group | cut -d: -f1 | sort -u > "${INITIAL_BACKUP_DIR}/preinstall-groups.list"
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-groups.list"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt" ]]; then
        if command -v ufw >/dev/null 2>&1; then
            local ufw_stat
            ufw_stat="$(ufw status 2>/dev/null | head -n 1 || echo "Status: inactive")"
            printf 'UFW_INSTALLED=yes\n%s\n' "${ufw_stat}" > "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt"
        else
            printf 'UFW_INSTALLED=no\nStatus: not-installed\n' > "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt"
        fi
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-iptables.v4" ]] && command -v iptables-save >/dev/null 2>&1; then
        iptables-save > "${INITIAL_BACKUP_DIR}/preinstall-iptables.v4" 2>/dev/null || true
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-iptables.v4"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-iptables.v6" ]] && command -v ip6tables-save >/dev/null 2>&1; then
        ip6tables-save > "${INITIAL_BACKUP_DIR}/preinstall-iptables.v6" 2>/dev/null || true
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-iptables.v6"
    fi
    if [[ ! -f "${INITIAL_BACKUP_DIR}/preinstall-ipset.rules" ]] && command -v ipset >/dev/null 2>&1; then
        ipset save > "${INITIAL_BACKUP_DIR}/preinstall-ipset.rules" 2>/dev/null || true
        chmod 0600 "${INITIAL_BACKUP_DIR}/preinstall-ipset.rules"
    fi
}

backup_single_entry_before_modify() {
    local orig_path="$1"
    local component="${2:-system}"

    if [[ -f "${INITIAL_BACKUP_SEAL}" ]]; then
        return 0
    fi
    if [[ ! -e "${orig_path}" && ! -L "${orig_path}" ]]; then
        return 0
    fi
    [[ -f "${INITIAL_BACKUP_MANIFEST}" ]] || init_initial_backup_store

    # Не перезаписывать уже сохранённый оригинал
    if awk -F'\t' -v p="${orig_path}" '!/^#/ && $2 == p { found=1 } END { exit !found }' "${INITIAL_BACKUP_MANIFEST}"; then
        return 0
    fi

    local rel_path="${orig_path#/}"
    local dest_path="${INITIAL_BACKUP_DIR}/fs/${rel_path}"
    local dest_parent
    dest_parent="$(dirname "${dest_path}")"
    mkdir -p "${dest_parent}"

    local ftype="file"
    local link_target="-"
    local orig_sha="-"
    local mode_val owner_val group_val
    mode_val="$(stat -c '%a' "${orig_path}" 2>/dev/null || echo "0644")"
    owner_val="$(stat -c '%U' "${orig_path}" 2>/dev/null || echo "root")"
    group_val="$(stat -c '%G' "${orig_path}" 2>/dev/null || echo "root")"

    if [[ -L "${orig_path}" ]]; then
        ftype="symlink"
        link_target="$(readlink "${orig_path}")"
        orig_sha="symlink"
        if ! cp -a --no-dereference "${orig_path}" "${dest_path}"; then
            log_error_tr "rollback.log" "M_0277" "${orig_path}"
            return 1
        fi
        local bak_target
        bak_target="$(readlink "${dest_path}" 2>/dev/null || true)"
        if [[ "${bak_target}" != "${link_target}" ]]; then
            rm -f "${dest_path}"
            log_error_tr "rollback.log" "M_0277" "${orig_path}"
            return 1
        fi
    elif [[ -f "${orig_path}" ]]; then
        ftype="file"
        orig_sha="$(sha256sum "${orig_path}" | awk '{print $1}')"
        if ! cp -a "${orig_path}" "${dest_path}"; then
            log_error_tr "rollback.log" "M_0277" "${orig_path}"
            return 1
        fi
        local bak_sha
        bak_sha="$(sha256sum "${dest_path}" 2>/dev/null | awk '{print $1}' || true)"
        if [[ -z "${bak_sha}" || "${bak_sha}" != "${orig_sha}" ]]; then
            rm -f "${dest_path}"
            log_error_tr "rollback.log" "M_0277" "${orig_path}"
            return 1
        fi
        if command -v getfacl >/dev/null 2>&1; then
            getfacl -p "${orig_path}" > "${dest_path}.acl" 2>/dev/null || rm -f "${dest_path}.acl"
        fi
    else
        return 0
    fi

    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$(date -Is)" "${orig_path}" "${ftype}" "${mode_val}" "${owner_val}" "${group_val}" "${link_target}" "${orig_sha}" "fs/${rel_path}" \
        >> "${INITIAL_BACKUP_MANIFEST}"

    manifest_record "MODIFIED_FILE" "${component}" "${orig_path}" "initial-backup:fs/${rel_path}" "${orig_sha}"
    log_info_tr "rollback.log" "M_0278" "${orig_path}" "${orig_sha}"
    return 0
}

backup_file_before_modify() {
    local target_path="$1"
    local component="${2:-system}"

    if [[ -f "${INITIAL_BACKUP_SEAL}" ]]; then
        return 0
    fi
    if [[ ! -e "${target_path}" && ! -L "${target_path}" ]]; then
        return 0
    fi

    if [[ -d "${target_path}" && ! -L "${target_path}" ]]; then
        local entry
        while IFS= read -r -d '' entry; do
            backup_single_entry_before_modify "${entry}" "${component}" || return 1
        done < <(find "${target_path}" \( -type f -o -type l \) -print0 2>/dev/null)
        return 0
    fi

    backup_single_entry_before_modify "${target_path}" "${component}"
}

verify_backup_integrity() {
    local bdir="${1:-${INITIAL_BACKUP_DIR}}"
    local bmanifest="${bdir}/backup-manifest.tsv"
    if [[ ! -f "${bmanifest}" ]]; then
        return 1
    fi

    local checked=0
    local errors=0
    local ts orig_path ftype mode_val owner_val group_val link_target orig_sha rel_bak
    while IFS=$'\t' read -r ts orig_path ftype mode_val owner_val group_val link_target orig_sha rel_bak; do
        [[ -z "${ts}" || "${ts}" == \#* ]] && continue
        local full_bak="${bdir}/${rel_bak}"
        if [[ "${ftype}" == "file" ]]; then
            if [[ ! -f "${full_bak}" ]]; then
                log_error_tr "rollback.log" "M_0280" "${orig_path}" "${orig_sha}" "MISSING"
                errors=$((errors + 1))
                continue
            fi
            local cur_sha
            cur_sha="$(sha256sum "${full_bak}" | awk '{print $1}')"
            if [[ "${cur_sha}" != "${orig_sha}" ]]; then
                log_error_tr "rollback.log" "M_0280" "${orig_path}" "${orig_sha}" "${cur_sha}"
                errors=$((errors + 1))
                continue
            fi
            checked=$((checked + 1))
        elif [[ "${ftype}" == "symlink" ]]; then
            if [[ ! -L "${full_bak}" || "$(readlink "${full_bak}" 2>/dev/null || true)" != "${link_target}" ]]; then
                log_error_tr "rollback.log" "M_0280" "${orig_path}" "${link_target}" "SYMLINK_MISMATCH"
                errors=$((errors + 1))
                continue
            fi
            checked=$((checked + 1))
        fi
    done < "${bmanifest}"

    if [[ "${errors}" -ne 0 ]]; then
        return 1
    fi
    log_info_tr "rollback.log" "M_0281" "${bdir}" "${checked}"
    return 0
}

seal_initial_backup() {
    if [[ -f "${INITIAL_BACKUP_SEAL}" ]]; then
        return 0
    fi
    if [[ ! -f "${INITIAL_BACKUP_MANIFEST}" ]]; then
        return 0
    fi
    if ! verify_backup_integrity "${INITIAL_BACKUP_DIR}"; then
        log_error_tr "rollback.log" "M_0284"
        return 1
    fi
    local mf_sha
    mf_sha="$(sha256sum "${INITIAL_BACKUP_MANIFEST}" | awk '{print $1}')"
    cat > "${INITIAL_BACKUP_SEAL}" <<EOF
SEALED_AT=$(date -Is)
INSTALLER_VERSION=${INSTALLER_VERSION}
MANIFEST_SHA256=${mf_sha}
EOF
    chmod 0400 "${INITIAL_BACKUP_SEAL}"
    log_info_tr "rollback.log" "M_0279" "${INITIAL_BACKUP_DIR}"
}

record_postinstall_packages_and_accounts() {
    [[ -f "${INSTALL_MANIFEST_FILE}" ]] || init_install_manifest

    if [[ -f "${INITIAL_BACKUP_DIR}/preinstall-packages.list" ]]; then
        local pkg
        while IFS= read -r pkg; do
            [[ -n "${pkg}" ]] || continue
            local pkg_comp="packages"
            if [[ "${pkg}" == "nginx" ]]; then pkg_comp="nginx"; fi
            manifest_record "PACKAGE" "${pkg_comp}" "${pkg}" "apt-installed" "-"
        done < <(comm -13 "${INITIAL_BACKUP_DIR}/preinstall-packages.list" <(dpkg-query -W -f='${Package}\n' 2>/dev/null | sort -u) 2>/dev/null || true)
    fi

    if [[ -f "${INITIAL_BACKUP_DIR}/preinstall-users.list" ]]; then
        local usr
        while IFS= read -r usr; do
            case "${usr}" in
                xray)    manifest_record "USER" "xray" "${usr}" "system-user" "-" ;;
                oxidns)  manifest_record "USER" "oxidns" "${usr}" "system-user" "-" ;;
                adguard) manifest_record "USER" "adguardhome" "${usr}" "system-user" "-" ;;
            esac
        done < <(comm -13 "${INITIAL_BACKUP_DIR}/preinstall-users.list" <(getent passwd | cut -d: -f1 | sort -u) 2>/dev/null || true)
    fi

    if [[ -f "${INITIAL_BACKUP_DIR}/preinstall-groups.list" ]]; then
        local grp
        while IFS= read -r grp; do
            case "${grp}" in
                xray)         manifest_record "GROUP" "xray" "${grp}" "system-group" "-" ;;
                oxidns)       manifest_record "GROUP" "oxidns" "${grp}" "system-group" "-" ;;
                adguard)      manifest_record "GROUP" "adguardhome" "${grp}" "system-group" "-" ;;
                ssl-smartdns) manifest_record "GROUP" "certificates" "${grp}" "system-group" "-" ;;
            esac
        done < <(comm -13 "${INITIAL_BACKUP_DIR}/preinstall-groups.list" <(getent group | cut -d: -f1 | sort -u) 2>/dev/null || true)
    fi
}

record_full_install_manifest() {
    init_install_manifest

    # Компоненты
    if [[ -f /etc/nginx/nginx.conf ]]; then manifest_record "COMPONENT" "nginx" "nginx" "installed" "-"; fi
    if [[ -x /usr/local/bin/xray ]]; then manifest_record "COMPONENT" "xray" "xray" "installed" "-"; fi
    if [[ -x /usr/local/bin/oxidns || -f /etc/oxidns/config.yaml ]]; then manifest_record "COMPONENT" "oxidns" "oxidns" "installed" "-"; fi
    if [[ -x /usr/local/bin/AdGuardHome || -f /etc/adguardhome/AdGuardHome.yaml ]]; then manifest_record "COMPONENT" "adguardhome" "adguardhome" "installed" "-"; fi
    if [[ -x /usr/local/bin/doh-ipset-watcher.sh || -x /usr/local/bin/dot-ipset-watcher.sh ]]; then manifest_record "COMPONENT" "ipset-watchers" "ipset-watchers" "installed" "-"; fi
    if [[ -x /usr/local/bin/smartdns-firewall-apply.sh ]]; then manifest_record "COMPONENT" "firewall" "firewall" "installed" "-"; fi
    manifest_record "COMPONENT" "systemd-timers" "systemd-timers" "installed" "-"
    if [[ -f "${CERT_DIR}/fullchain.pem" || -x /root/.acme.sh/acme.sh ]]; then manifest_record "COMPONENT" "certificates" "certificates" "installed" "-"; fi
    if [[ -d "${DNS_ASSETS_DIR}" ]]; then manifest_record "COMPONENT" "domain-rules" "domain-rules" "installed" "-"; fi
    if [[ -f "${WEB_ROOT}/index.html" ]]; then manifest_record "COMPONENT" "cover-site" "cover-site" "installed" "-"; fi
    manifest_record "COMPONENT" "installer-core" "installer-core" "installed" "-"

    # Nginx
    for f in /etc/nginx/nginx.conf /etc/systemd/system/nginx.service.d/hardening.conf \
             /etc/apt/keyrings/nginx-archive-keyring.gpg /etc/apt/sources.list.d/nginx-official.list \
             /etc/apt/preferences.d/99nginx-official /var/log/nginx/doh-auth.log /var/log/nginx/dot-auth.log; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "nginx" "${f}" "managed"; fi
    done

    # Xray
    for f in /usr/local/bin/xray /usr/local/bin/xray-safe-reload.sh "${XRAY_CONF_DIR}/00-base.json"; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "xray" "${f}" "managed"; fi
    done
    if [[ -L /etc/xray/conf.d/10-smartdns-routing.json ]]; then manifest_record "SYMLINK" "xray" "/etc/xray/conf.d/10-smartdns-routing.json" "target:${XRAY_ROUTING_JSON}"; fi
    for u in /etc/systemd/system/xray.service /etc/systemd/system/xray-reload.service; do
        if [[ -f "${u}" ]]; then manifest_record "UNIT" "xray" "${u}" "systemd-service"; fi
    done
    if [[ -f /etc/systemd/system/xray-reload.path ]]; then manifest_record "PATH_UNIT" "xray" "/etc/systemd/system/xray-reload.path" "systemd-path"; fi
    for d in /etc/xray "${XRAY_CONF_DIR}" "${XRAY_RULES_DIR}" /var/log/xray; do
        if [[ -d "${d}" ]]; then manifest_record "DIR" "xray" "${d}" "managed" "-"; fi
    done

    # OxiDNS
    for f in /usr/local/bin/oxidns /etc/oxidns/config.yaml; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "oxidns" "${f}" "managed"; fi
    done
    if [[ -f /etc/systemd/system/oxidns.service ]]; then manifest_record "UNIT" "oxidns" "/etc/systemd/system/oxidns.service" "systemd-service"; fi
    for d in /etc/oxidns /var/lib/oxidns; do
        if [[ -d "${d}" ]]; then manifest_record "DIR" "oxidns" "${d}" "managed" "-"; fi
    done

    # AdGuardHome
    for f in /usr/local/bin/AdGuardHome /etc/adguardhome/AdGuardHome.yaml; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "adguardhome" "${f}" "managed"; fi
    done
    if [[ -f /etc/systemd/system/adguardhome.service ]]; then manifest_record "UNIT" "adguardhome" "/etc/systemd/system/adguardhome.service" "systemd-service"; fi
    for d in /etc/adguardhome /var/lib/adguardhome; do
        if [[ -d "${d}" ]]; then manifest_record "DIR" "adguardhome" "${d}" "managed" "-"; fi
    done

    # Watchers
    for f in /usr/local/bin/doh-ipset-watcher.sh /usr/local/bin/dot-ipset-watcher.sh; do
        if [[ -e "${f}" ]]; then manifest_record "SCRIPT" "ipset-watchers" "${f}" "managed"; fi
    done
    for u in /etc/systemd/system/doh-ipset-watcher.service /etc/systemd/system/dot-ipset-watcher.service; do
        if [[ -f "${u}" ]]; then manifest_record "UNIT" "ipset-watchers" "${u}" "systemd-service"; fi
    done

    # Firewall & Sysctl
    for f in /usr/local/bin/smartdns-firewall-apply.sh /etc/sysctl.d/90-smartdns-keepalive.conf; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "firewall" "${f}" "managed"; fi
    done
    if [[ -f /etc/systemd/system/smartdns-firewall.service ]]; then manifest_record "UNIT" "firewall" "/etc/systemd/system/smartdns-firewall.service" "systemd-service"; fi
    for ch in "ipv4:nat:SMARTDNS_PREROUTING" "ipv4:filter:SMARTDNS_INPUT" "ipv4:filter:SMARTDNS_OUTPUT" \
              "ipv6:nat:SMARTDNS6_PREROUTING" "ipv6:filter:SMARTDNS6_INPUT" "ipv6:filter:SMARTDNS6_OUTPUT"; do
        manifest_record "FIREWALL_CHAIN" "firewall" "${ch}" "iptables-chain" "-"
    done
    for iset in smartdns_clients smartdns_clients6 dot_clients dot_clients6; do
        manifest_record "IPSET" "firewall" "${iset}" "ipset-table" "-"
    done
    for u_port in "80/tcp" "443/tcp" "853/tcp"; do
        manifest_record "UFW_RULE" "firewall" "${u_port}" "allow" "-"
    done

    # Domain Rules & Timers
    for f in /usr/local/bin/update-geosite.sh /usr/local/bin/update-geohide-domains.sh \
             "${XRAY_ROUTING_JSON}" "${ROUTING_VARS_FILE}" "${GEOHIDE_LIST_FILE}" \
             "${GEOHIDE_HOSTS_FILE}" "${AGH_RULES_FILE}" "${DNS_ASSETS_DIR}/geosite.dat" \
             "${DOMAIN_GROUPS_MAP_FILE}"; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "domain-rules" "${f}" "managed"; fi
    done
    for f in "${CUSTOM_ALLOW_FILE}" "${CUSTOM_DENY_FILE}"; do
        if [[ -e "${f}" ]]; then manifest_record "USER_DATA" "domain-rules" "${f}" "custom-rules"; fi
    done
    if [[ -d "${DNS_ASSETS_DIR}" ]]; then manifest_record "DIR" "domain-rules" "${DNS_ASSETS_DIR}" "managed" "-"; fi
    for u in /etc/systemd/system/geosite-update.service /etc/systemd/system/geohide-update.service; do
        if [[ -f "${u}" ]]; then manifest_record "UNIT" "systemd-timers" "${u}" "systemd-service"; fi
    done
    for t in /etc/systemd/system/geosite-update.timer /etc/systemd/system/geohide-update.timer; do
        if [[ -f "${t}" ]]; then manifest_record "TIMER" "systemd-timers" "${t}" "systemd-timer"; fi
    done

    # Certificates
    if is_hostname_profile; then
        for f in /usr/local/bin/verify-hostname-tls-keys.sh /usr/local/bin/smartdns-hostname-cert-deploy.sh /etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh; do
            if [[ -e "${f}" ]]; then manifest_record "SCRIPT" "certificates" "${f}" "managed"; fi
        done
        for f in "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem"; do
            if [[ -e "${f}" ]]; then manifest_record "CERT" "certificates" "${f}" "tls-material"; fi
        done
        if [[ -d "${CERT_DIR}" ]]; then manifest_record "DIR" "certificates" "${CERT_DIR}" "managed" "-"; fi
    else
        for f in /usr/local/bin/verify-tls-keys.sh /usr/local/bin/smartdns-cert-deploy.sh /usr/local/bin/smartdns-cert-renew.sh; do
            if [[ -e "${f}" ]]; then manifest_record "SCRIPT" "certificates" "${f}" "managed"; fi
        done
        for f in "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem"; do
            if [[ -e "${f}" ]]; then manifest_record "CERT" "certificates" "${f}" "tls-material"; fi
        done
        if [[ -f /etc/systemd/system/smartdns-cert-renew.service ]]; then manifest_record "UNIT" "certificates" "/etc/systemd/system/smartdns-cert-renew.service" "systemd-service"; fi
        if [[ -f /etc/systemd/system/smartdns-cert-renew.timer ]]; then manifest_record "TIMER" "certificates" "/etc/systemd/system/smartdns-cert-renew.timer" "systemd-timer"; fi
        if [[ -d "${CERT_DIR}" ]]; then manifest_record "DIR" "certificates" "${CERT_DIR}" "managed" "-"; fi
    fi

    # Cover Site
    for f in "${WEB_ROOT}/index.html" "${WEB_ROOT}/404.html" "${WEB_ROOT}/favicon.svg" \
             "${WEB_ROOT}/robots.txt" "${WEB_ROOT}/sitemap.xml" \
             "${WEB_ROOT}/assets/style.css" "${WEB_ROOT}/assets/app.js"; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "cover-site" "${f}" "managed"; fi
    done
    if [[ -d "${WEB_ROOT}" ]]; then manifest_record "DIR" "cover-site" "${WEB_ROOT}" "managed" "-"; fi

    # Installer Core State
    for f in "${SETTINGS_FILE}" "${VERSIONS_FILE}" "${SECRETS_FILE}" "${IPSET_SAVE_FILE}" \
             "${STATE_DIR}/geohide-stats.env" "${STATE_DIR}/cover-site.sha256" \
             "${STATE_DIR}/10-smartdns-routing.json.lastgood" "${STATE_DIR}/latest_backup"; do
        if [[ -e "${f}" ]]; then manifest_record "FILE" "installer-core" "${f}" "state"; fi
    done
    manifest_record "DIR" "installer-core" "${STATE_DIR}" "state-dir" "-"
    manifest_record "DIR" "installer-core" "${LOG_DIR}" "log-dir" "-"

    log_info_tr "installation.log" "M_0283" "${INSTALL_MANIFEST_FILE}"
}

# ------------------------------ Backup & Rollback -----------------------------
create_system_backup() {
    CURRENT_BACKUP_DIR="${BACKUP_ROOT}/backup-${TIMESTAMP}"
    mkdir -p "${CURRENT_BACKUP_DIR}"
    chmod 0700 "${CURRENT_BACKUP_DIR}"
    install -d -m 0755 "${CURRENT_BACKUP_DIR}/fs"
    log_info_tr "rollback.log" "M_0083" "${CURRENT_BACKUP_DIR}"

    for path in /etc/nginx /etc/xray /etc/oxidns /etc/adguardhome /etc/ufw /etc/sysctl.d/90-smartdns-keepalive.conf /etc/systemd/system/nginx.service.d /etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh "${CERT_DIR}" "${STATE_DIR}/settings" "${DNS_ASSETS_DIR}" "${IPSET_SAVE_FILE}"; do
        if [[ -e "${path}" ]]; then
            local rel_path="${path#/}"
            local parent_dir
            parent_dir="${CURRENT_BACKUP_DIR}/fs/$(dirname "${rel_path}")"
            mkdir -p "${parent_dir}"
            chmod 0755 "${CURRENT_BACKUP_DIR}/fs" "${CURRENT_BACKUP_DIR}/fs/etc" "${CURRENT_BACKUP_DIR}/fs/var" "${CURRENT_BACKUP_DIR}/fs/var/lib" 2>/dev/null || true
            cp -a "${path}" "${CURRENT_BACKUP_DIR}/fs/${rel_path}"
        fi
    done

    mkdir -p "${CURRENT_BACKUP_DIR}/systemd"
    for unit in xray.service xray-reload.path xray-reload.service oxidns.service adguardhome.service \
                doh-ipset-watcher.service dot-ipset-watcher.service geohide-update.service geohide-update.timer \
                geosite-update.service geosite-update.timer smartdns-firewall.service smartdns-cert-renew.service smartdns-cert-renew.timer; do
        if [[ -f "/etc/systemd/system/${unit}" ]]; then
            cp -a "/etc/systemd/system/${unit}" "${CURRENT_BACKUP_DIR}/systemd/"
        fi
    done

    if command -v iptables-save >/dev/null 2>&1; then
        iptables-save > "${CURRENT_BACKUP_DIR}/iptables.v4" 2>/dev/null || true
    fi
    if command -v ip6tables-save >/dev/null 2>&1; then
        ip6tables-save > "${CURRENT_BACKUP_DIR}/iptables.v6" 2>/dev/null || true
    fi
    if command -v ipset >/dev/null 2>&1; then
        ipset save > "${CURRENT_BACKUP_DIR}/ipset.rules" 2>/dev/null || true
    fi

    (
        cd "${CURRENT_BACKUP_DIR}" && find fs systemd -type f -print0 2>/dev/null | xargs -0 -r sha256sum > "${CURRENT_BACKUP_DIR}/checksums.sha256"
    ) || true
    chmod 0600 "${CURRENT_BACKUP_DIR}/checksums.sha256" 2>/dev/null || true

    printf '%s\n' "${CURRENT_BACKUP_DIR}" > "${STATE_DIR}/latest_backup"
    log_info_tr "rollback.log" "M_0084" "${CURRENT_BACKUP_DIR}"
}

perform_rollback() {
    local target_backup="${1:-}"
    if [[ -z "${target_backup}" && -f "${STATE_DIR}/latest_backup" ]]; then
        target_backup="$(cat "${STATE_DIR}/latest_backup")"
    fi
    if [[ -z "${target_backup}" || ! -d "${target_backup}" ]]; then
        log_error_tr "rollback.log" "M_0085"
        exit 1
    fi

    TRANSACTION_ACTIVE=0
    log_warn_tr "rollback.log" "M_0086" "${target_backup}"

    if command -v ufw >/dev/null 2>&1; then
        ufw allow OpenSSH >/dev/null 2>&1 || ufw allow 22/tcp >/dev/null 2>&1 || true
    fi

    if [[ -d "${target_backup}/fs" ]]; then
        chmod 0755 "${target_backup}/fs" "${target_backup}/fs/etc" "${target_backup}/fs/var" "${target_backup}/fs/var/lib" 2>/dev/null || true
        cp -a "${target_backup}/fs/." /
        chmod 0755 / /etc /var /var/lib /var/log /usr /usr/local /usr/local/bin /run /etc/ssl /etc/ssl/certs
        chmod 0644 /etc/ssl/certs/ca-certificates.crt /etc/resolv.conf 2>/dev/null || true
    fi
    if [[ -d "${target_backup}/systemd" ]]; then
        cp -a "${target_backup}/systemd/." /etc/systemd/system/
        systemctl daemon-reload || true
    fi
    if [[ -f "${target_backup}/ipset.rules" ]] && command -v ipset >/dev/null 2>&1; then
        ipset restore -! < "${target_backup}/ipset.rules" || true
    fi
    if [[ -f "${target_backup}/iptables.v4" ]] && command -v iptables-restore >/dev/null 2>&1; then
        iptables-restore < "${target_backup}/iptables.v4" || true
    fi
    if [[ -f "${target_backup}/iptables.v6" ]] && command -v ip6tables-restore >/dev/null 2>&1; then
        ip6tables-restore < "${target_backup}/iptables.v6" || true
    fi

    local restored_engine="oxidns"
    if [[ -f "${SETTINGS_FILE}" ]]; then
        restored_engine="$(awk -F'"' '/^DNS_ENGINE=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || echo "oxidns")"
    fi

    if [[ "${restored_engine}" == "adguardhome" ]]; then
        chown -R adguard:xray "${DNS_ASSETS_DIR}" "${XRAY_RULES_DIR}" 2>/dev/null || true
        systemctl disable --now oxidns.service 2>/dev/null || true
        systemctl enable --now adguardhome.service 2>/dev/null || true
    else
        chown -R oxidns:xray "${DNS_ASSETS_DIR}" "${XRAY_RULES_DIR}" 2>/dev/null || true
        systemctl disable --now adguardhome.service 2>/dev/null || true
        systemctl enable --now oxidns.service 2>/dev/null || true
    fi

    wait_for_dns_backend_ready "${restored_engine}" || true

    for svc in nginx xray doh-ipset-watcher dot-ipset-watcher; do
        if systemctl list-unit-files "${svc}.service" >/dev/null 2>&1; then
            systemctl restart "${svc}" 2>/dev/null || true
        fi
    done

    log_info_tr "rollback.log" "M_0087" "${target_backup}" "${restored_engine}"
}

# ------------------------------ Base Dependencies -----------------------------
install_system_packages() {
    log_info_tr "installation.log" "M_0088"
    umask 022
    export DEBIAN_FRONTEND=noninteractive
    export NEEDRESTART_MODE=l
    export NEEDRESTART_SUSPEND=1
    apt-get update -y -q
    apt-get install -y -q curl ca-certificates gnupg2 lsb-release jq ufw ipset conntrack \
        dnsutils openssl tar unzip socat cron logrotate python3-bcrypt

    chmod 0755 /etc/ssl /etc/ssl/certs /usr/share/ca-certificates 2>/dev/null || true
    find /usr/share/ca-certificates -type d -exec chmod 0755 {} + 2>/dev/null || true
    find /usr/share/ca-certificates -type f -exec chmod 0644 {} + 2>/dev/null || true
    update-ca-certificates --fresh >/dev/null 2>&1 || true
    chmod 0644 /etc/ssl/certs/ca-certificates.crt /etc/resolv.conf 2>/dev/null || true

    backup_file_before_modify "/etc/apt/keyrings/nginx-archive-keyring.gpg" "nginx" || return 1
    backup_file_before_modify "/etc/apt/sources.list.d/nginx-official.list" "nginx" || return 1
    backup_file_before_modify "/etc/apt/preferences.d/99nginx-official" "nginx" || return 1
    backup_file_before_modify "/etc/nginx/nginx.conf" "nginx" || return 1

    install -d -m 0755 /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/nginx-archive-keyring.gpg ]]; then
        curl -fsSL https://nginx.org/keys/nginx_signing.key | gpg --dearmor -o /etc/apt/keyrings/nginx-archive-keyring.gpg
        chmod 0644 /etc/apt/keyrings/nginx-archive-keyring.gpg
    fi

    if [[ "${OS_ID}" == "debian" ]]; then
        printf 'deb [signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/debian %s nginx\n' "${OS_CODENAME}" \
            > /etc/apt/sources.list.d/nginx-official.list
    else
        printf 'deb [signed-by=/etc/apt/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/ubuntu %s nginx\n' "${OS_CODENAME}" \
            > /etc/apt/sources.list.d/nginx-official.list
    fi

    cat > /etc/apt/preferences.d/99nginx-official <<'EOF'
Package: *
Pin: origin nginx.org
Pin: release o=nginx
Pin-Priority: 900
EOF

    apt-get update -y -q
    apt-get install -y -q nginx
    umask 027
    NGINX_INSTALLED_VER="$(nginx -v 2>&1 | awk -F'/' '{print $2}')"
    log_info_tr "installation.log" "M_0089" "${NGINX_INSTALLED_VER}"
    check_reboot_required 1 || true
}

# ------------------------------ Users & Permissions ---------------------------
setup_users_and_dirs() {
    log_info_tr "installation.log" "M_0090"

    chmod 0755 / /etc /var /var/lib /var/log /usr /usr/local /usr/local/bin /run /etc/ssl /etc/ssl/certs 2>/dev/null || true
    chmod 0644 /etc/ssl/certs/ca-certificates.crt /etc/resolv.conf 2>/dev/null || true

    for usr in xray "${DNS_USER}"; do
        if ! getent group "${usr}" >/dev/null 2>&1; then
            groupadd --system "${usr}"
        fi
        if ! id -u "${usr}" >/dev/null 2>&1; then
            useradd --system --gid "${usr}" --no-create-home --home-dir /nonexistent --shell /usr/sbin/nologin "${usr}"
        else
            usermod --shell /usr/sbin/nologin --home /nonexistent "${usr}"
        fi
    done

    if ! getent group ssl-smartdns >/dev/null 2>&1; then
        groupadd --system ssl-smartdns
    fi

    usermod -aG xray "${DNS_USER}"
    usermod -aG "${DNS_USER}" xray

    if ! id -u www-data >/dev/null 2>&1; then
        useradd --system --no-create-home --shell /usr/sbin/nologin www-data
    fi
    usermod -aG ssl-smartdns www-data
    gpasswd -d xray ssl-smartdns >/dev/null 2>&1 || true

    install -d -m 0700 -o root -g root "${STATE_DIR}" "${BACKUP_ROOT}"
    install -d -m 0750 -o root -g xray /etc/xray "${XRAY_CONF_DIR}"
    install -d -m 2750 -o "${DNS_USER}" -g xray "${XRAY_RULES_DIR}" "${DNS_ASSETS_DIR}"
    install -d -m 0750 -o root -g ssl-smartdns "${CERT_DIR}"
    install -d -m 0755 -o root -g root "${WEB_ROOT}" "${WEB_ROOT}/assets"
    install -d -m 0750 -o "${DNS_USER}" -g "${DNS_USER}" "/etc/${DNS_ENGINE}" "/var/lib/${DNS_ENGINE}"

    chown -R "${DNS_USER}:xray" "${DNS_ASSETS_DIR}" "${XRAY_RULES_DIR}" 2>/dev/null || true
    touch "${CUSTOM_ALLOW_FILE}" "${CUSTOM_DENY_FILE}" "${GEOHIDE_LIST_FILE}" "${GEOHIDE_HOSTS_FILE}"
    chown "${DNS_USER}:xray" "${CUSTOM_ALLOW_FILE}" "${CUSTOM_DENY_FILE}" "${GEOHIDE_LIST_FILE}" "${GEOHIDE_HOSTS_FILE}"
    chmod 0640 "${CUSTOM_ALLOW_FILE}" "${CUSTOM_DENY_FILE}" "${GEOHIDE_LIST_FILE}" "${GEOHIDE_HOSTS_FILE}"
}

save_persistent_settings() {
    DOH_HOST="${ROOT_DOMAIN}"
    if [[ -f "${SETTINGS_FILE}" ]]; then
        cp -p "${SETTINGS_FILE}" "${SETTINGS_FILE}.bak" 2>/dev/null || true
        chmod 0600 "${SETTINGS_FILE}.bak" 2>/dev/null || true
    fi

    local eff_profile="cloudflare"
    local eff_dns_provider="cloudflare"
    local eff_tls_mode="acme-cloudflare"
    if is_hostname_profile; then
        eff_profile="hostname"
        eff_dns_provider="external"
        eff_tls_mode="existing-certbot"
    fi

    local tmp_settings="${SETTINGS_FILE}.tmp"
    cat > "${tmp_settings}" <<EOF
INSTALL_PROFILE="${eff_profile}"
DNS_PROVIDER="${eff_dns_provider}"
TLS_MODE="${eff_tls_mode}"
DNS_ENGINE="${DNS_ENGINE}"
DNS_USER="${DNS_USER}"
ROOT_DOMAIN="${ROOT_DOMAIN}"
DOH_HOST="${ROOT_DOMAIN}"
DOT_HOST="${DOT_HOST}"
DOT_WHITELIST_ENABLED="${DOT_WHITELIST_ENABLED}"
DOT_WHITELIST_MODE="${DOT_WHITELIST_MODE}"
SELECTED_DOMAIN_GROUPS="${SELECTED_DOMAIN_GROUPS:-ALL}"
EXCLUDE_GOOGLE_SYS="${EXCLUDE_GOOGLE_SYS}"
INCLUDE_XBOX_IPIFY="${INCLUDE_XBOX_IPIFY}"
SERVER_IPV4="${SERVER_IPV4}"
SERVER_IPV6="${SERVER_IPV6}"
HAS_IPV6="${HAS_IPV6}"
PRIMARY_IFACE="${PRIMARY_IFACE}"
ACME_EMAIL="${ACME_EMAIL:-}"
EOF
    if is_hostname_profile; then
        local profile_key
        for profile_key in PROVIDER_HOSTNAME PUBLIC_IPV4 PUBLIC_IPV6 HOSTNAME_CERT_LINEAGE HOSTNAME_ACME_WEBROOT HOSTNAME_RENEWAL_CONF; do
            printf '%s=%q\n' "${profile_key}" "${!profile_key:-}" >> "${tmp_settings}"
        done
    fi
    chmod 0600 "${tmp_settings}"
    mv -f "${tmp_settings}" "${SETTINGS_FILE}"

    local tmp_vars="${ROUTING_VARS_FILE}.tmp"
    cat > "${tmp_vars}" <<EOF
DNS_ENGINE="${DNS_ENGINE}"
DOT_WHITELIST_ENABLED="${DOT_WHITELIST_ENABLED}"
DOT_WHITELIST_MODE="${DOT_WHITELIST_MODE}"
SELECTED_DOMAIN_GROUPS="${SELECTED_DOMAIN_GROUPS:-ALL}"
EXCLUDE_GOOGLE_SYS="${EXCLUDE_GOOGLE_SYS}"
INCLUDE_XBOX_IPIFY="${INCLUDE_XBOX_IPIFY}"
SERVER_IPV4="${SERVER_IPV4}"
EOF
    chown "${DNS_USER}:xray" "${tmp_vars}"
    chmod 0640 "${tmp_vars}"
    mv -f "${tmp_vars}" "${ROUTING_VARS_FILE}"

    local tmp_secrets="${SECRETS_FILE}.tmp"
    if is_hostname_profile; then
        cat > "${tmp_secrets}" <<EOF
DOH_PATH="${DOH_PATH}"
EOF
    else
        cat > "${tmp_secrets}" <<EOF
DOH_PATH="${DOH_PATH}"
CF_API_TOKEN="${CF_API_TOKEN}"
EOF
    fi
    if [[ -n "${AGH_ADMIN_USER:-}" ]]; then
        printf 'AGH_ADMIN_USER="%s"\n' "${AGH_ADMIN_USER}" >> "${tmp_secrets}"
    fi
    if [[ -n "${AGH_ADMIN_PASS:-}" ]]; then
        printf 'AGH_ADMIN_PASS="%s"\n' "${AGH_ADMIN_PASS}" >> "${tmp_secrets}"
    fi
    chmod 0600 "${tmp_secrets}"
    mv -f "${tmp_secrets}" "${SECRETS_FILE}"
}

# ------------------------------ Binary Installers -----------------------------
install_xray_binary() {
    local tag_name="${XRAY_DEFAULT_VER}"
    local zip_url=""

    case "${CPU_ARCH}" in
        x86_64)
            zip_url="https://github.com/XTLS/Xray-core/releases/download/${tag_name}/Xray-linux-64.zip"
            ;;
        aarch64)
            zip_url="https://github.com/XTLS/Xray-core/releases/download/${tag_name}/Xray-linux-arm64-v8a.zip"
            ;;
        *)
            log_error_tr "xray.log" "M_0091" "${CPU_ARCH}"
            exit 1
            ;;
    esac

    log_info_tr "xray.log" "M_0092" "${tag_name}"
    local api_json=""
    if api_json="$(curl -fsSL --retry 2 --connect-timeout 10 https://api.github.com/repos/XTLS/Xray-core/releases/latest 2>/dev/null)"; then
        local latest_tag
        latest_tag="$(printf '%s' "${api_json}" | jq -r '.tag_name // empty')"
        local pre_flag
        pre_flag="$(printf '%s' "${api_json}" | jq -r '.prerelease // true')"
        if [[ -n "${latest_tag}" && "${latest_tag}" != "null" && "${pre_flag}" == "false" ]]; then
            tag_name="${latest_tag}"
            if [[ "${CPU_ARCH}" == "x86_64" ]]; then
                zip_url="https://github.com/XTLS/Xray-core/releases/download/${tag_name}/Xray-linux-64.zip"
            else
                zip_url="https://github.com/XTLS/Xray-core/releases/download/${tag_name}/Xray-linux-arm64-v8a.zip"
            fi
        fi
    else
        log_warn_tr "xray.log" "M_0093" "${zip_url}"
    fi

    local dgst_url="${zip_url}.dgst"
    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/xray-install.XXXXXX)"

    log_info_tr "xray.log" "M_0094" "${tag_name}" "${zip_url}"
    curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp_dir}/Xray.zip" "${zip_url}"
    curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp_dir}/Xray.zip.dgst" "${dgst_url}"

    local expected_sha256
    expected_sha256="$(awk -F'= ' '/SHA2-256=/ {print $2; exit}' "${tmp_dir}/Xray.zip.dgst" | tr -d ' \r\n')"
    local actual_sha256
    actual_sha256="$(sha256sum "${tmp_dir}/Xray.zip" | awk '{print $1}')"

    if [[ -z "${expected_sha256}" || "${expected_sha256}" != "${actual_sha256}" ]]; then
        rm -rf "${tmp_dir}"
        log_error_tr "xray.log" "M_0095" "${expected_sha256}" "${actual_sha256}"
        exit 1
    fi

    unzip -q "${tmp_dir}/Xray.zip" -d "${tmp_dir}/unpacked"
    if [[ ! -x "${tmp_dir}/unpacked/xray" ]]; then
        chmod +x "${tmp_dir}/unpacked/xray"
    fi

    local ver_out
    ver_out="$("${tmp_dir}/unpacked/xray" version | sed -n '1p')"
    install -m 0755 -o root -g root "${tmp_dir}/unpacked/xray" /usr/local/bin/xray.new
    mv -f /usr/local/bin/xray.new /usr/local/bin/xray
    rm -rf "${tmp_dir}"

    XRAY_INSTALLED_VER="${tag_name}"
    XRAY_SOURCE_URL="${zip_url}"
    log_info_tr "xray.log" "M_0096" "${ver_out}" "${tag_name}"
}

install_oxidns_binary() {
    if [[ "${CPU_ARCH}" != "x86_64" ]]; then
        log_error_tr "dns.log" "M_0097" "${CPU_ARCH}"
        exit 1
    fi

    local target_ver="${OXIDNS_DEFAULT_VER}"
    local target_url="${OXIDNS_DEFAULT_URL}"

    log_info_tr "dns.log" "M_0098" "${OXIDNS_REPO}"
    local latest_json=""
    if latest_json="$(curl -fsSL --retry 2 --connect-timeout 10 https://api.github.com/repos/svenshi/oxidns/releases/latest 2>/dev/null)"; then
        local latest_tag
        latest_tag="$(printf '%s' "${latest_json}" | jq -r '.tag_name // empty')"
        local latest_pre
        latest_pre="$(printf '%s' "${latest_json}" | jq -r '.prerelease // true')"
        local latest_asset
        latest_asset="$(printf '%s' "${latest_json}" | jq -r '.assets[]? | select(.name | test("x86_64.*linux.*tar\\.gz$")) | .browser_download_url' | sed -n '1p')"
        if [[ -n "${latest_tag}" && "${latest_pre}" == "false" && -n "${latest_asset}" ]]; then
            target_ver="${latest_tag}"
            target_url="${latest_asset}"
        fi
    fi

    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/oxidns-install.XXXXXX)"
    log_info_tr "dns.log" "M_0099" "${target_ver}" "${target_url}"
    curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp_dir}/oxidns.tar.gz" "${target_url}"

    if ! gzip -t "${tmp_dir}/oxidns.tar.gz" 2>/dev/null; then
        rm -rf "${tmp_dir}"
        log_error_tr "dns.log" "M_0100"
        exit 1
    fi

    tar -xzf "${tmp_dir}/oxidns.tar.gz" -C "${tmp_dir}"
    local bin_path
    bin_path="$(find "${tmp_dir}" -type f -name "oxidns" | sed -n '1p')"
    if [[ -z "${bin_path}" ]]; then
        rm -rf "${tmp_dir}"
        log_error_tr "dns.log" "M_0101"
        exit 1
    fi
    chmod 0755 "${bin_path}"

    local actual_ver
    actual_ver="$("${bin_path}" --version 2>&1 || "${bin_path}" -V 2>&1 || echo "${target_ver}")"
    install -m 0755 -o root -g root "${bin_path}" /usr/local/bin/oxidns.new
    mv -f /usr/local/bin/oxidns.new /usr/local/bin/oxidns
    rm -rf "${tmp_dir}"

    DNS_INSTALLED_VER="${target_ver} (${actual_ver})"
    DNS_SOURCE_URL="${target_url}"
    log_info_tr "dns.log" "M_0102" "${DNS_INSTALLED_VER}"
}

install_adguardhome_binary() {
    log_info_tr "dns.log" "M_0103"
    local api_json
    api_json="$(curl -fsSL --retry 3 --connect-timeout 10 https://api.github.com/repos/AdguardTeam/AdGuardHome/releases/latest)"
    local tag_name
    tag_name="$(printf '%s' "${api_json}" | jq -r '.tag_name')"
    local pre_flag
    pre_flag="$(printf '%s' "${api_json}" | jq -r '.prerelease')"
    if [[ -z "${tag_name}" || "${tag_name}" == "null" || "${pre_flag}" != "false" ]]; then
        log_error_tr "dns.log" "M_0104"
        exit 1
    fi

    local agh_arch=""
    case "${CPU_ARCH}" in
        x86_64)  agh_arch="amd64" ;;
        aarch64) agh_arch="arm64" ;;
        *)
            log_error_tr "dns.log" "M_0105" "${CPU_ARCH}"
            exit 1
            ;;
    esac

    local tar_url="https://github.com/AdguardTeam/AdGuardHome/releases/download/${tag_name}/AdGuardHome_linux_${agh_arch}.tar.gz"
    local tmp_dir
    tmp_dir="$(mktemp -d /tmp/agh-install.XXXXXX)"
    curl -fsSL --retry 3 --connect-timeout 15 -o "${tmp_dir}/agh.tar.gz" "${tar_url}"

    tar -xzf "${tmp_dir}/agh.tar.gz" -C "${tmp_dir}"
    if [[ ! -f "${tmp_dir}/AdGuardHome/AdGuardHome" ]]; then
        rm -rf "${tmp_dir}"
        log_error_tr "dns.log" "M_0106"
        exit 1
    fi

    chmod 0755 "${tmp_dir}/AdGuardHome/AdGuardHome"
    local ver_out
    ver_out="$("${tmp_dir}/AdGuardHome/AdGuardHome" --version 2>&1 | sed -n '1p')"
    install -m 0755 -o root -g root "${tmp_dir}/AdGuardHome/AdGuardHome" /usr/local/bin/AdGuardHome.new
    mv -f /usr/local/bin/AdGuardHome.new /usr/local/bin/AdGuardHome
    rm -rf "${tmp_dir}"

    DNS_INSTALLED_VER="${tag_name} (${ver_out})"
    DNS_SOURCE_URL="${tar_url}"
    log_info_tr "dns.log" "M_0107" "${DNS_INSTALLED_VER}"
}

record_installed_versions() {
    if [[ -z "${NGINX_INSTALLED_VER:-}" ]] && command -v nginx >/dev/null 2>&1; then
        NGINX_INSTALLED_VER="$(nginx -v 2>&1 | awk -F'/' '{print $2}' || echo "unknown")"
    fi
    NGINX_INSTALLED_VER="${NGINX_INSTALLED_VER:-unknown}"
    local tmp_ver="${VERSIONS_FILE}.tmp"
    cat > "${tmp_ver}" <<EOF
INSTALL_DATE="$(date -Is)"
INSTALLER_VERSION="${INSTALLER_VERSION}"
DNS_ENGINE="${DNS_ENGINE}"
DNS_VERSION="${DNS_INSTALLED_VER}"
DNS_SOURCE_URL="${DNS_SOURCE_URL}"
XRAY_VERSION="${XRAY_INSTALLED_VER}"
XRAY_SOURCE_URL="${XRAY_SOURCE_URL}"
NGINX_VERSION="${NGINX_INSTALLED_VER}"
NGINX_SOURCE="http://nginx.org/packages/${OS_ID}"
GEOHIDE_REPO="${GEOHIDE_REPO}"
GEOHIDE_SOURCE_URL="${GEOHIDE_RAW_URL}"
EOF
    chmod 0640 "${tmp_ver}"
    mv -f "${tmp_ver}" "${VERSIONS_FILE}"
}

# ------------------------------ Cloudflare DNS Synchronization ----------------
sync_cloudflare_dns_records() {
    local new_ipv4="$1"
    local new_ipv6="${2:-}"

    # shellcheck disable=SC1091
    [[ -f "${SECRETS_FILE}" ]] && source "${SECRETS_FILE}"

    if [[ -z "${CF_API_TOKEN:-}" || "${CF_API_TOKEN}" == "REUSE_EXISTING_CERT_TOKEN" ]]; then
        if [[ -t 0 ]]; then
            read -r -s -p "Введите Cloudflare API Token (с правами Zone:DNS:Edit для ${ROOT_DOMAIN}): " CF_API_TOKEN
            printf '\n'
            if [[ -n "${CF_API_TOKEN}" && "${#CF_API_TOKEN}" -ge 20 ]]; then
                sed -i "s|^CF_API_TOKEN=.*|CF_API_TOKEN=\"${CF_API_TOKEN}\"|" "${SECRETS_FILE}" 2>/dev/null || true
            else
                log_error_tr "update.log" "M_0108"
                return 1
            fi
        else
            log_warn_tr "update.log" "M_0109" "${SECRETS_FILE}"
            return 1
        fi
    fi

    log_info_tr "update.log" "M_0110" "${ROOT_DOMAIN}"
    local zone_resp
    zone_resp="$(curl -fsSL --retry 3 --connect-timeout 10 -G \
        "https://api.cloudflare.com/client/v4/zones" \
        --data-urlencode "name=${ROOT_DOMAIN}" \
        --data-urlencode "status=active" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" 2>/dev/null || true)"

    local zone_id
    zone_id="$(printf '%s' "${zone_resp}" | jq -r '.result[0].id // empty' 2>/dev/null || true)"
    if [[ -z "${zone_id}" ]]; then
        log_error_tr "update.log" "M_0111" "${ROOT_DOMAIN}"
        return 1
    fi

    upsert_cf_record() {
        local rec_type="$1"
        local rec_name="$2"
        local rec_content="$3"
        local create_if_missing="$4"

        local search_resp
        search_resp="$(curl -fsSL --retry 3 --connect-timeout 10 -G \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            --data-urlencode "type=${rec_type}" \
            --data-urlencode "name=${rec_name}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" 2>/dev/null || true)"

        local rec_id
        rec_id="$(printf '%s' "${search_resp}" | jq -r '.result[0].id // empty' 2>/dev/null || true)"

        local payload
        payload="$(jq -n \
            --arg t "${rec_type}" \
            --arg n "${rec_name}" \
            --arg c "${rec_content}" \
            '{type: $t, name: $n, content: $c, ttl: 120, proxied: false}')"

        if [[ -n "${rec_id}" ]]; then
            local put_resp
            put_resp="$(curl -fsSL --retry 3 --connect-timeout 10 -X PUT \
                "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${rec_id}" \
                -H "Authorization: Bearer ${CF_API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "${payload}" 2>/dev/null || true)"
            if [[ "$(printf '%s' "${put_resp}" | jq -r '.success // false')" == "true" ]]; then
                log_info_tr "update.log" "M_0112" "${rec_type}" "${rec_name}" "${rec_content}"
            else
                log_error_tr "update.log" "M_0113" "${rec_type}" "${rec_name}"
                return 1
            fi
        elif [[ "${create_if_missing}" == "true" ]]; then
            local post_resp
            post_resp="$(curl -fsSL --retry 3 --connect-timeout 10 -X POST \
                "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
                -H "Authorization: Bearer ${CF_API_TOKEN}" \
                -H "Content-Type: application/json" \
                --data "${payload}" 2>/dev/null || true)"
            if [[ "$(printf '%s' "${post_resp}" | jq -r '.success // false')" == "true" ]]; then
                log_info_tr "update.log" "M_0114" "${rec_type}" "${rec_name}" "${rec_content}"
            else
                log_error_tr "update.log" "M_0115" "${rec_type}" "${rec_name}"
                return 1
            fi
        fi
    }

    delete_cf_record_if_exists() {
        local rec_type="$1"
        local rec_name="$2"
        local search_resp
        search_resp="$(curl -fsSL --retry 3 --connect-timeout 10 -G \
            "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records" \
            --data-urlencode "type=${rec_type}" \
            --data-urlencode "name=${rec_name}" \
            -H "Authorization: Bearer ${CF_API_TOKEN}" \
            -H "Content-Type: application/json" 2>/dev/null || true)"

        local rec_ids
        rec_ids="$(printf '%s' "${search_resp}" | jq -r '.result[]?.id // empty' 2>/dev/null || true)"
        for rid in ${rec_ids}; do
            curl -fsSL --retry 2 --connect-timeout 10 -X DELETE \
                "https://api.cloudflare.com/client/v4/zones/${zone_id}/dns_records/${rid}" \
                -H "Authorization: Bearer ${CF_API_TOKEN}" \
                -H "Content-Type: application/json" >/dev/null 2>&1 || true
            log_info_tr "update.log" "M_0116" "${rec_type}" "${rec_name}" "${rid}"
        done
    }

    upsert_cf_record "A" "${ROOT_DOMAIN}" "${new_ipv4}" "true"
    upsert_cf_record "A" "*.${ROOT_DOMAIN}" "${new_ipv4}" "true"
    upsert_cf_record "A" "${DOT_HOST}" "${new_ipv4}" "false"

    if [[ -n "${new_ipv6}" ]]; then
        upsert_cf_record "AAAA" "${ROOT_DOMAIN}" "${new_ipv6}" "false"
        upsert_cf_record "AAAA" "*.${ROOT_DOMAIN}" "${new_ipv6}" "false"
        upsert_cf_record "AAAA" "${DOT_HOST}" "${new_ipv6}" "false"
    else
        delete_cf_record_if_exists "AAAA" "${ROOT_DOMAIN}"
        delete_cf_record_if_exists "AAAA" "*.${ROOT_DOMAIN}"
        delete_cf_record_if_exists "AAAA" "${DOT_HOST}"
    fi
}

# ------------------------------ TLS & Cloudflare DNS-01 -----------------------
install_tls_verification_helper() {
    cat > /usr/local/bin/verify-tls-keys.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

CERT_FILE="${1:?Укажите путь к fullchain.pem}"
KEY_FILE="${2:?Укажите путь к privkey.pem}"
ROOT_DOM="${3:?Укажите ROOT_DOMAIN}"

if [[ ! -s "${CERT_FILE}" || ! -s "${KEY_FILE}" ]]; then
    echo "ОШИБКА: Файлы сертификата или ключа отсутствуют или пусты." >&2
    exit 1
fi

CERT_PUB_HASH="$(openssl x509 -in "${CERT_FILE}" -pubkey -noout | openssl pkey -pubin -outform DER | sha256sum | awk '{print $1}')"
KEY_PUB_HASH="$(openssl pkey -in "${KEY_FILE}" -pubout -outform DER | sha256sum | awk '{print $1}')"

if [[ -z "${CERT_PUB_HASH}" || "${CERT_PUB_HASH}" != "${KEY_PUB_HASH}" ]]; then
    echo "КРИТИЧЕСКАЯ ОШИБКА: Несовпадение SHA-256 публичных ключей fullchain.pem (${CERT_PUB_HASH}) и privkey.pem (${KEY_PUB_HASH})!" >&2
    exit 1
fi

if ! openssl x509 -in "${CERT_FILE}" -noout -checkend 86400 >/dev/null 2>&1; then
    echo "ОШИБКА: Срок действия сертификата истёк или истекает менее чем через 24 часа." >&2
    exit 1
fi

SAN_TEXT="$(openssl x509 -in "${CERT_FILE}" -noout -ext subjectAltName)"
if ! grep -Fq "DNS:${ROOT_DOM}" <<<"${SAN_TEXT}" || ! grep -Fq "DNS:*.${ROOT_DOM}" <<<"${SAN_TEXT}"; then
    echo "ОШИБКА: Сертификат не содержит обязательные SAN: ${ROOT_DOM} и *.${ROOT_DOM}." >&2
    exit 1
fi

DNS_COUNT="$(grep -o 'DNS:' <<<"${SAN_TEXT}" | wc -l)"
if [[ "${DNS_COUNT}" -ne 2 ]]; then
    echo "ОШИБКА: Сертификат содержит лишние SAN записи (ожидалось строго 2: ${ROOT_DOM} и *.${ROOT_DOM}, найдено: ${DNS_COUNT})." >&2
    exit 1
fi

echo "OK: Сертификат и ключ прошли криптографическую проверку (SHA-256 PubKey DER: ${CERT_PUB_HASH})."
EOF
    chmod 0755 /usr/local/bin/verify-tls-keys.sh
}

configure_cert_auto_renewal() {
    log_info_tr "certificate.log" "M_0369"
    install_tls_verification_helper

    install -d -m 0700 -o root -g root "${CERT_STAGE_DIR}"
    if [[ -f /root/.acme.sh/account.conf ]]; then
        chmod 0600 /root/.acme.sh/account.conf
    fi

    cat > /usr/local/bin/smartdns-cert-deploy.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

exec 9>/run/lock/smartdns-cert-deploy.lock
if ! flock -n 9; then
    exit 0
fi

# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings

LOG_FILE="/var/log/oxidns-installer/certificate.log"
CERT_DIR="/etc/ssl/smartdns"
STAGE_DIR="/var/lib/oxidns-installer/cert-stage"
ACME_ECC_DIR="/root/.acme.sh/${ROOT_DOMAIN}_ecc"

log() {
    printf '[%s] [CERT-DEPLOY] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" >> "${LOG_FILE}"
}

SRC_CERT=""
SRC_KEY=""
if [[ -s "${STAGE_DIR}/fullchain.pem" && -s "${STAGE_DIR}/privkey.pem" ]]; then
    SRC_CERT="${STAGE_DIR}/fullchain.pem"
    SRC_KEY="${STAGE_DIR}/privkey.pem"
elif [[ -s "${ACME_ECC_DIR}/fullchain.cer" && -s "${ACME_ECC_DIR}/${ROOT_DOMAIN}.key" ]]; then
    SRC_CERT="${ACME_ECC_DIR}/fullchain.cer"
    SRC_KEY="${ACME_ECC_DIR}/${ROOT_DOMAIN}.key"
else
    log "ОШИБКА: Файлы сертификата не найдены ни в ${STAGE_DIR}, ни в ${ACME_ECC_DIR}."
    exit 1
fi

if ! /usr/local/bin/verify-tls-keys.sh "${SRC_CERT}" "${SRC_KEY}" "${ROOT_DOMAIN}" >> "${LOG_FILE}" 2>&1; then
    log "ОШИБКА: Криптографическая проверка нового сертификата не пройдена. Рабочие файлы в ${CERT_DIR} сохранены без изменений."
    exit 1
fi

install -d -m 0750 -o root -g ssl-smartdns "${CERT_DIR}"
install -m 0644 -o root -g ssl-smartdns "${SRC_CERT}" "${CERT_DIR}/fullchain.pem.new"
install -m 0640 -o root -g ssl-smartdns "${SRC_KEY}" "${CERT_DIR}/privkey.pem.new"
mv -f "${CERT_DIR}/fullchain.pem.new" "${CERT_DIR}/fullchain.pem"
mv -f "${CERT_DIR}/privkey.pem.new" "${CERT_DIR}/privkey.pem"
log "Сертификат для ${ROOT_DOMAIN} атомарно установлен в ${CERT_DIR}."

if systemctl is-active --quiet nginx 2>/dev/null; then
    if nginx -t >> "${LOG_FILE}" 2>&1; then
        systemctl reload nginx
        log "Nginx успешно перезагружен с актуальным TLS-сертификатом."
    else
        log "ОШИБКА: Проверка nginx -t не пройдена после установки сертификата."
        exit 1
    fi
else
    log "Служба nginx не активна — reload пропущен (сертификат установлен)."
fi
EOF
    chmod 0750 /usr/local/bin/smartdns-cert-deploy.sh

    cat > /usr/local/bin/smartdns-cert-renew.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

exec 9>/run/lock/smartdns-cert-renew.lock
if ! flock -n 9; then
    exit 0
fi

# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings
# shellcheck disable=SC1091
[[ -f /var/lib/oxidns-installer/secrets.env ]] && source /var/lib/oxidns-installer/secrets.env

LOG_FILE="/var/log/oxidns-installer/certificate.log"
CERT_DIR="/etc/ssl/smartdns"

log() {
    printf '[%s] [CERT-RENEW] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" >> "${LOG_FILE}"
}

if [[ ! -x /root/.acme.sh/acme.sh ]]; then
    log "ОШИБКА: Клиент /root/.acme.sh/acme.sh не найден."
    exit 1
fi

if [[ -f /root/.acme.sh/account.conf ]]; then
    chmod 0600 /root/.acme.sh/account.conf
fi

log "Запуск плановой проверки продления сертификата для ${ROOT_DOMAIN}..."
if [[ -n "${CF_API_TOKEN:-}" && "${CF_API_TOKEN}" != "REUSE_EXISTING_CERT_TOKEN" ]]; then
    export CF_Token="${CF_API_TOKEN}"
fi

rc=0
/root/.acme.sh/acme.sh --cron --home /root/.acme.sh >> "${LOG_FILE}" 2>&1 || rc=$?
unset CF_Token || true

if [[ "${rc}" -ne 0 ]]; then
    log "ОШИБКА: acme.sh --cron завершился с кодом ${rc}. Действующий сертификат в ${CERT_DIR} не изменён."
    exit "${rc}"
fi

if ! /usr/local/bin/verify-tls-keys.sh "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${ROOT_DOMAIN}" >> "${LOG_FILE}" 2>&1; then
    log "ПРЕДУПРЕЖДЕНИЕ: Проверка установленного сертификата в ${CERT_DIR} не пройдена после --cron."
    exit 1
fi

log "Плановая проверка продления сертификата для ${ROOT_DOMAIN} успешно завершена."
EOF
    chmod 0750 /usr/local/bin/smartdns-cert-renew.sh

    local acme_ecc_conf="/root/.acme.sh/${ROOT_DOMAIN}_ecc/${ROOT_DOMAIN}.conf"
    if [[ -x /root/.acme.sh/acme.sh && -f "${acme_ecc_conf}" ]]; then
        if ! /root/.acme.sh/acme.sh --home /root/.acme.sh --install-cert -d "${ROOT_DOMAIN}" --ecc \
            --fullchain-file "${CERT_STAGE_DIR}/fullchain.pem" \
            --key-file "${CERT_STAGE_DIR}/privkey.pem" \
            --reloadcmd "/usr/local/bin/smartdns-cert-deploy.sh" >> "${LOG_DIR}/certificate.log" 2>&1; then
            log_warn_tr "certificate.log" "M_0371" "${ROOT_DOMAIN}"
        fi
    else
        log_info_tr "certificate.log" "M_0373" "${ROOT_DOMAIN}"
    fi

    cat > /etc/systemd/system/smartdns-cert-renew.service <<'EOF'
[Unit]
Description=SmartDNS Automated TLS Certificate Renewal (acme.sh)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/smartdns-cert-renew.sh
NoNewPrivileges=true
PrivateTmp=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
EOF

    cat > /etc/systemd/system/smartdns-cert-renew.timer <<'EOF'
[Unit]
Description=Daily SmartDNS TLS Certificate Renewal Check (03:30 Europe/Moscow)

[Timer]
OnCalendar=*-*-* 03:30:00 Europe/Moscow
RandomizedDelaySec=1800
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable --now smartdns-cert-renew.timer
    log_info_tr "certificate.log" "M_0370"
}

issue_wildcard_certificate() {
    backup_file_before_modify "${CERT_DIR}/fullchain.pem" "certificates" || return 1
    backup_file_before_modify "${CERT_DIR}/privkey.pem" "certificates" || return 1
    install_tls_verification_helper
    log_info_tr "certificate.log" "M_0117" "${ROOT_DOMAIN}"

    if [[ -s "${CERT_DIR}/fullchain.pem" && -s "${CERT_DIR}/privkey.pem" ]]; then
        if /usr/local/bin/verify-tls-keys.sh "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${ROOT_DOMAIN}" >> "${LOG_DIR}/certificate.log" 2>&1; then
            chown root:ssl-smartdns "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem"
            chmod 0644 "${CERT_DIR}/fullchain.pem"
            chmod 0640 "${CERT_DIR}/privkey.pem"
            log_info_tr "certificate.log" "M_0118" "${CERT_DIR}"
            configure_cert_auto_renewal
            return 0
        fi
    fi

    local acme_ecc_dir="/root/.acme.sh/${ROOT_DOMAIN}_ecc"
    if [[ -s "${acme_ecc_dir}/fullchain.cer" && -s "${acme_ecc_dir}/${ROOT_DOMAIN}.key" ]]; then
        if /usr/local/bin/verify-tls-keys.sh "${acme_ecc_dir}/fullchain.cer" "${acme_ecc_dir}/${ROOT_DOMAIN}.key" "${ROOT_DOMAIN}" >> "${LOG_DIR}/certificate.log" 2>&1; then
            install -m 0644 -o root -g ssl-smartdns "${acme_ecc_dir}/fullchain.cer" "${CERT_DIR}/fullchain.pem.new"
            install -m 0640 -o root -g ssl-smartdns "${acme_ecc_dir}/${ROOT_DOMAIN}.key" "${CERT_DIR}/privkey.pem.new"
            mv -f "${CERT_DIR}/fullchain.pem.new" "${CERT_DIR}/fullchain.pem"
            mv -f "${CERT_DIR}/privkey.pem.new" "${CERT_DIR}/privkey.pem"
            log_info_tr "certificate.log" "M_0119" "${acme_ecc_dir}"
            configure_cert_auto_renewal
            return 0
        fi
    fi

    log_info_tr "certificate.log" "M_0120"

    if [[ ! -x /root/.acme.sh/acme.sh ]]; then
        local tmp_acme
        tmp_acme="$(mktemp -d /tmp/acme-install.XXXXXX)"
        local git_tar_url="https://github.com/acmesh-official/acme.sh/archive/refs/heads/master.tar.gz"
        curl -fsSL --retry 3 -o "${tmp_acme}/acme.tar.gz" "${git_tar_url}"
        tar -xzf "${tmp_acme}/acme.tar.gz" -C "${tmp_acme}"
        pushd "${tmp_acme}"/acme.sh-* >/dev/null
        ./acme.sh --install --home /root/.acme.sh --accountemail "${ACME_EMAIL}" --nocron >/dev/null
        popd >/dev/null
        rm -rf "${tmp_acme}"
    fi

    install -d -m 0700 -o root -g root "${CERT_STAGE_DIR}"

    export CF_Token="${CF_API_TOKEN}"
    /root/.acme.sh/acme.sh --home /root/.acme.sh --set-default-ca --server letsencrypt >/dev/null 2>&1 || true

    log_info_tr "certificate.log" "M_0121" "${ROOT_DOMAIN}" "${ROOT_DOMAIN}"
    if ! /root/.acme.sh/acme.sh --home /root/.acme.sh --issue --dns dns_cf \
        -d "${ROOT_DOMAIN}" -d "*.${ROOT_DOMAIN}" --keylength ec-256 >> "${LOG_DIR}/certificate.log" 2>&1; then
        unset CF_Token
        log_error_tr "certificate.log" "M_0122"
        exit 1
    fi
    unset CF_Token

    configure_cert_auto_renewal

    if ! /usr/local/bin/verify-tls-keys.sh "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${ROOT_DOMAIN}" >> "${LOG_DIR}/certificate.log" 2>&1; then
        log_error_tr "certificate.log" "M_0123"
        exit 1
    fi

    log_info_tr "certificate.log" "M_0124" "${ROOT_DOMAIN}" "${ROOT_DOMAIN}"
}

# ------------------------------ GeoHideDNS & Geosite --------------------------
install_domain_update_scripts() {
    log_info_tr "dns.log" "M_0125"

    cat > /usr/local/bin/update-geosite.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

exec 9>/run/lock/update-geosite.lock
if ! flock -n 9; then
    exit 0
fi

# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings
LOG_FILE="/var/log/oxidns-installer/update.log"
TMP_DAT="/var/lib/dns-assets/geosite.dat.download"
FINAL_DAT="/var/lib/dns-assets/geosite.dat"

log() {
    printf '[%s] [GEOSITE] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" >> "${LOG_FILE}"
}

log "Начало загрузки свежего geosite.dat..."
if ! curl -fsSL --retry 3 --connect-timeout 15 --max-time 120 \
    -o "${TMP_DAT}" "https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat"; then
    rm -f "${TMP_DAT}"
    log "ОШИБКА: Не удалось скачать geosite.dat. Сохранена предыдущая версия."
    exit 1
fi

FILE_SIZE="$(stat -c%s "${TMP_DAT}" 2>/dev/null || echo 0)"
if [[ "${FILE_SIZE}" -lt 100000 ]]; then
    rm -f "${TMP_DAT}"
    log "ОШИБКА: Размер geosite.dat подозрительно мал (${FILE_SIZE} байт). Отмена обновления."
    exit 1
fi

chown "${DNS_USER}:xray" "${TMP_DAT}"
chmod 0640 "${TMP_DAT}"
mv -f "${TMP_DAT}" "${FINAL_DAT}"
log "Файл geosite.dat успешно обновлён (${FILE_SIZE} байт)."

if [[ "${DNS_ENGINE}" == "oxidns" ]] && systemctl is-active --quiet oxidns; then
    systemctl reload-or-restart oxidns
    log "Выполнена перезагрузка провайдера OxiDNS."
fi
EOF
    chmod 0755 /usr/local/bin/update-geosite.sh

    cat > /usr/local/bin/update-geohide-domains.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
umask 027

exec 9>/run/lock/update-geohide-domains.lock
if ! flock -n 9; then
    echo "Обновление GeoHideDNS уже выполняется." >&2
    exit 0
fi

# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings
# shellcheck disable=SC1091
source /var/lib/dns-assets/xray-routing-vars.env

LOG_FILE="/var/log/oxidns-installer/update.log"
ASSETS_DIR="/var/lib/dns-assets"
RAW_URL="https://raw.githubusercontent.com/Internet-Helper/GeoHideDNS/refs/heads/main/hosts/hosts"

TMP_DOWNLOAD="${ASSETS_DIR}/hosts.download"
TMP_DOMAINS="${ASSETS_DIR}/geohide-domains.new"
FINAL_DOMAINS="${ASSETS_DIR}/geohide-domains.txt"
AGH_RULES_NEW="${ASSETS_DIR}/ag-smartdns-rules.new"
AGH_RULES_FINAL="${ASSETS_DIR}/ag-smartdns-rules.txt"
XRAY_JSON_NEW="/etc/xray/rules.d/10-smartdns-routing.json.new"
XRAY_JSON_FINAL="/etc/xray/rules.d/10-smartdns-routing.json"
STATS_FILE="/var/lib/oxidns-installer/geohide-stats.env"

log() {
    printf '[%s] [GEOHIDE] %s\n' "$(date '+%Y-%m-%d %H:%M:%S %z')" "$*" >> "${LOG_FILE}"
}

cleanup_tmp() {
    rm -f "${TMP_DOWNLOAD}" "${TMP_DOMAINS}" "${AGH_RULES_NEW}" "${XRAY_JSON_NEW}" "${ASSETS_DIR}/geohide-hosts.txt.new"
}
trap cleanup_tmp EXIT

log "Загрузка исходного списка GeoHideDNS из ${RAW_URL}..."
HTTP_CODE="$(curl -sSL --retry 3 --connect-timeout 15 --max-time 60 -w '%{http_code}' -o "${TMP_DOWNLOAD}" "${RAW_URL}" || echo "000")"
if [[ "${HTTP_CODE}" != "200" || ! -s "${TMP_DOWNLOAD}" ]]; then
    log "ОШИБКА: Код ответа HTTP=${HTTP_CODE} или пустой файл. Рабочая конфигурация не изменена."
    exit 1
fi

SELECTED_GROUPS="${SELECTED_DOMAIN_GROUPS:-ALL}"
GROUPS_MAP_FILE="${ASSETS_DIR}/domain-groups.map"

group_enabled() {
    local target="$1"
    [[ "${SELECTED_GROUPS}" == "ALL" ]] && return 0
    [[ "${SELECTED_GROUPS}" == "NONE" ]] && return 1
    [[ ",${SELECTED_GROUPS}," == *",${target},"* ]]
}

awk '
    function classify_section(sec,    s) {
        s = tolower(sec)
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", s)
        if (s == "" || s ~ /^geohide\.ru/ || s ~ /^последнее обновление/ || s ~ /^регион серверов/ || s ~ /^эти ip-адреса/ || s ~ /^остальные ip-адреса/ || s ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/) {
            return ""
        }
        if (s ~ /^работающие ip/ || s ~ /^остальное$/) {
            return "other"
        }
        if (s ~ /(^|[[:space:](])ai([[:space:])]|$)/ || s ~ /(chatgpt|openai|claude|gemini|grok|groq|cursor|elevenlabs|cerebras|genspark|hume|camel|dola|kaleido|manus|monica|opencode|openrouter|reve|trae\.ai|windsurf)/) {
            return "ai"
        }
        if (s ~ /(microsoft|xbox)/) {
            return "microsoft"
        }
        if (s ~ /(37signals|atlassian|autodesk|chaos|clickup|coreweave|framer|jetbrains|linear\.app|make|mongodb|notion|oracle|posthog|slack|sketchup|tableau|tailscale|teamviewer|wix|workos|zerossl)/) {
            return "dev_cloud"
        }
        if (s ~ /(amd|analog|arduino|arrow|broadcom|corsair|cummins|dell|digikey|dyson|elgato|fitbit|intel|makita|microchip|nvidia|xerox)/) {
            return "hardware"
        }
        if (s ~ /(affinity studio|canva|capcut|crunchyroll|deezer|formula 1|imgur|last\.fm|scribd|spotify|twitch)/) {
            return "media"
        }
        if (s ~ /(chess|game8|guilded|stumble guys|supercell)/) {
            return "gaming"
        }
        if (s ~ /(arkoselabs|avast|brave|deepl|fmhy|guidedhacking|qwant|tria\.ge|tuta|web archive)/) {
            return "tools"
        }
        if (s ~ /(aave|badoo|bestbuy|bike24|ikea|lego|modivo|naukri|pump\.fun|strava|truth social|weather\.com|weather underground)/) {
            return "lifestyle"
        }
        return "other"
    }
    BEGIN { cur_grp = "other" }
    {
        sub(/\r$/, "")
        if ($0 ~ /^[[:space:]]*$/) next
        if ($0 ~ /^[[:space:]]*#/) {
            hdr = $0
            sub(/^[[:space:]]*#+[[:space:]]*/, "", hdr)
            g = classify_section(hdr)
            if (g != "") cur_grp = g
            next
        }
        if ($1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ || $1 ~ /:/) {
            for (i = 2; i <= NF; i++) {
                if ($i ~ /^#/) break
                d = tolower($i)
                sub(/^\*\./, "", d)
                sub(/^\./, "", d)
                if (d ~ /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/) {
                    print cur_grp "\t" d
                }
            }
        } else {
            d = tolower($1)
            sub(/^\*\./, "", d)
            sub(/^\./, "", d)
            if (d ~ /^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$/) {
                print cur_grp "\t" d
            }
        }
    }
' "${TMP_DOWNLOAD}" | sort -u > "${TMP_DOMAINS}.grouped"

RAW_COUNT="$(awk -F'\t' '{print $2}' "${TMP_DOMAINS}.grouped" | sort -u | wc -l | tr -d ' ')"
if [[ "${RAW_COUNT}" -lt 10 ]]; then
    log "ОШИБКА: Слишком мало валидных доменов в загруженном файле (${RAW_COUNT}). Отмена обновления."
    rm -f "${TMP_DOMAINS}.grouped"
    exit 1
fi

{
    printf '# UPDATED_AT=%s\n' "$(date -Is)"
    awk -F'\t' '{print $1}' "${TMP_DOMAINS}.grouped" | sort | uniq -c | awk '{printf "%s\t%s\n", $2, $1}'
    printf 'google_sys\t8\n'
} > "${GROUPS_MAP_FILE}.new"
chown "${DNS_USER}:xray" "${GROUPS_MAP_FILE}.new"
chmod 0640 "${GROUPS_MAP_FILE}.new"
mv -f "${GROUPS_MAP_FILE}.new" "${GROUPS_MAP_FILE}"

: > "${TMP_DOMAINS}.raw"
if [[ "${SELECTED_GROUPS}" != "NONE" ]]; then
    awk -F'\t' -v sel="${SELECTED_GROUPS}" '
        BEGIN {
            if (sel == "ALL") {
                all_mode = 1
            } else {
                n = split(sel, arr, ",")
                for (i = 1; i <= n; i++) want[arr[i]] = 1
            }
        }
        all_mode || ($1 in want) { print $2 }
    ' "${TMP_DOMAINS}.grouped" | sort -u > "${TMP_DOMAINS}.raw"
fi
rm -f "${TMP_DOMAINS}.grouped"

if group_enabled "google_sys" && [[ "${EXCLUDE_GOOGLE_SYS}" == "N" ]]; then
    cat >> "${TMP_DOMAINS}.raw" <<'GDOMS'
apis.google.com
suggestqueries.google.com
clients6.google.com
clients.google.com
withgoogle.com
o.pki.goog
googleapis.com
generativelanguage.googleapis.com
GDOMS
fi

if group_enabled "microsoft" && [[ "${INCLUDE_XBOX_IPIFY}" == "y" ]]; then
    cat >> "${TMP_DOMAINS}.raw" <<'XDOMS'
xboxlive.com
xbox.com
sfx.ms
msgamestudios.com
XDOMS
fi

if [[ -s "${ASSETS_DIR}/custom-allow.txt" ]]; then
    grep -E '^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$' "${ASSETS_DIR}/custom-allow.txt" >> "${TMP_DOMAINS}.raw" || true
fi

KEEP_GENLANG="0"
if group_enabled "ai" || { group_enabled "google_sys" && [[ "${EXCLUDE_GOOGLE_SYS}" == "N" ]]; }; then
    KEEP_GENLANG="1"
fi

awk -v excl_google="${EXCLUDE_GOOGLE_SYS}" -v incl_xbox="${INCLUDE_XBOX_IPIFY}" -v keep_gen="${KEEP_GENLANG}" '
    $0 == "generativelanguage.googleapis.com" { if (keep_gen == "1") print; next }

    # Unconditional exclusions (x.com, meta.ai + Wi-Fi Captive Portal detection domains)
    $0 == "x.com" || $0 ~ /\.x\.com$/ { next }
    $0 == "meta.ai" || $0 ~ /\.meta\.ai$/ { next }
    $0 == "connectivitycheck.gstatic.com" || $0 == "connectivitycheck.android.com" { next }
    $0 ~ /^clients[0-9]*\.google\.com$/ { next }
    $0 == "captive.apple.com" || $0 == "connect.rom.miui.com" { next }
    $0 == "msftconnecttest.com" || $0 ~ /\.msftconnecttest\.com$/ { next }
    $0 == "msftncsi.com" || $0 ~ /\.msftncsi\.com$/ { next }

    excl_google == "y" && ( \
        $0 == "apis.google.com" || \
        $0 == "suggestqueries.google.com" || \
        $0 == "o.pki.goog" || \
        $0 == "clients6.google.com" || $0 ~ /\.clients6\.google\.com$/ || \
        $0 == "clients.google.com" || $0 ~ /\.clients\.google\.com$/ || \
        $0 == "withgoogle.com" || $0 ~ /\.withgoogle\.com$/ || \
        $0 == "googleapis.com" || $0 ~ /\.googleapis\.com$/ \
    ) { next }

    incl_xbox == "N" && ( \
        $0 == "xboxlive.com" || $0 ~ /\.xboxlive\.com$/ || \
        $0 == "xbox.com" || $0 ~ /\.xbox\.com$/ \
    ) { next }

    { print }
' "${TMP_DOMAINS}.raw" > "${TMP_DOMAINS}.filtered"

if [[ "${KEEP_GENLANG}" == "1" ]]; then
    printf 'generativelanguage.googleapis.com\n' >> "${TMP_DOMAINS}.filtered"
fi

if [[ -s "${ASSETS_DIR}/custom-deny.txt" ]]; then
    grep -vFf "${ASSETS_DIR}/custom-deny.txt" "${TMP_DOMAINS}.filtered" | sort -u > "${TMP_DOMAINS}" || true
else
    sort -u "${TMP_DOMAINS}.filtered" > "${TMP_DOMAINS}"
fi
rm -f "${TMP_DOMAINS}.raw" "${TMP_DOMAINS}.filtered"

FINAL_COUNT="$(wc -l < "${TMP_DOMAINS}" | tr -d ' ')"
if [[ "${SELECTED_GROUPS}" != "NONE" && "${FINAL_COUNT}" -lt 1 ]]; then
    log "ОШИБКА: Итоговый список доменов пуст при активных группах (${SELECTED_GROUPS})."
    exit 1
fi

jq -Rn --arg root_dom "${ROOT_DOMAIN}" --arg dot_dom "${DOT_HOST}" \
       --arg srv_ip4 "${SERVER_IPV4}" --arg srv_ip6 "${SERVER_IPV6:-::1}" '
  [inputs | select(length > 0) | "domain:" + .] as $allowed |
  {
    "routing": {
      "domainStrategy": "AsIs",
      "rules": (
        [
          {
            "type": "field",
            "inboundTag": ["dot-in"],
            "domain": ["full:" + $dot_dom],
            "outboundTag": "dot-backend"
          },
          {
            "type": "field",
            "inboundTag": ["dot-in"],
            "port": "0-65535",
            "outboundTag": "block"
          },
          {
            "type": "field",
            "inboundTag": ["https-in"],
            "domain": [
              "full:" + $root_dom,
              "full:www." + $root_dom,
              "full:" + $dot_dom
            ],
            "outboundTag": "nginx-local"
          }
        ]
        + (if ($allowed | length) > 0 then [
          {
            "type": "field",
            "inboundTag": ["https-in"],
            "domain": $allowed,
            "outboundTag": "direct-v4"
          }
        ] else [] end)
        + [
          {
            "type": "field",
            "inboundTag": ["https-in"],
            "ip": (
              [
                $srv_ip4,
                "127.0.0.0/8",
                "10.0.0.0/8",
                "172.16.0.0/12",
                "192.168.0.0/16",
                "100.64.0.0/10",
                "169.254.0.0/16",
                "::1/128",
                "fc00::/7",
                "fe80::/10"
              ] + (if ($srv_ip6 != "" and $srv_ip6 != "::1") then [$srv_ip6] else [] end)
            ),
            "outboundTag": "block"
          },
          {
            "type": "field",
            "inboundTag": ["https-in"],
            "port": "0-65535",
            "outboundTag": "nginx-local"
          }
        ]
      )
    }
  }
' < "${TMP_DOMAINS}" > "${XRAY_JSON_NEW}"

TEST_DIR="$(mktemp -d /tmp/xray-validate.XXXXXX)"
cp -a /etc/xray/conf.d/00-base.json "${TEST_DIR}/00-base.json"
cp -a "${XRAY_JSON_NEW}" "${TEST_DIR}/10-smartdns-routing.json"
chmod -R 0755 "${TEST_DIR}"

if ! /usr/local/bin/xray run -test -confdir "${TEST_DIR}" >> "${LOG_FILE}" 2>&1; then
    rm -rf "${TEST_DIR}"
    log "КРИТИЧЕСКАЯ ОШИБКА: Сгенерированный 10-smartdns-routing.json не прошёл проверку xray run -test! Отказ от применения."
    exit 1
fi
rm -rf "${TEST_DIR}"

awk -v ip="${SERVER_IPV4}" 'NF > 0 {print "domain:" $1, ip}' "${TMP_DOMAINS}" > "${ASSETS_DIR}/geohide-hosts.txt.new"
chown "${DNS_USER}:xray" "${ASSETS_DIR}/geohide-hosts.txt.new"
chmod 0640 "${ASSETS_DIR}/geohide-hosts.txt.new"
mv -f "${ASSETS_DIR}/geohide-hosts.txt.new" "${ASSETS_DIR}/geohide-hosts.txt"

awk -v ip="${SERVER_IPV4}" 'NF > 0 {
    printf "||%s^$dnstype=A,dnsrewrite=NOERROR;A;%s\n", $0, ip
    printf "||%s^$dnstype=AAAA,dnsrewrite=NOERROR\n", $0
    printf "||%s^$dnstype=HTTPS|SVCB,dnsrewrite=NOERROR\n", $0
}' "${TMP_DOMAINS}" > "${AGH_RULES_NEW}"
chown "${DNS_USER}:xray" "${AGH_RULES_NEW}"
chmod 0640 "${AGH_RULES_NEW}"
mv -f "${AGH_RULES_NEW}" "${AGH_RULES_FINAL}"

chown "${DNS_USER}:xray" "${TMP_DOMAINS}" "${XRAY_JSON_NEW}"
chmod 0640 "${TMP_DOMAINS}" "${XRAY_JSON_NEW}"
mv -f "${TMP_DOMAINS}" "${FINAL_DOMAINS}"
mv -f "${XRAY_JSON_NEW}" "${XRAY_JSON_FINAL}"
ln -sf "${XRAY_JSON_FINAL}" /etc/xray/conf.d/10-smartdns-routing.json

cat > "${STATS_FILE}.tmp" <<STATS
LAST_UPDATE="$(date -Is)"
RAW_DOMAIN_COUNT="${RAW_COUNT}"
FINAL_DOMAIN_COUNT="${FINAL_COUNT}"
XRAY_RULES_STATUS="VERIFIED_OK"
STATS
mv -f "${STATS_FILE}.tmp" "${STATS_FILE}"

if systemctl is-active --quiet "${DNS_ENGINE}"; then
    systemctl reload-or-restart "${DNS_ENGINE}" || true
fi

log "Обновление успешно завершено: исходных=${RAW_COUNT}, итоговых=${FINAL_COUNT}."
EOF
    chmod 0755 /usr/local/bin/update-geohide-domains.sh
}

# ------------------------------ DNS Engine Adapters ---------------------------
render_dns_domain_lists_from_cache() {
    if [[ ! -f "${GEOHIDE_LIST_FILE}" ]] || { [[ ! -s "${GEOHIDE_LIST_FILE}" ]] && [[ "${SELECTED_DOMAIN_GROUPS:-ALL}" != "NONE" ]]; }; then
        /usr/local/bin/update-geohide-domains.sh
        return 0
    fi

    awk -v ip="${SERVER_IPV4}" 'NF > 0 {print "domain:" $1, ip}' "${GEOHIDE_LIST_FILE}" > "${GEOHIDE_HOSTS_FILE}.new"
    chown "${DNS_USER}:xray" "${GEOHIDE_HOSTS_FILE}.new"
    chmod 0640 "${GEOHIDE_HOSTS_FILE}.new"
    mv -f "${GEOHIDE_HOSTS_FILE}.new" "${GEOHIDE_HOSTS_FILE}"

    awk -v ip="${SERVER_IPV4}" 'NF > 0 {
        printf "||%s^$dnstype=A,dnsrewrite=NOERROR;A;%s\n", $0, ip
        printf "||%s^$dnstype=AAAA,dnsrewrite=NOERROR\n", $0
        printf "||%s^$dnstype=HTTPS|SVCB,dnsrewrite=NOERROR\n", $0
    }' "${GEOHIDE_LIST_FILE}" > "${AGH_RULES_FILE}.new"
    chown "${DNS_USER}:xray" "${AGH_RULES_FILE}.new"
    chmod 0640 "${AGH_RULES_FILE}.new"
    mv -f "${AGH_RULES_FILE}.new" "${AGH_RULES_FILE}"
}

configure_dns_engine() {
    if [[ "${DNS_ENGINE}" == "oxidns" ]]; then
        log_info_tr "dns.log" "M_0126"
        install -d -m 0750 -o oxidns -g oxidns /var/lib/oxidns

        render_dns_domain_lists_from_cache

        cat > /etc/oxidns/config.yaml.tmp <<EOF
log:
  level: info

plugins:
  - tag: ads_domains
    type: geosite
    args:
      file: "/var/lib/dns-assets/geosite.dat"
      selectors:
        - "category-ads-all"

  - tag: proxied_sites
    type: domain_set
    args:
      files:
        - "/var/lib/dns-assets/geohide-domains.txt"

  - tag: smart_a
    type: hosts
    args:
      files:
        - "/var/lib/dns-assets/geohide-hosts.txt"

  - tag: cache
    type: cache
    args:
      size: 4096
      short_circuit: true
      cache_negative: true

  - tag: upstream_doh
    type: forward
    args:
      upstreams:
        - addr: "https://1.1.1.1/dns-query"
        - addr: "https://8.8.8.8/dns-query"

  - tag: main
    type: sequence
    args:
      - matches: "qname \$ads_domains"
        exec: "reject 3"
      - matches:
          - "qname \$proxied_sites"
          - "qtype 64 65"
        exec: "reject 5"
      - matches:
          - "qname \$proxied_sites"
          - "qtype 1 28"
        exec: "\$smart_a"
      - matches: "has_resp"
        exec: "accept"
      - exec: "\$cache"
      - matches: "!has_resp"
        exec: "\$upstream_doh"

  - tag: udp_local
    type: udp_server
    args:
      entry: "main"
      listen: "127.0.0.1:5353"

  - tag: tcp_local
    type: tcp_server
    args:
      entry: "main"
      listen: "127.0.0.1:5353"

  - tag: doh_local
    type: http_server
    args:
      listen: "127.0.0.1:8053"
      entries:
        - path: "/dns-query"
          exec: "main"
EOF
        backup_file_before_modify "/etc/oxidns/config.yaml" "oxidns" || return 1
        chown oxidns:oxidns /etc/oxidns/config.yaml.tmp
        chmod 0640 /etc/oxidns/config.yaml.tmp
        mv -f /etc/oxidns/config.yaml.tmp /etc/oxidns/config.yaml
    else
        log_info_tr "dns.log" "M_0127"
        install -d -m 0750 -o adguard -g adguard /etc/adguardhome /var/lib/adguardhome

        render_dns_domain_lists_from_cache

        local existing_agh_user=""
        local existing_agh_pass=""
        if [[ -f "${SECRETS_FILE}" ]]; then
            existing_agh_user="$(awk -F'"' '/^AGH_ADMIN_USER=/ {print $2}' "${SECRETS_FILE}" 2>/dev/null || true)"
            existing_agh_pass="$(awk -F'"' '/^AGH_ADMIN_PASS=/ {print $2}' "${SECRETS_FILE}" 2>/dev/null || true)"
        fi

        if [[ -n "${existing_agh_user}" && -n "${existing_agh_pass}" ]]; then
            AGH_ADMIN_USER="${existing_agh_user}"
            AGH_ADMIN_PASS="${existing_agh_pass}"
        else
            AGH_ADMIN_USER="admin_$(generate_random_lower 6)"
            AGH_ADMIN_PASS="$(generate_random_alnum 24)"
            cat >> "${SECRETS_FILE}" <<EOF
AGH_PANEL_URL="http://127.0.0.1:8053 (через SSH-туннель)"
AGH_ADMIN_USER="${AGH_ADMIN_USER}"
AGH_ADMIN_PASS="${AGH_ADMIN_PASS}"
EOF
        fi

        local agh_pass_hash=""
        if python3 -c "import bcrypt" >/dev/null 2>&1; then
            agh_pass_hash="$(AGH_ADMIN_PASS="${AGH_ADMIN_PASS}" python3 -c 'import bcrypt, os; print(bcrypt.hashpw(os.environ["AGH_ADMIN_PASS"].encode(), bcrypt.gensalt(rounds=10)).decode())')"
        elif command -v htpasswd >/dev/null 2>&1; then
            agh_pass_hash="$(htpasswd -nbB "" "${AGH_ADMIN_PASS}" | cut -d: -f2)"
        else
            log_error_tr "dns.log" "M_0128"
            exit 1
        fi

        cat > /etc/adguardhome/AdGuardHome.yaml.tmp <<EOF
http:
  address: 127.0.0.1:8053
  session_ttl: 720h
users:
  - name: "${AGH_ADMIN_USER}"
    password: "${agh_pass_hash}"
dns:
  bind_hosts:
    - 127.0.0.1
  port: 5353
  upstream_dns:
    - https://1.1.1.1/dns-query
    - https://8.8.8.8/dns-query
  bootstrap_dns:
    - 1.1.1.1
    - 8.8.8.8
  cache_size: 4194304
  ratelimit: 0
  refuse_any: true
  serve_plain_dns: true
tls:
  enabled: false
  server_name: "${ROOT_DOMAIN}"
  port_https: 0
  port_dns_over_tls: 0
  allow_unencrypted_doh: true
filtering:
  protection_enabled: true
  filtering_enabled: true
  filters_update_interval: 24
  safe_fs_patterns:
    - /var/lib/dns-assets/*
    - /var/lib/adguardhome/*
filters:
  - enabled: true
    url: https://adguardteam.github.io/AdGuardSDNSFilter/Filters/filter.txt
    name: AdGuard DNS filter
    id: 1
  - enabled: true
    url: /var/lib/dns-assets/ag-smartdns-rules.txt
    name: GeoHide SmartDNS Rules
    id: 2
schema_version: 29
EOF
        backup_file_before_modify "/etc/adguardhome/AdGuardHome.yaml" "adguardhome" || return 1
        chown adguard:adguard /etc/adguardhome/AdGuardHome.yaml.tmp
        chmod 0640 /etc/adguardhome/AdGuardHome.yaml.tmp
        mv -f /etc/adguardhome/AdGuardHome.yaml.tmp /etc/adguardhome/AdGuardHome.yaml
    fi
}

# ------------------------------ Xray Configuration ----------------------------
configure_xray_base() {
    log_info_tr "xray.log" "M_0129"
    install -d -m 0750 -o xray -g xray /var/log/xray
    touch /var/log/xray/access.log /var/log/xray/error.log
    chown xray:xray /var/log/xray/access.log /var/log/xray/error.log
    chmod 0640 /var/log/xray/access.log /var/log/xray/error.log

    cat > "${XRAY_CONF_DIR}/00-base.json.tmp" <<EOF
{
  "log": {
    "access": "/var/log/xray/access.log",
    "error": "/var/log/xray/error.log",
    "loglevel": "info"
  },
  "dns": {
    "servers": [
      "https+local://1.1.1.1/dns-query",
      "https+local://8.8.8.8/dns-query"
    ],
    "queryStrategy": "UseIPv4"
  },
  "inbounds": [
    {
      "tag": "https-in",
      "listen": "0.0.0.0",
      "port": 8444,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 443,
        "network": "tcp",
        "followRedirect": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["tls"],
        "routeOnly": false
      },
      "streamSettings": {
        "sockopt": {
          "tcpKeepAliveInterval": 120,
          "tcpNoDelay": true
        }
      }
    },
    {
      "tag": "dot-in",
      "listen": "0.0.0.0",
      "port": 853,
      "protocol": "dokodemo-door",
      "settings": {
        "address": "127.0.0.1",
        "port": 8853,
        "network": "tcp",
        "followRedirect": false
      },
      "sniffing": {
        "enabled": true,
        "destOverride": ["tls"],
        "routeOnly": true
      },
      "streamSettings": {
        "sockopt": {
          "tcpKeepAliveInterval": 60,
          "tcpNoDelay": true
        }
      }
    }
  ],
  "outbounds": [
    {
      "tag": "direct-v4",
      "protocol": "freedom",
      "settings": {
        "domainStrategy": "UseIPv4"
      },
      "streamSettings": {
        "sockopt": {
          "tcpKeepAliveInterval": 120
        }
      }
    },
    {
      "tag": "nginx-local",
      "protocol": "freedom",
      "settings": {
        "redirect": "127.0.0.1:9444",
        "proxyProtocol": 1
      }
    },
    {
      "tag": "dot-backend",
      "protocol": "freedom",
      "settings": {
        "redirect": "127.0.0.1:8853"
      }
    },
    {
      "tag": "block",
      "protocol": "blackhole",
      "settings": {}
    }
  ]
}
EOF
    backup_file_before_modify "${XRAY_CONF_DIR}/00-base.json" "xray" || return 1
    chown root:xray "${XRAY_CONF_DIR}/00-base.json.tmp"
    chmod 0640 "${XRAY_CONF_DIR}/00-base.json.tmp"
    mv -f "${XRAY_CONF_DIR}/00-base.json.tmp" "${XRAY_CONF_DIR}/00-base.json"
}

# ------------------------------ Procedural Cover Site Generator ---------------
html_escape() {
    local s="$1"
    s="${s//&/&amp;}"
    s="${s//</&lt;}"
    s="${s//>/&gt;}"
    s="${s//\"/&quot;}"
    s="${s//\'/&#39;}"
    printf '%s' "${s}"
}

rand_u32() {
    od -An -tu4 -N4 /dev/urandom | tr -d ' 
'
}

rand_range() {
    local min="$1"
    local max="$2"
    local span=$((max - min + 1))
    local val
    val="$(rand_u32)"
    printf '%d' $((min + (val % span)))
}

shuffle_indices() {
    local count="$1"
    local -a arr=()
    local i j tmp
    for ((i = 0; i < count; i++)); do
        arr+=("${i}")
    done
    for ((i = count - 1; i > 0; i--)); do
        j="$(rand_range 0 "${i}")"
        tmp="${arr[${i}]}"
        arr[i]="${arr[${j}]}"
        arr[j]="${tmp}"
    done
    printf '%s ' "${arr[@]}"
}

sync_cover_site_domain_metadata() {
    local target_dir="${1:-${WEB_ROOT}}"
    [[ -d "${target_dir}" ]] || return 0

    cat > "${target_dir}/robots.txt" <<EOF
User-agent: *
Allow: /
Sitemap: https://${ROOT_DOMAIN}/sitemap.xml
EOF

    cat > "${target_dir}/sitemap.xml" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
  <url>
    <loc>https://${ROOT_DOMAIN}/</loc>
    <changefreq>monthly</changefreq>
    <priority>1.0</priority>
  </url>
</urlset>
EOF
    chmod 0644 "${target_dir}/robots.txt" "${target_dir}/sitemap.xml"
}

validate_generated_cover_site() {
    local stage_dir="$1"
    local prev_hash="${2:-}"

    for req_file in index.html 404.html favicon.svg robots.txt sitemap.xml assets/style.css assets/app.js; do
        if [[ ! -s "${stage_dir}/${req_file}" ]]; then
            log_error_tr "installation.log" "M_0130" "${req_file}"
            return 1
        fi
    done

    local html_content
    html_content="$(cat "${stage_dir}/index.html")"

    for req_tag in "<!DOCTYPE html>" "<html" "<head>" "<title>" "<body>" "<header" "<main" "<footer" "</html>"; do
        if ! grep -Fq "${req_tag}" <<<"${html_content}"; then
            log_error_tr "installation.log" "M_0131" "${req_tag}"
            return 1
        fi
    done

    local section_count
    section_count="$(grep -c '<section ' <<<"${html_content}" || echo 0)"
    if [[ "${section_count}" -lt 3 ]]; then
        log_error_tr "installation.log" "M_0132" "${section_count}"
        return 1
    fi

    # Проверка отсутствия утечек технических терминов и внутренних адресов
    if grep -Eiq '(xray|nginx|oxidns|adguard|adguardhome|telemt|smartdns|dokodemo|ipset|iptables|127\.0\.0\.1)' "${stage_dir}/index.html" "${stage_dir}/404.html" "${stage_dir}/assets/style.css" "${stage_dir}/assets/app.js"; then
        log_error_tr "installation.log" "M_0133"
        return 1
    fi

    if [[ -n "${SERVER_IPV4:-}" ]] && grep -Fq "${SERVER_IPV4}" "${stage_dir}/index.html" "${stage_dir}/404.html"; then
        log_error_tr "installation.log" "M_0134"
        return 1
    fi

    local new_hash
    new_hash="$(sha256sum "${stage_dir}/index.html" | awk '{print $1}')"
    if [[ -n "${prev_hash}" && "${new_hash}" == "${prev_hash}" ]]; then
        log_warn_tr "installation.log" "M_0135"
        return 2
    fi

    return 0
}

render_procedural_cover_attempt() {
    local stage_dir="$1"
    install -d -m 0755 "${stage_dir}/assets"

    local seed_hex
    seed_hex="$(od -An -tx4 -N16 /dev/urandom | tr -d ' 
')"

    # 1. Процедурная генерация цветовой палитры (HSL) и контрастов
    local hue_base harmony_mode hue_accent hue_secondary bg_mode
    hue_base="$(rand_range 0 359)"
    harmony_mode="$(rand_range 0 3)"
    case "${harmony_mode}" in
        0) hue_accent="${hue_base}"; hue_secondary="$(((hue_base + 18) % 360))" ;;
        1) hue_accent="$(((hue_base + 150) % 360))"; hue_secondary="$(((hue_base + 210) % 360))" ;;
        2) hue_accent="$(((hue_base + 180) % 360))"; hue_secondary="$(((hue_base + 30) % 360))" ;;
        *) hue_accent="$(((hue_base + 35) % 360))"; hue_secondary="$(((hue_base + 325) % 360))" ;;
    esac

    bg_mode="$(rand_range 0 3)"
    local col_bg col_surface col_surface_alt col_text col_muted col_accent col_accent_soft col_border
    case "${bg_mode}" in
        0) # Warm editorial paper
            col_bg="hsl(${hue_base}, 18%, 96%)"
            col_surface="hsl(${hue_base}, 20%, 99%)"
            col_surface_alt="hsl(${hue_base}, 15%, 92%)"
            col_text="hsl(${hue_base}, 24%, 13%)"
            col_muted="hsl(${hue_base}, 12%, 40%)"
            col_accent="hsl(${hue_accent}, 48%, 31%)"
            col_accent_soft="hsla(${hue_accent}, 48%, 31%, 0.11)"
            col_border="hsl(${hue_base}, 14%, 84%)"
            ;;
        1) # Cool architectural stone
            col_bg="hsl(${hue_base}, 14%, 95%)"
            col_surface="#ffffff"
            col_surface_alt="hsl(${hue_base}, 16%, 90%)"
            col_text="hsl(${hue_base}, 28%, 12%)"
            col_muted="hsl(${hue_base}, 14%, 38%)"
            col_accent="hsl(${hue_accent}, 55%, 34%)"
            col_accent_soft="hsla(${hue_accent}, 55%, 34%, 0.10)"
            col_border="hsl(${hue_base}, 15%, 83%)"
            ;;
        2) # Deep Nordic slate (dark editorial theme)
            col_bg="hsl(${hue_base}, 22%, 11%)"
            col_surface="hsl(${hue_base}, 20%, 15%)"
            col_surface_alt="hsl(${hue_base}, 18%, 19%)"
            col_text="hsl(${hue_base}, 15%, 93%)"
            col_muted="hsl(${hue_base}, 10%, 68%)"
            col_accent="hsl(${hue_accent}, 68%, 62%)"
            col_accent_soft="hsla(${hue_accent}, 68%, 62%, 0.15)"
            col_border="hsl(${hue_base}, 16%, 26%)"
            ;;
        *) # High-contrast gallery white
            col_bg="#fafaf9"
            col_surface="#ffffff"
            col_surface_alt="hsl(${hue_secondary}, 22%, 94%)"
            col_text="#18181b"
            col_muted="#52525b"
            col_accent="hsl(${hue_accent}, 52%, 33%)"
            col_accent_soft="hsla(${hue_accent}, 52%, 33%, 0.10)"
            col_border="#e4e4e7"
            ;;
    esac

    # 2. Типографика, пропорции, радиусы и стилистика оформления
    local font_choice font_heading font_body
    font_choice="$(rand_range 0 3)"
    case "${font_choice}" in
        0)
            font_heading='ui-serif, Georgia, Cambria, "Times New Roman", serif'
            font_body='system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'
            ;;
        1)
            font_heading='system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'
            font_body='system-ui, -apple-system, "Segoe UI", Roboto, sans-serif'
            ;;
        2)
            font_heading='"Trebuchet MS", "Segoe UI", system-ui, sans-serif'
            font_body='ui-serif, Georgia, "Times New Roman", serif'
            ;;
        *)
            font_heading='system-ui, -apple-system, "Segoe UI", sans-serif'
            font_body='"Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif'
            ;;
    esac

    local container_w radius_px card_style hero_layout header_layout deco_type
    container_w="$(rand_range 1040 1260)"
    local -a radii=(0 3 6 10 16)
    radius_px="${radii[$(rand_range 0 4)]}"
    card_style="$(rand_range 0 3)"
    hero_layout="$(rand_range 0 2)"
    header_layout="$(rand_range 0 2)"
    deco_type="$(rand_range 0 3)"

    # 3. Комбинаторный генератор предметной области и осмысленного контента
    local -a brand_p1=("Vespera" "Krono" "Aether" "Solvik" "Lumen" "Boreal" "Tecton" "Orbis" "Halcyon" "Meridian" "Cairn" "Alba" "Norden" "Strata" "Kestrel" "Veritas")
    local -a brand_p2=("Spatial" "Form" "Civic" "Acoustic" "Material" "Urban" "Ecological" "Heritage" "Structural" "Systems" "Horizon" "Atelier" "Grid" "Field" "Timber" "Metric")
    local -a brand_p3=("Group" "Studio" "Practice" "Lab" "Associates" "Collective" "Works" "Institute" "Partners" "Bureau")

    local b1="${brand_p1[$(rand_range 0 $((${#brand_p1[@]} - 1)))]}"
    local b2="${brand_p2[$(rand_range 0 $((${#brand_p2[@]} - 1)))]}"
    local b3="${brand_p3[$(rand_range 0 $((${#brand_p3[@]} - 1)))]}"
    local brand_name="${b1} ${b2} ${b3}"
    local brand_initials="${b1:0:1}${b2:0:1}"
    local brand_slug
    brand_slug="$(printf '%s%s' "${b1,,}" "${b2,,}")"

    local domain_idx
    domain_idx="$(rand_range 0 4)"
    local site_tagline hero_title hero_lead mission_title mission_body
    local -a svc_titles=() svc_bodies=()
    local -a proj_titles=() proj_meta=() proj_bodies=()
    local -a step_titles=() step_bodies=()
    local -a faq_q=() faq_a=()

    case "${domain_idx}" in
        0) # Sustainable Architecture & Adaptive Reuse
            site_tagline="Contemporary Architecture, Mass-Timber Engineering & Adaptive Reuse"
            hero_title="Tactile Minimalism and Climate-Resilient Civic Environments"
            hero_lead="${brand_name} is an independent architectural and structural engineering practice focused on low-carbon timber construction, daylight optimization, and adaptive heritage reuse."
            mission_title="Environmental Lifecycle Approach"
            mission_body="Every commission begins with micro-climate modeling, embodied carbon budgeting, and regionally sourced structural timber, natural stone, and lime plaster."
            svc_titles=("Civic & Cultural Architecture" "Adaptive Heritage Reuse" "Passive-House Masterplanning" "Structural Timber Consulting")
            svc_bodies=(
                "Full-cycle architectural design from feasibility studies to construction administration for libraries, pavilions, and public workspaces."
                "Structural retrofitting of post-industrial brick and masonry landmarks into energy-positive cultural and educational hubs."
                "Transit-oriented neighborhood frameworks integrating geothermal storage, rainwater retention, and pedestrian greenways."
                "Cross-laminated timber span optimization, acoustic isolation detailing, and prefabricated modular assembly."
            )
            proj_titles=("Fjord Acoustic Hall" "Kallio Foundry Archive" "Linden Courtyard Housing" "Vltava Timber Footbridge")
            proj_meta=("Oslo — 2024" "Helsinki — 2025" "Copenhagen — 2025" "Prague — 2026")
            proj_bodies=(
                "Cantilevered spruce-timber chamber engineered for natural reverberation and passive coastal ventilation."
                "Transformation of a 1928 maritime workshop into a daylight-lit municipal archive and public reading room."
                "Forty-two modular cross-laminated timber residences organized around a shared geothermal winter garden."
                "Lightweight pedestrian and cycle span fabricated from locally harvested glulam beams with weathering steel joints."
            )
            step_titles=("Site & Micro-Climate Audit" "Parametric Massing & Daylight" "Material & Carbon Ledger" "Prefabricated Assembly")
            step_bodies=(
                "Topographic laser scanning, wind-rose simulation, and soil thermal conductivity testing prior to concept sketches."
                "Iterative solar-gain balancing to minimize summer cooling loads while maximizing winter passive heating."
                "Component-level lifecycle assessment verifying net-negative embodied carbon across structural assemblies."
                "Off-site CNC timber milling for quiet, rapid on-site installation with minimal neighborhood disruption."
            )
            faq_q=("How do you evaluate embodied carbon in renovation projects?" "Do you collaborate with municipal planning boards?" "What scale of commissions does the practice undertake?")
            faq_a=(
                "We perform a full cradle-to-site structural audit comparing foundation retention against new-build alternatives before finalizing schematics."
                "Yes, our urbanism team regularly prepares public-realm impact studies, daylight envelopes, and accessibility briefs for civic review."
                "Our portfolio spans bespoke cultural pavilions from 400 square meters up to multi-hectare mixed-use district masterplans."
            )
            ;;
        1) # Acoustic Engineering & Spatial Sound Design
            site_tagline="Architectural Acoustics, Electro-Acoustic Modeling & Quiet Urbanism"
            hero_title="Precision Soundscapes for Cultural and Civic Spaces"
            hero_lead="${brand_name} designs acoustic geometries, vibration-isolated structures, and calm interior environments for concert halls, museums, and modern workspaces."
            mission_title="Physics-Driven Spatial Clarity"
            mission_body="By pairing ray-tracing acoustic simulation with custom micro-perforated timber and mineral wool diffusers, we shape speech intelligibility and musical warmth."
            svc_titles=("Auditorium & Hall Acoustics" "Structural Vibration Isolation" "Workplace Soundscaping" "Environmental Noise Mapping")
            svc_bodies=(
                "3D impulse-response modeling, variable reverberation canopies, and custom reflector geometry for performance venues."
                "Floating slab engineering and elastomeric bearing specification to isolate studios from rail and street vibration."
                "Acoustic zoning, speech-privacy baffling, and reverberation control for open research laboratories and libraries."
                "Outdoor facade attenuation studies and urban sound-barrier design compliant with strict municipal decibel thresholds."
            )
            proj_titles=("Malmo Chamber Auditorium" "Bergen Maritime Museum" "Aarhus Research Atrium" "Zurich Broadcast Wing")
            proj_meta=("Malmo — 2024" "Bergen — 2025" "Aarhus — 2025" "Zurich — 2026")
            proj_bodies=(
                "Variable-volume birch acoustic panels tuned to switch seamlessly between spoken-word symposia and chamber ensembles."
                "Floating glass-and-timber exhibition galleries decoupled from adjacent harbor freight rail vibrations."
                "Suspended felt baffles and micro-slotted ash ceilings reducing ambient reverberation time to 0.45 seconds."
                "Box-in-box recording suites achieving NC-15 background noise ratings within a dense city-center building."
            )
            step_titles=("Impulse & Noise Baseline" "3D Ray-Tracing Simulation" "Prototype Panel Testing" "Commissioning & Tuning")
            step_bodies=(
                "On-site omnidirectional source measurements capturing existing reverberation decay and structural flanking paths."
                "Frequency-band wave modeling from 63 Hz to 8 kHz to eliminate flutter echoes and focal hot spots."
                "Laboratory impedance-tube verification of custom perforated wood and recycled textile absorbers."
                "Post-construction acoustic calibration with calibrated condenser arrays and final spatial tuning."
            )
            faq_q=("When should acoustic consultants join a building project?" "Can historic interiors be treated without visual alteration?" "How do you address low-frequency mechanical noise?")
            faq_a=(
                "Engaging during early massing allows room proportions to prevent standing waves naturally, reducing the need for heavy corrective absorbers."
                "We utilize micro-perforated lime plasters and concealed bass traps behind existing historic paneling to preserve visual authenticity."
                "Our mechanical engineers specify low-velocity ductwork, acoustic plenums, and spring-isolated plant rooms from day one."
            )
            ;;
        2) # Industrial Design & Sustainable Materials Lab
            site_tagline="Circular Industrial Design, Bio-Composites & Tactile Hardware"
            hero_title="Enduring Objects Engineered for Repairability and Circularity"
            hero_lead="${brand_name} develops modular furniture, architectural hardware, and bio-based material systems built for multi-decade service life and clean disassembly."
            mission_title="Mono-Material Engineering"
            mission_body="We eliminate permanent adhesives and mixed-polymer laminates in favor of mechanical fasteners, anodized aluminum, and regenerative mycelium or flax composites."
            svc_titles=("Circular Product Architecture" "Bio-Composite Formulation" "Architectural Hardware Systems" "Design for Disassembly Audits")
            svc_bodies=(
                "End-to-end industrial design of modular seating, lighting fixtures, and workspace tools with replaceable wear components."
                "Testing and tooling of compressed hemp-fiber, cork, and mineral-bound surface panels for interior fit-outs."
                "Precision-milled brass and stainless-steel door furniture, hinges, and modular shelving connectors."
                "Component teardown analysis and digital material-passport documentation for European circular procurement."
            )
            proj_titles=("Kvadrat Modular Task Lamp" "Viken Recycled Aluminium Bench" "Talinn Flax-Core Partition" "Ghent Repairable Transit Seat")
            proj_meta=("Copenhagen — 2024" "Gothenburg — 2025" "Tallinn — 2025" "Ghent — 2026")
            proj_bodies=(
                "Tool-free LED luminaire engineered with a replaceable driver cartridge and spun post-consumer aluminum shade."
                "Public seating system cast from 94% remelted marine alloy with replaceable ash timber slats."
                "Lightweight acoustic room divider pressed from regional flax fibers and natural starch binders."
                "High-durability commuter seating allowing cushion and armrest replacement in under ninety seconds."
            )
            step_titles=("Lifecycle & Use-Case Study" "Mechanical Prototyping" "Accelerated Wear Testing" "Tooling & Material Passport")
            step_bodies=(
                "Field observation of maintenance workflows and failure points across high-traffic public installations."
                "CNC aluminum and 3D-printed functional assemblies tested for ergonomics, tolerances, and repair speed."
                "100,000-cycle mechanical load and surface abrasion verification in our physical testing workshop."
                "Full bill-of-materials registry specifying alloy grades, fastener standards, and end-of-life recovery streams."
            )
            faq_q=("Do you support small-batch architectural production?" "How are bio-composites tested for fire and wear standards?" "Can existing product lines be redesigned for circularity?")
            faq_a=(
                "Yes, we maintain relationships with regional European foundries and CNC workshops capable of runs from 50 to 10,000 units."
                "All surface panels undergo accredited EN 13501 fire-reaction and Taber abrasion testing prior to commercial specification."
                "We frequently re-engineer legacy housings to replace glued joints with standardized Torx fasteners and modular sub-assemblies."
            )
            ;;
        3) # Landscape Ecology & Urban Hydrology
            site_tagline="Landscape Ecology, Sponge-City Hydrology & Botanical Restoration"
            hero_title="Restoring Urban Watersheds and Resilient Public Landscapes"
            hero_lead="${brand_name} plans bio-diverse parklands, stormwater bioswales, and coastal wetland buffers that cool dense cities and protect infrastructure."
            mission_title="Living Hydrological Infrastructure"
            mission_body="We replace impermeable concrete drainage with layered soil bio-retention, native perennial meadows, and seasonal floodable plazas."
            svc_titles=("Sponge-City Stormwater Design" "Coastal & Riparian Restoration" "Urban Heat-Island Mitigation" "Native Seed & Soil Engineering")
            svc_bodies=(
                "Detention basins, permeable stone paving, and vegetated bioswales engineered to capture 1-in-100-year cloudburst events."
                "Salt-tolerant marshland terracing and soft-edge riverbanks that stabilize shorelines while expanding bird habitats."
                "Multi-canopy street tree corridors and reflective mineral surfaces lowering peak summer temperatures by up to 4 degrees."
                "Site-specific mycorrhizal soil blending and regional wildflower meadow establishment for low-irrigation upkeep."
            )
            proj_titles=("Rotterdam Tidal Canal Park" "Uppsala Cloudburst Meadow" "Gdansk Dune Promenade" "Ljubljana Riverfront Arboretum")
            proj_meta=("Rotterdam — 2024" "Uppsala — 2025" "Gdansk — 2025" "Ljubljana — 2026")
            proj_bodies=(
                "Stepped estuarine boardwalk and reed-bed filtration gardens absorbing tidal surges along a former dockyard."
                "Six-hectare sunken botanical park storing 18,000 cubic meters of rainwater while serving as a neighborhood commons."
                "Elevated larch walkways protecting fragile Baltic coastal dunes and native marram grass ecosystems."
                "Continuous riparian forest corridor linking seven urban districts with shaded cycling paths and pollinator habitats."
            )
            step_titles=("Watershed & Soil Survey" "Hydrological Runoff Modeling" "Botanical Palette Selection" "Seasonal Stewardship Plan")
            step_bodies=(
                "Percolation bore-hole testing, groundwater mapping, and existing biodiversity inventory across the site."
                "Dynamic rainfall-runoff simulation sizing retention swales and underground cisterns for extreme weather."
                "Selection of drought-hardy, non-invasive native perennials, sedges, and deep-rooting canopy trees."
                "Three-year ecological establishment protocol guiding municipal gardeners through seasonal pruning and monitoring."
            )
            faq_q=("How quickly do constructed bioswales reach full filtration capacity?" "Are sponge-city parks safe during heavy storm events?" "How do you minimize long-term irrigation costs?")
            faq_a=(
                "Engineered sandy-loam filter media operates from day one, while root-zone microbial filtration matures over two growing seasons."
                "All floodable basins feature gentle 1:6 graded slopes, clear high-water signage, and dry upper promenades for safe public access."
                "By matching deep-rooted native species to local rainfall patterns, established landscapes require zero supplemental watering."
            )
            ;;
        *) # Museum Conservation, Archival Lighting & Exhibition Design
            site_tagline="Museum Exhibition Design, Archival Conservation & Daylight Control"
            hero_title="Preserving Cultural Artifacts Through Precision Light and Climate"
            hero_lead="${brand_name} creates micro-climate display vitrines, low-UV museum lighting systems, and clear spatial narratives for galleries and archives."
            mission_title="Conservation-First Exhibition Craft"
            mission_body="Every gallery environment balances visitor visual comfort with strict lux-hour budgets, passive humidity buffering, and non-offgassing materials."
            svc_titles=("Exhibition Spatial Architecture" "Archival Lighting & Lux Control" "Micro-Climate Vitrine Engineering" "Wayfinding & Graphic Systems")
            svc_bodies=(
                "Modular gallery walls, intuitive visitor flow planning, and tactile exhibition plinths built from archival-grade boards."
                "High-CRI tunable LED luminaires and automated skylight louvers protecting sensitive textiles and works on paper."
                "Airtight low-iron glass display cases with concealed silica-gel cassettes maintaining 50% relative humidity."
                "Bilingual typographic hierarchy, tactile bronze maps, and high-contrast signage designed for universal accessibility."
            )
            proj_titles=("Antwerp Print Cabinet" "Tartu Ethnographic Gallery" "Basel Horology Pavilion" "Trondheim Cathedral Treasury")
            proj_meta=("Antwerp — 2024" "Tartu — 2025" "Basel — 2025" "Trondheim — 2026")
            proj_bodies=(
                "North-lit study room and automated shutter system limiting cumulative annual exposure on 16th-century engravings."
                "Reconfigurable ash-and-linen gallery system hosting rotating textile and ceramic collections without construction waste."
                "Anti-reflective fiber-optic lit vitrines showcasing intricate mechanical timepieces at 50 lux with zero heat gain."
                "Passive humidity-stabilized stone vault and bronze lectern system for medieval manuscripts and liturgical metalwork."
            )
            step_titles=("Curatorial & Conservation Brief" "Lux-Hour & Climate Modeling" "Full-Scale Mockup Review" "Installation & Calibration")
            step_bodies=(
                "Cataloging object sensitivity classes, sightline requirements, and curator narrative sequences."
                "Photometric ray-tracing and air-exchange calculations ensuring zero UV exposure and stable dew points."
                "Physical 1:1 lighting and material sample testing with conservators prior to workshop fabrication."
                "White-glove installation, spectrometer color-rendering verification, and wireless data-logger handover."
            )
            faq_q=("What materials are approved for sealed archival vitrines?" "How do you combine natural daylight with sensitive artifacts?" "Can exhibition walls be reused across multiple shows?")
            faq_a=(
                "We use powder-coated aluminum, low-iron laminated glass, inert silicone gaskets, and Oddy-tested archival textiles."
                "Motorized external louvers linked to roof photosensors modulate incoming daylight while keeping gallery illumination within 50–150 lux."
                "Our bolted aluminum-frame wall modules are engineered for ten or more reconfiguration cycles with minimal surface refinishing."
            )
            ;;
    esac

    # 4. Города и контактные данные на базе ROOT_DOMAIN
    local -a cities=("Stockholm" "Copenhagen" "Oslo" "Helsinki" "Zurich" "Vienna" "Amsterdam" "Prague")
    local -a streets=("Skeppsbron 14" "Bredgade 42" "Karl Johans gate 19" "Esplanadi 31" "Limmatquai 88" "Ringstrasse 12" "Herengracht 210" "Masarykovo nabrezi 26")
    local loc_idx
    loc_idx="$(rand_range 0 $((${#cities[@]} - 1)))"
    local office_city="${cities[${loc_idx}]}"
    local office_street="${streets[${loc_idx}]}"
    local contact_email="info@${ROOT_DOMAIN}"
    local press_email="archive@${ROOT_DOMAIN}"

    # 5. Генерация уникального геометрического favicon.svg
    local svg_shape
    svg_shape="$(rand_range 0 3)"
    local svg_inner=""
    case "${svg_shape}" in
        0)
            svg_inner="<rect x=\"4\" y=\"4\" width=\"56\" height=\"56\" rx=\"${radius_px}\" fill=\"${col_accent}\"/><text x=\"32\" y=\"40\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"24\" font-weight=\"700\" fill=\"#ffffff\">${brand_initials}</text>"
            ;;
        1)
            svg_inner="<circle cx=\"32\" cy=\"32\" r=\"28\" fill=\"${col_accent}\"/><circle cx=\"32\" cy=\"32\" r=\"21\" fill=\"none\" stroke=\"#ffffff\" stroke-width=\"2\"/><text x=\"32\" y=\"39\" text-anchor=\"middle\" font-family=\"serif\" font-size=\"22\" font-weight=\"700\" fill=\"#ffffff\">${brand_initials}</text>"
            ;;
        2)
            svg_inner="<polygon points=\"32,3 59,18 59,46 32,61 5,46 5,18\" fill=\"${col_accent}\"/><text x=\"32\" y=\"39\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"21\" font-weight=\"700\" fill=\"#ffffff\">${brand_initials}</text>"
            ;;
        *)
            svg_inner="<rect x=\"4\" y=\"4\" width=\"56\" height=\"56\" rx=\"${radius_px}\" fill=\"${col_surface}\" stroke=\"${col_accent}\" stroke-width=\"4\"/><rect x=\"12\" y=\"12\" width=\"16\" height=\"16\" fill=\"${col_accent}\"/><text x=\"41\" y=\"46\" text-anchor=\"middle\" font-family=\"sans-serif\" font-size=\"20\" font-weight=\"700\" fill=\"${col_text}\">${brand_initials}</text>"
            ;;
    esac

    cat > "${stage_dir}/favicon.svg" <<EOF
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">
  ${svg_inner}
</svg>
EOF

    # 6. Генерация вариативного CSS (assets/style.css)
    local card_css=""
    case "${card_style}" in
        0) card_css="background: var(--surface); border: 1px solid var(--border); border-top: 3px solid var(--accent);" ;;
        1) card_css="background: var(--surface); border: 1px solid var(--border); border-left: 4px solid var(--accent);" ;;
        2) card_css="background: var(--surface-alt); border: 1px solid transparent;" ;;
        *) card_css="background: var(--surface); border: 1px solid var(--border); box-shadow: 0 6px 22px rgba(0, 0, 0, 0.04);" ;;
    esac

    local deco_css=""
    case "${deco_type}" in
        0) deco_css="background-image: radial-gradient(var(--accent) 1px, transparent 1px); background-size: 18px 18px;" ;;
        1) deco_css="background-image: linear-gradient(to right, var(--border) 1px, transparent 1px), linear-gradient(to bottom, var(--border) 1px, transparent 1px); background-size: 28px 28px;" ;;
        2) deco_css="background: linear-gradient(135deg, var(--accent-soft) 0%, var(--surface-alt) 100%);" ;;
        *) deco_css="background: repeating-linear-gradient(-45deg, var(--surface), var(--surface) 12px, var(--surface-alt) 12px, var(--surface-alt) 24px);" ;;
    esac

    local hero_grid_css=""
    case "${hero_layout}" in
        0) hero_grid_css="grid-template-columns: 1.3fr 0.7fr;" ;;
        1) hero_grid_css="grid-template-columns: 0.75fr 1.25fr;" ;;
        *) hero_grid_css="grid-template-columns: 1fr;" ;;
    esac

    local header_css=""
    case "${header_layout}" in
        0) header_css="display: flex; justify-content: space-between; align-items: center; gap: 1.5rem;" ;;
        1) header_css="display: flex; flex-direction: column; align-items: center; text-align: center; gap: 0.9rem;" ;;
        *) header_css="display: flex; justify-content: space-between; align-items: center; border-left: 4px solid var(--accent); padding-left: 1rem;" ;;
    esac

    local grid_cols_svc grid_cols_proj
    grid_cols_svc="$(rand_range 2 4)"
    grid_cols_proj="$(rand_range 2 3)"

    cat > "${stage_dir}/assets/style.css" <<EOF
:root {
  --bg: ${col_bg};
  --surface: ${col_surface};
  --surface-alt: ${col_surface_alt};
  --text: ${col_text};
  --muted: ${col_muted};
  --accent: ${col_accent};
  --accent-soft: ${col_accent_soft};
  --border: ${col_border};
  --radius: ${radius_px}px;
  --container: ${container_w}px;
  --font-head: ${font_heading};
  --font-body: ${font_body};
}

* { box-sizing: border-box; margin: 0; padding: 0; }

html { scroll-behavior: smooth; }

body {
  background-color: var(--bg);
  color: var(--text);
  font-family: var(--font-body);
  font-size: 16px;
  line-height: 1.65;
  -webkit-font-smoothing: antialiased;
}

.wrap {
  max-width: var(--container);
  margin: 0 auto;
  padding: 0 1.75rem;
}

.site-header {
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  padding: 1.25rem 0;
}

.header-inner {
  ${header_css}
}

.brand-mark {
  display: inline-flex;
  align-items: center;
  gap: 0.75rem;
  text-decoration: none;
  color: var(--text);
  font-family: var(--font-head);
  font-weight: 700;
  font-size: 1.15rem;
  letter-spacing: 0.04em;
}

.brand-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 2.1rem;
  height: 2.1rem;
  background: var(--accent);
  color: #ffffff;
  border-radius: var(--radius);
  font-size: 0.85rem;
  font-weight: 700;
}

.nav-links {
  display: flex;
  flex-wrap: wrap;
  gap: 1.5rem;
}

.nav-links a {
  color: var(--muted);
  text-decoration: none;
  font-size: 0.94rem;
  font-weight: 500;
  transition: color 0.18s ease;
}

.nav-links a:hover {
  color: var(--accent);
}

.hero-block {
  padding: 4.25rem 0 3.25rem;
  border-bottom: 1px solid var(--border);
}

.hero-grid {
  display: grid;
  ${hero_grid_css}
  gap: 2.5rem;
  align-items: stretch;
}

.eyebrow {
  display: inline-block;
  font-size: 0.8rem;
  font-weight: 600;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--accent);
  background: var(--accent-soft);
  padding: 0.28rem 0.65rem;
  border-radius: var(--radius);
  margin-bottom: 1rem;
}

.hero-title {
  font-family: var(--font-head);
  font-size: clamp(1.95rem, 3.6vw, 2.95rem);
  line-height: 1.16;
  font-weight: 700;
  margin-bottom: 1.15rem;
}

.hero-lead {
  color: var(--muted);
  font-size: 1.08rem;
  max-width: 64ch;
}

.hero-aside {
  ${card_css}
  border-radius: var(--radius);
  padding: 1.75rem;
  display: flex;
  flex-direction: column;
  justify-content: space-between;
  gap: 1.25rem;
}

.deco-strip {
  height: 64px;
  border-radius: var(--radius);
  border: 1px solid var(--border);
  ${deco_css}
}

.content-section {
  padding: 3.5rem 0;
  border-bottom: 1px solid var(--border);
}

.section-head {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.75rem;
  margin-bottom: 1.85rem;
}

.section-title {
  font-family: var(--font-head);
  font-size: 1.55rem;
  font-weight: 700;
}

.section-sub {
  color: var(--muted);
  font-size: 0.92rem;
}

.grid-svc {
  display: grid;
  grid-template-columns: repeat(${grid_cols_svc}, minmax(0, 1fr));
  gap: 1.4rem;
}

.grid-proj {
  display: grid;
  grid-template-columns: repeat(${grid_cols_proj}, minmax(0, 1fr));
  gap: 1.5rem;
}

.grid-2 {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 1.5rem;
}

.card {
  ${card_css}
  border-radius: var(--radius);
  padding: 1.55rem;
}

.card-kicker {
  font-size: 0.78rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.08em;
  color: var(--accent);
  margin-bottom: 0.45rem;
}

.card h3 {
  font-family: var(--font-head);
  font-size: 1.14rem;
  margin-bottom: 0.6rem;
}

.card p {
  color: var(--muted);
  font-size: 0.94rem;
}

.faq-list {
  display: grid;
  gap: 0.85rem;
}

.faq-item {
  ${card_css}
  border-radius: var(--radius);
  padding: 1.1rem 1.35rem;
}

.faq-item summary {
  cursor: pointer;
  font-weight: 600;
  font-family: var(--font-head);
  list-style: none;
}

.faq-item summary::-webkit-details-marker { display: none; }

.faq-item p {
  margin-top: 0.75rem;
  color: var(--muted);
  font-size: 0.94rem;
}

.btn-link {
  display: inline-block;
  margin-top: 1.25rem;
  padding: 0.65rem 1.25rem;
  background: var(--accent);
  color: #ffffff;
  text-decoration: none;
  border-radius: var(--radius);
  font-size: 0.9rem;
  font-weight: 600;
}

.site-footer {
  padding: 2.5rem 0;
  color: var(--muted);
  font-size: 0.88rem;
}

.footer-inner {
  display: flex;
  justify-content: space-between;
  flex-wrap: wrap;
  gap: 1rem;
}

@media (max-width: 960px) {
  .hero-grid, .grid-svc, .grid-proj { grid-template-columns: repeat(2, minmax(0, 1fr)); }
}

@media (max-width: 640px) {
  .hero-grid, .grid-svc, .grid-proj, .grid-2 { grid-template-columns: 1fr; }
  .header-inner { flex-direction: column; align-items: flex-start; }
}
EOF

    # 7. Минимальный прогрессивный JS (безопасный, без внешних запросов и eval)
    cat > "${stage_dir}/assets/app.js" <<'EOF'
document.addEventListener("DOMContentLoaded", function () {
  var items = document.querySelectorAll("details.faq-item");
  items.forEach(function (target) {
    target.addEventListener("toggle", function () {
      if (target.open) {
        items.forEach(function (other) {
          if (other !== target) {
            other.removeAttribute("open");
          }
        });
      }
    });
  });
});
EOF

    # 8. Алгоритмическая сборка вариативных секций и их перемешивание
    local esc_brand esc_tagline esc_hero_t esc_hero_l esc_mis_t esc_mis_b esc_city esc_street esc_email esc_press
    esc_brand="$(html_escape "${brand_name}")"
    esc_tagline="$(html_escape "${site_tagline}")"
    esc_hero_t="$(html_escape "${hero_title}")"
    esc_hero_l="$(html_escape "${hero_lead}")"
    esc_mis_t="$(html_escape "${mission_title}")"
    esc_mis_b="$(html_escape "${mission_body}")"
    esc_city="$(html_escape "${office_city}")"
    esc_street="$(html_escape "${office_street}")"
    esc_email="$(html_escape "${contact_email}")"
    esc_press="$(html_escape "${press_email}")"

    local sec_services=""
    sec_services+="<section id=\"services\" class=\"content-section\"><div class=\"wrap\">"
    sec_services+="<div class=\"section-head\"><h2 class=\"section-title\">Core Capabilities</h2><span class=\"section-sub\">Advisory &amp; Technical Disciplines</span></div>"
    sec_services+="<div class=\"grid-svc\">"
    local idx
    for idx in 0 1 2 3; do
        sec_services+="<article class=\"card\"><div class=\"card-kicker\">0$((idx + 1))</div><h3>$(html_escape "${svc_titles[${idx}]}")</h3><p>$(html_escape "${svc_bodies[${idx}]}")</p></article>"
    done
    sec_services+="</div></div></section>"

    local sec_projects=""
    sec_projects+="<section id=\"work\" class=\"content-section\"><div class=\"wrap\">"
    sec_projects+="<div class=\"section-head\"><h2 class=\"section-title\">Selected Commissions</h2><span class=\"section-sub\">Recent European Case Studies</span></div>"
    sec_projects+="<div class=\"grid-proj\">"
    local proj_limit
    proj_limit="$(rand_range 3 4)"
    for ((idx = 0; idx < proj_limit; idx++)); do
        sec_projects+="<article class=\"card\"><div class=\"card-kicker\">$(html_escape "${proj_meta[${idx}]}")</div><h3>$(html_escape "${proj_titles[${idx}]}")</h3><p>$(html_escape "${proj_bodies[${idx}]}")</p></article>"
    done
    sec_projects+="</div></div></section>"

    local sec_method=""
    sec_method+="<section id=\"methodology\" class=\"content-section\"><div class=\"wrap\">"
    sec_method+="<div class=\"section-head\"><h2 class=\"section-title\">Workflow &amp; Methodology</h2><span class=\"section-sub\">Four-Stage Delivery Framework</span></div>"
    sec_method+="<div class=\"grid-2\">"
    for idx in 0 1 2 3; do
        sec_method+="<article class=\"card\"><div class=\"card-kicker\">Phase 0$((idx + 1))</div><h3>$(html_escape "${step_titles[${idx}]}")</h3><p>$(html_escape "${step_bodies[${idx}]}")</p></article>"
    done
    sec_method+="</div></div></section>"

    local sec_faq=""
    sec_faq+="<section id=\"faq\" class=\"content-section\"><div class=\"wrap\">"
    sec_faq+="<div class=\"section-head\"><h2 class=\"section-title\">Technical &amp; Commissioning Notes</h2><span class=\"section-sub\">Frequently Asked Questions</span></div>"
    sec_faq+="<div class=\"faq-list\">"
    for idx in 0 1 2; do
        local open_attr=""
        [[ "${idx}" -eq 0 ]] && open_attr=" open"
        sec_faq+="<details class=\"faq-item\"${open_attr}><summary>$(html_escape "${faq_q[${idx}]}")</summary><p>$(html_escape "${faq_a[${idx}]}")</p></details>"
    done
    sec_faq+="</div></div></section>"

    local sec_contact=""
    sec_contact+="<section id=\"contact\" class=\"content-section\"><div class=\"wrap\">"
    sec_contact+="<div class=\"section-head\"><h2 class=\"section-title\">Office &amp; Inquiries</h2><span class=\"section-sub\">${esc_city} Practice</span></div>"
    sec_contact+="<div class=\"grid-2\">"
    sec_contact+="<div class=\"card\"><div class=\"card-kicker\">Studio Location</div><h3>${esc_city} Office</h3><p>${esc_street}, ${esc_city}<br>Monday – Friday, 09:00 – 18:00 CET</p></div>"
    sec_contact+="<div class=\"card\"><div class=\"card-kicker\">Direct Correspondence</div><h3>New Commissions &amp; Archive</h3><p>General: ${esc_email}<br>Research &amp; Press: ${esc_press}</p></div>"
    sec_contact+="</div></div></section>"

    # Перемешиваем 4 тематические секции и выбираем 3 или 4 из них + фиксируем секцию контактов
    local -a pool_sections=("${sec_services}" "${sec_projects}" "${sec_method}" "${sec_faq}")
    local -a pool_nav=("<a href=\"#services\">Capabilities</a>" "<a href=\"#work\">Commissions</a>" "<a href=\"#methodology\">Methodology</a>" "<a href=\"#faq\">Notes</a>")
    local keep_count
    keep_count="$(rand_range 3 4)"
    local shuffled_order
    shuffled_order="$(shuffle_indices 4)"

    local rendered_sections=""
    local rendered_nav=""
    local picked=0
    local s_idx
    for s_idx in ${shuffled_order}; do
        if [[ "${picked}" -lt "${keep_count}" ]]; then
            rendered_sections+="${pool_sections[${s_idx}]}"$'
'
            rendered_nav+="${pool_nav[${s_idx}]}"
            picked=$((picked + 1))
        fi
    done
    rendered_sections+="${sec_contact}"$'
'
    rendered_nav+="<a href=\"#contact\">Contact</a>"

    local hero_aside_html=""
    if [[ "${hero_layout}" -ne 2 ]]; then
        hero_aside_html="<aside class=\"hero-aside\"><div><div class=\"card-kicker\">Practice Standard</div><h3>${esc_mis_t}</h3><p>${esc_mis_b}</p></div><div class=\"deco-strip\" aria-hidden=\"true\"></div></aside>"
    fi

    cat > "${stage_dir}/index.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <meta name="description" content="${esc_brand} — ${esc_tagline}">
  <meta name="generator" content="procedural-static-${seed_hex:0:12}">
  <title>${esc_brand} — ${esc_tagline}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <header class="site-header">
    <div class="wrap header-inner">
      <a href="/" class="brand-mark"><span class="brand-badge">${brand_initials}</span><span>${esc_brand}</span></a>
      <nav class="nav-links" aria-label="Primary Navigation">
        ${rendered_nav}
      </nav>
    </div>
  </header>

  <main>
    <section class="hero-block">
      <div class="wrap hero-grid">
        <div>
          <span class="eyebrow">${esc_tagline}</span>
          <h1 class="hero-title">${esc_hero_t}</h1>
          <p class="hero-lead">${esc_hero_l}</p>
        </div>
        ${hero_aside_html}
      </div>
    </section>

    ${rendered_sections}
  </main>

  <footer class="site-footer">
    <div class="wrap footer-inner">
      <span>&copy; 2026 ${esc_brand}. All rights reserved.</span>
      <span>${esc_city} &bull; ${brand_slug}</span>
    </div>
  </footer>
  <script src="/assets/app.js" defer></script>
</body>
</html>
EOF

    cat > "${stage_dir}/404.html" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>404 — Page Not Found | ${esc_brand}</title>
  <link rel="icon" type="image/svg+xml" href="/favicon.svg">
  <link rel="stylesheet" href="/assets/style.css">
</head>
<body>
  <header class="site-header">
    <div class="wrap header-inner">
      <a href="/" class="brand-mark"><span class="brand-badge">${brand_initials}</span><span>${esc_brand}</span></a>
      <nav class="nav-links"><a href="/">Overview</a><a href="/#contact">Contact</a></nav>
    </div>
  </header>
  <main>
    <section class="content-section">
      <div class="wrap">
        <div class="card">
          <div class="card-kicker">Error 404</div>
          <h3>Requested Archive Page Not Found</h3>
          <p>The document or project reference you followed is not available in the public index of ${esc_brand}.</p>
          <a href="/" class="btn-link">Return to Overview</a>
        </div>
      </div>
    </section>
  </main>
  <footer class="site-footer">
    <div class="wrap footer-inner"><span>&copy; 2026 ${esc_brand}.</span><span>${esc_city}</span></div>
  </footer>
</body>
</html>
EOF

    sync_cover_site_domain_metadata "${stage_dir}"
}

generate_procedural_cover_site() {
    local target_dir="${1:-${WEB_ROOT}}"
    local force_regen="${2:-0}"

    if [[ "${force_regen}" != "1" && -s "${target_dir}/index.html" && -s "${target_dir}/assets/style.css" ]]; then
        log_info_tr "installation.log" "M_0136" "${target_dir}"
        return 0
    fi

    log_info_tr "installation.log" "M_0137" "${target_dir}"
    local prev_hash=""
    if [[ -f "${target_dir}/index.html" ]]; then
        prev_hash="$(sha256sum "${target_dir}/index.html" | awk '{print $1}')"
    elif [[ -f "${STATE_DIR}/cover-site.sha256" ]]; then
        prev_hash="$(cat "${STATE_DIR}/cover-site.sha256" 2>/dev/null || true)"
    fi

    local stage_dir
    stage_dir="$(mktemp -d /tmp/cover-site-gen.XXXXXX)"
    chmod 0755 "${stage_dir}"

    local attempt=1
    local valid_ok=0
    while [[ "${attempt}" -le 5 ]]; do
        rm -rf "${stage_dir:?}/"*
        render_procedural_cover_attempt "${stage_dir}"
        local rc=0
        validate_generated_cover_site "${stage_dir}" "${prev_hash}" || rc=$?
        if [[ "${rc}" -eq 0 ]]; then
            valid_ok=1
            break
        fi
        attempt=$((attempt + 1))
    done

    if [[ "${valid_ok}" -ne 1 ]]; then
        rm -rf "${stage_dir}"
        log_error_tr "installation.log" "M_0138"
        return 1
    fi

    install -d -m 0755 -o root -g root "${target_dir}" "${target_dir}/assets"
    chmod 0755 "${stage_dir}" "${stage_dir}/assets"
    chmod 0644 "${stage_dir}/index.html" "${stage_dir}/404.html" "${stage_dir}/favicon.svg" \
               "${stage_dir}/robots.txt" "${stage_dir}/sitemap.xml" \
               "${stage_dir}/assets/style.css" "${stage_dir}/assets/app.js"
    chown -R root:root "${stage_dir}"

    cp -a "${stage_dir}/." "${target_dir}/"
    rm -rf "${stage_dir}"

    local final_hash
    final_hash="$(sha256sum "${target_dir}/index.html" | awk '{print $1}')"
    if [[ -d "${STATE_DIR}" ]]; then
        printf '%s
' "${final_hash}" > "${STATE_DIR}/cover-site.sha256"
        chmod 0600 "${STATE_DIR}/cover-site.sha256"
    fi
    log_info_tr "installation.log" "M_0139" "${final_hash:0:16}"
}

configure_nginx() {
    log_info_tr "installation.log" "M_0140"
    install -d -m 0750 -o www-data -g adm /var/log/nginx
    touch /var/log/nginx/doh-auth.log /var/log/nginx/dot-auth.log
    chown www-data:adm /var/log/nginx/doh-auth.log /var/log/nginx/dot-auth.log
    chmod 0640 /var/log/nginx/doh-auth.log /var/log/nginx/dot-auth.log

    local acme_http01_block=""
    local nginx_server_names="${ROOT_DOMAIN} www.${ROOT_DOMAIN} ${DOT_HOST} _"
    if is_hostname_profile; then
        validate_safe_abs_path "${HOSTNAME_ACME_WEBROOT}" || return 1
        nginx_server_names="${ROOT_DOMAIN} _"
        acme_http01_block="
        location ^~ /.well-known/acme-challenge/ {
            root ${HOSTNAME_ACME_WEBROOT};
            default_type \"text/plain\";
            autoindex off;
            try_files \$uri =404;
        }"
    fi

    cat > /etc/nginx/nginx.conf.tmp <<EOF
user www-data;
worker_processes auto;
pid /run/nginx.pid;

events {
    worker_connections 2048;
    multi_accept on;
}

# Internal DoT TLS terminator (receives SNI-verified stream from Xray dot-in)
stream {
    log_format dot_stream '\$time_iso8601|\$remote_addr|\$protocol|\$status|\$bytes_sent|\$bytes_received';

    server {
        listen 127.0.0.1:8853 ssl;
        ssl_certificate ${CERT_DIR}/fullchain.pem;
        ssl_certificate_key ${CERT_DIR}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers HIGH:!aNULL:!MD5;
        ssl_handshake_timeout 10s;

        proxy_pass 127.0.0.1:5353;
        proxy_timeout 30s;
        proxy_connect_timeout 5s;
        access_log /var/log/nginx/dot-auth.log dot_stream;
    }
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    server_tokens off;
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;

    # Never log \$request_uri so secret DOH_PATH is never written to disk
    log_format doh_auth_fmt '\$time_iso8601|\$remote_addr|\$status|\$upstream_status|\$upstream_http_content_type|\$bytes_sent';
    log_format web_auth_fmt '\$time_iso8601|\$remote_addr|\$status|200|web-auth-verified|\$bytes_sent';
    log_format safe_main '\$remote_addr - [\$time_local] "\$request_method \$scheme://\$host/" \$status \$body_bytes_sent';

    access_log /var/log/nginx/access.log safe_main;
    error_log /var/log/nginx/error.log warn;

    limit_req_zone \$binary_remote_addr zone=doh_ratelimit:10m rate=200r/s;
    limit_req_zone \$binary_remote_addr zone=web_ratelimit:10m rate=30r/s;

    map "\$request_method:\$arg_dns" \$doh_get_ok {
        "~^GET:[A-Za-z0-9_=-]{12,2048}\$" 1;
        default 0;
    }

    map "\$request_method:\$content_type" \$doh_post_ok {
        "~*^POST:application/dns-message" 1;
        default 0;
    }

    map "\$doh_get_ok:\$doh_post_ok" \$doh_req_valid {
        "1:0" 1;
        "0:1" 1;
        default 0;
    }

    map "\$request_method" \$web_auth_method_ok {
        GET 1;
        HEAD 1;
        default 0;
    }

    map "\$status:\$upstream_status:\$upstream_http_content_type" \$doh_verified {
        "200:200:application/dns-message" 1;
        default 0;
    }

    server {
        listen 80 default_server;
        listen [::]:80 default_server;
        server_name _;

        location ~ ^/(generate_204|gen_204)\$ {
            return 204;
        }
${acme_http01_block}
        location / {
            return 301 https://\$host\$request_uri;
        }
    }

    # Unified Stealth Server: Studio Nord Website + Root Domain DoH & Web-Auth
    server {
        listen 9443 ssl default_server;
        listen [::]:9443 ssl default_server;
        listen 127.0.0.1:9444 ssl proxy_protocol default_server;
        http2 on;
        server_name ${nginx_server_names};

        set_real_ip_from 127.0.0.1;
        real_ip_header proxy_protocol;

        ssl_certificate ${CERT_DIR}/fullchain.pem;
        ssl_certificate_key ${CERT_DIR}/privkey.pem;
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_prefer_server_ciphers on;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;

        add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header X-Frame-Options "DENY" always;
        add_header Referrer-Policy "no-referrer" always;
        add_header Content-Security-Policy "default-src 'self'; style-src 'self'; img-src 'self' data:; script-src 'none'; object-src 'none'" always;

        root ${WEB_ROOT};
        index index.html;
        error_page 404 /404.html;

        location = /404.html {
            internal;
        }

        # Secret Browser Bookmark Endpoint for one-tap Wi-Fi IP authorization
        location = /auth/${DOH_PATH} {
            limit_req zone=web_ratelimit burst=15 nodelay;
            if (\$web_auth_method_ok = 0) {
                return 404;
            }
            default_type text/html;
            charset utf-8;
            add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
            add_header Pragma "no-cache" always;
            add_header X-Robots-Tag "noindex, nofollow" always;
            access_log /var/log/nginx/doh-auth.log web_auth_fmt;
            return 200 '<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"><title>Studio Nord — Client Session Active</title><link rel="icon" type="image/svg+xml" href="/favicon.svg"><link rel="stylesheet" href="/assets/style.css"></head><body><header><div class="nav-container"><a href="/" class="brand">Studio Nord</a></div></header><section class="section"><div class="card"><h3>Client Portal / Session Synchronized</h3><p>Network endpoint <strong>\$remote_addr</strong> is verified for active workspace access (24h lease).</p><a href="/" class="btn">Return to Studio Overview</a></div></section><footer>&copy; 2026 Studio Nord Architecture AB.</footer></body></html>';
        }

        # Secret DoH Endpoint disguised inside root domain
        location = /resolve/${DOH_PATH} {
            limit_req zone=doh_ratelimit burst=300 nodelay;
            if (\$doh_req_valid = 0) {
                return 404;
            }

            proxy_http_version 1.1;
            proxy_request_buffering on;
            proxy_buffering on;
            proxy_set_header Host \$host;
            proxy_set_header Connection "";
            proxy_hide_header Server;
            proxy_hide_header X-Powered-By;
            proxy_pass http://127.0.0.1:8053/dns-query;

            access_log /var/log/nginx/doh-auth.log doh_auth_fmt if=\$doh_verified;
        }

        location / {
            limit_req zone=web_ratelimit burst=40 nodelay;
            try_files \$uri \$uri/ =404;
        }
    }
}
EOF
    backup_file_before_modify "/etc/nginx/nginx.conf" "nginx" || return 1
    mv -f /etc/nginx/nginx.conf.tmp /etc/nginx/nginx.conf
    nginx -t
}

# ------------------------------ Dynamic Allowlist Watchers --------------------
install_ipset_watchers() {
    log_info_tr "firewall.log" "M_0141"

    cat > /usr/local/bin/doh-ipset-watcher.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

LOG_FILE="/var/log/nginx/doh-auth.log"
FIREWALL_LOG="/var/log/oxidns-installer/firewall.log"
IPSET_SAVE="/var/lib/oxidns-installer/ipset-whitelist.save"

mkdir -p "$(dirname "${LOG_FILE}")" "$(dirname "${FIREWALL_LOG}")"
touch "${LOG_FILE}" "${FIREWALL_LOG}"

declare -A LAST_SEEN
LAST_PERSIST=0

is_valid_ipv4() {
    local ip="$1"
    [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
    local IFS='.'
    read -r o1 o2 o3 o4 <<<"${ip}"
    [[ "${o1}" -le 255 && "${o2}" -le 255 && "${o3}" -le 255 && "${o4}" -le 255 ]]
}

is_valid_ipv6() {
    local ip="$1"
    [[ "${ip}" =~ ^[0-9a-fA-F:]+$ ]] && [[ "${ip}" == *:* ]]
}

tail -n 0 -F "${LOG_FILE}" 2>/dev/null | while IFS='|' read -r ts client_ip status up_status ctype bytes_sent; do
    [[ "${status:-}" == "200" && "${up_status:-}" == "200" ]] || continue
    [[ "${ctype:-}" == "application/dns-message" || "${ctype:-}" == "web-auth-verified" ]] || continue
    [[ "${bytes_sent:-0}" =~ ^[0-9]+$ && "${bytes_sent}" -ge 12 ]] || continue

    client_ip="${client_ip#::ffff:}"
    now="$(date +%s)"
    key="${ctype}:${client_ip}"
    prev="${LAST_SEEN[${key}]:-0}"

    if [[ "${ctype}" != "web-auth-verified" && $((now - prev)) -lt 60 ]]; then
        continue
    fi

    if is_valid_ipv4 "${client_ip}"; then
        [[ "${client_ip}" =~ ^(127\.|10\.|192\.168\.|169\.254\.) ]] && continue
        if ipset add smartdns_clients "${client_ip}" timeout 86400 -exist 2>/dev/null; then
            LAST_SEEN["${key}"]="${now}"
            if [[ "${ctype}" == "web-auth-verified" ]]; then
                ipset add dot_clients "${client_ip}" timeout 86400 -exist 2>/dev/null || true
                printf '[%s] [WEB-AUTH] Авторизован IPv4 %s через веб-закладку (TTL 86400s)\n' "$(date -Is)" "${client_ip}" >> "${FIREWALL_LOG}"
            else
                printf '[%s] [DOH-AUTH] Авторизован IPv4 %s (TTL 86400s)\n' "$(date -Is)" "${client_ip}" >> "${FIREWALL_LOG}"
            fi
        fi
    elif is_valid_ipv6 "${client_ip}"; then
        [[ "${client_ip}" == "::1" || "${client_ip}" =~ ^fe80: || "${client_ip}" =~ ^fc00: || "${client_ip}" =~ ^fd00: ]] && continue
        if ipset add smartdns_clients6 "${client_ip}" timeout 86400 -exist 2>/dev/null; then
            LAST_SEEN["${key}"]="${now}"
            if [[ "${ctype}" == "web-auth-verified" ]]; then
                ipset add dot_clients6 "${client_ip}" timeout 86400 -exist 2>/dev/null || true
                printf '[%s] [WEB-AUTH] Авторизован IPv6 %s через веб-закладку (TTL 86400s)\n' "$(date -Is)" "${client_ip}" >> "${FIREWALL_LOG}"
            else
                printf '[%s] [DOH-AUTH] Авторизован IPv6 %s (TTL 86400s)\n' "$(date -Is)" "${client_ip}" >> "${FIREWALL_LOG}"
            fi
        fi
    fi

    if [[ "${ctype}" == "web-auth-verified" || $((now - LAST_PERSIST)) -ge 30 ]]; then
        ipset save > "${IPSET_SAVE}.tmp" 2>/dev/null && mv -f "${IPSET_SAVE}.tmp" "${IPSET_SAVE}" || true
        LAST_PERSIST="${now}"
    fi
done
EOF
    chmod 0755 /usr/local/bin/doh-ipset-watcher.sh

    cat > /usr/local/bin/dot-ipset-watcher.sh <<'EOF'
#!/usr/bin/env bash
set -uo pipefail

XRAY_ACCESS_LOG="/var/log/xray/access.log"
FIREWALL_LOG="/var/log/oxidns-installer/firewall.log"
SETTINGS_FILE="/var/lib/oxidns-installer/settings"
IPSET_SAVE="/var/lib/oxidns-installer/ipset-whitelist.save"

mkdir -p "$(dirname "${XRAY_ACCESS_LOG}")" "$(dirname "${FIREWALL_LOG}")"
touch "${XRAY_ACCESS_LOG}" "${FIREWALL_LOG}"

declare -A LAST_DOT_SEEN
LAST_PERSIST=0

tail -n 0 -F "${XRAY_ACCESS_LOG}" 2>/dev/null | while IFS= read -r line; do
    [[ "${line}" == *"[dot-in -> dot-backend]"* || "${line}" == *"[dot-in >> dot-backend]"* ]] || continue

    src_token="$(awk '{for(i=1;i<=NF;i++) if($i=="from") {print $(i+1); exit}}' <<<"${line}")"
    src_token="${src_token#tcp:}"
    client_ip="${src_token%:*}"
    client_ip="${client_ip#[}"
    client_ip="${client_ip%]}"
    client_ip="${client_ip#::ffff:}"

    now="$(date +%s)"
    prev="${LAST_DOT_SEEN[${client_ip}]:-0}"
    [[ $((now - prev)) -ge 60 ]] || continue

    dot_wl_mode="shared"
    if [[ -f "${SETTINGS_FILE}" ]]; then
        dot_wl_mode="$(awk -F'"' '/^DOT_WHITELIST_MODE=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || echo "shared")"
    fi

    if [[ "${client_ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        [[ "${client_ip}" =~ ^(127\.|10\.|192\.168\.|169\.254\.) ]] && continue
        if ipset add smartdns_clients "${client_ip}" timeout 86400 -exist 2>/dev/null; then
            LAST_DOT_SEEN["${client_ip}"]="${now}"
            if [[ "${dot_wl_mode}" == "separate" ]]; then
                ipset add dot_clients "${client_ip}" timeout 86400 -exist 2>/dev/null || true
            fi
            printf '[%s] [DOT-AUTH] Авторизован IPv4 %s через DoT (TTL 86400s, режим %s)\n' "$(date -Is)" "${client_ip}" "${dot_wl_mode}" >> "${FIREWALL_LOG}"
        fi
    elif [[ "${client_ip}" =~ ^[0-9a-fA-F:]+$ ]] && [[ "${client_ip}" == *:* ]]; then
        [[ "${client_ip}" == "::1" || "${client_ip}" =~ ^fe80: || "${client_ip}" =~ ^fc00: || "${client_ip}" =~ ^fd00: ]] && continue
        if ipset add smartdns_clients6 "${client_ip}" timeout 86400 -exist 2>/dev/null; then
            LAST_DOT_SEEN["${client_ip}"]="${now}"
            if [[ "${dot_wl_mode}" == "separate" ]]; then
                ipset add dot_clients6 "${client_ip}" timeout 86400 -exist 2>/dev/null || true
            fi
            printf '[%s] [DOT-AUTH] Авторизован IPv6 %s через DoT (TTL 86400s, режим %s)\n' "$(date -Is)" "${client_ip}" "${dot_wl_mode}" >> "${FIREWALL_LOG}"
        fi
    fi

    if [[ $((now - LAST_PERSIST)) -ge 30 ]]; then
        ipset save > "${IPSET_SAVE}.tmp" 2>/dev/null && mv -f "${IPSET_SAVE}.tmp" "${IPSET_SAVE}" || true
        LAST_PERSIST="${now}"
    fi
done
EOF
    chmod 0755 /usr/local/bin/dot-ipset-watcher.sh
}

# ------------------------------ Firewall, ipset & Sysctl ----------------------
configure_firewall_and_sysctl() {
    log_info_tr "firewall.log" "M_0142"

    backup_file_before_modify "/etc/sysctl.d/90-smartdns-keepalive.conf" "firewall" || return 1
    cat > /etc/sysctl.d/90-smartdns-keepalive.conf <<'EOF'
net.ipv4.tcp_keepalive_time = 120
net.ipv4.tcp_keepalive_intvl = 30
net.ipv4.tcp_keepalive_probes = 4
net.ipv4.tcp_mtu_probing = 1
EOF
    sysctl --system >/dev/null 2>&1 || true

    cat > /usr/local/bin/smartdns-firewall-apply.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck disable=SC1091
source /var/lib/oxidns-installer/settings

STATE_DIR="/var/lib/oxidns-installer"
IPSET_SAVE_FILE="${STATE_DIR}/ipset-whitelist.save"
FW_BACKUP_DIR="${STATE_DIR}/fw-backup"
mkdir -p "${FW_BACKUP_DIR}"
chmod 0700 "${FW_BACKUP_DIR}"

iptables-save > "${FW_BACKUP_DIR}/iptables.v4.bak" 2>/dev/null || true
ip6tables-save > "${FW_BACKUP_DIR}/iptables.v6.bak" 2>/dev/null || true
ipset save > "${FW_BACKUP_DIR}/ipset.bak" 2>/dev/null || true

# 1. Create or ensure ipset tables exist
ipset create smartdns_clients hash:ip family inet timeout 86400 -exist
ipset create smartdns_clients6 hash:ip family inet6 timeout 86400 -exist
ipset create dot_clients hash:ip family inet timeout 86400 -exist
ipset create dot_clients6 hash:ip family inet6 timeout 86400 -exist

if [[ -s "${IPSET_SAVE_FILE}" ]]; then
    ipset restore -! < "${IPSET_SAVE_FILE}" 2>/dev/null || true
fi

DOT_WL_ENABLED="${DOT_WHITELIST_ENABLED:-false}"
DOT_WL_MODE="${DOT_WHITELIST_MODE:-shared}"

if [[ "${DOT_WL_MODE}" == "separate" ]]; then
    DOT_SET_V4="dot_clients"
    DOT_SET_V6="dot_clients6"
else
    DOT_SET_V4="smartdns_clients"
    DOT_SET_V6="smartdns_clients6"
fi

# 2. Cleanly recreate dedicated IPv4 chains
iptables -t nat -N SMARTDNS_PREROUTING 2>/dev/null || iptables -t nat -F SMARTDNS_PREROUTING
iptables -t filter -N SMARTDNS_INPUT 2>/dev/null || iptables -t filter -F SMARTDNS_INPUT
iptables -t filter -N SMARTDNS_OUTPUT 2>/dev/null || iptables -t filter -F SMARTDNS_OUTPUT

for cidr in 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16 "${SERVER_IPV4}/32"; do
    iptables -t nat -A SMARTDNS_PREROUTING -s "${cidr}" -j RETURN
done

iptables -t nat -A SMARTDNS_PREROUTING -p tcp --dport 443 -m set --match-set smartdns_clients src -j REDIRECT --to-ports 8444
if [[ "${DOT_WL_MODE}" == "separate" ]]; then
    iptables -t nat -A SMARTDNS_PREROUTING -p tcp --dport 443 -m set --match-set dot_clients src -j REDIRECT --to-ports 8444
fi
iptables -t nat -A SMARTDNS_PREROUTING -p tcp --dport 443 -j REDIRECT --to-ports 9443

if ! iptables -t nat -C PREROUTING -j SMARTDNS_PREROUTING 2>/dev/null; then
    iptables -t nat -I PREROUTING 1 -j SMARTDNS_PREROUTING
fi

# INPUT Chain Protection (IPv4)
iptables -t filter -A SMARTDNS_INPUT -p tcp ! --syn -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset
iptables -t filter -A SMARTDNS_INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

if [[ "${DOT_WL_ENABLED}" == "true" ]]; then
    iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 853 -m set --match-set "${DOT_SET_V4}" src \
        -m hashlimit --hashlimit-name dot_v4_rate --hashlimit-mode srcip --hashlimit-upto 30/min --hashlimit-burst 40 -j ACCEPT
    iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 853 -j DROP
else
    iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 853 --syn \
        -m hashlimit --hashlimit-name dot_v4_rate --hashlimit-mode srcip --hashlimit-above 30/min --hashlimit-burst 40 -j DROP
    iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 853 -j ACCEPT
fi

iptables -t filter -A SMARTDNS_INPUT -i lo -j ACCEPT
iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 9443 -m conntrack --ctstate DNAT --ctorigdstport 443 -j ACCEPT
iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 9443 -j DROP
iptables -t filter -A SMARTDNS_INPUT -p tcp -m multiport --dports 8443,9444,8853,5353,8053,3000 -j DROP
iptables -t filter -A SMARTDNS_INPUT -p udp --dport 5353 -j DROP
iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 8444 -m conntrack --ctstate DNAT --ctorigdstport 443 -m set --match-set smartdns_clients src -j ACCEPT
if [[ "${DOT_WL_MODE}" == "separate" ]]; then
    iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 8444 -m conntrack --ctstate DNAT --ctorigdstport 443 -m set --match-set dot_clients src -j ACCEPT
fi
iptables -t filter -A SMARTDNS_INPUT -p tcp --dport 8444 -j DROP

if ! iptables -t filter -C INPUT -j SMARTDNS_INPUT 2>/dev/null; then
    iptables -t filter -I INPUT 1 -j SMARTDNS_INPUT
fi

# OUTPUT Chain Anti-Loop & Anti-SSRF for Xray user (allows local ports 9443, 9444, 8853)
XRAY_UID="$(id -u xray)"
iptables -t filter -A SMARTDNS_OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
iptables -t filter -A SMARTDNS_OUTPUT -m owner --uid-owner "${XRAY_UID}" -d 127.0.0.1/32 -p tcp -m multiport --dports 9443,9444,8853 -j ACCEPT
for cidr in "${SERVER_IPV4}/32" 127.0.0.0/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 169.254.0.0/16; do
    iptables -t filter -A SMARTDNS_OUTPUT -m owner --uid-owner "${XRAY_UID}" -p tcp -d "${cidr}" -j REJECT --reject-with tcp-reset
    iptables -t filter -A SMARTDNS_OUTPUT -m owner --uid-owner "${XRAY_UID}" -d "${cidr}" -j DROP
done

if ! iptables -t filter -C OUTPUT -j SMARTDNS_OUTPUT 2>/dev/null; then
    iptables -t filter -I OUTPUT 1 -j SMARTDNS_OUTPUT
fi

# 3. IPv6 Protection
ip6tables -t nat -N SMARTDNS6_PREROUTING 2>/dev/null || ip6tables -t nat -F SMARTDNS6_PREROUTING
ip6tables -t filter -N SMARTDNS6_INPUT 2>/dev/null || ip6tables -t filter -F SMARTDNS6_INPUT
ip6tables -t filter -N SMARTDNS6_OUTPUT 2>/dev/null || ip6tables -t filter -F SMARTDNS6_OUTPUT

for cidr6 in ::1/128 fe80::/10 fc00::/7; do
    ip6tables -t nat -A SMARTDNS6_PREROUTING -s "${cidr6}" -j RETURN
done
if [[ -n "${SERVER_IPV6:-}" ]]; then
    ip6tables -t nat -A SMARTDNS6_PREROUTING -s "${SERVER_IPV6}/128" -j RETURN
fi
ip6tables -t nat -A SMARTDNS6_PREROUTING -p tcp --dport 443 -m set --match-set smartdns_clients6 src -j REDIRECT --to-ports 8444
if [[ "${DOT_WL_MODE}" == "separate" ]]; then
    ip6tables -t nat -A SMARTDNS6_PREROUTING -p tcp --dport 443 -m set --match-set dot_clients6 src -j REDIRECT --to-ports 8444
fi
ip6tables -t nat -A SMARTDNS6_PREROUTING -p tcp --dport 443 -j REDIRECT --to-ports 9443

if ! ip6tables -t nat -C PREROUTING -j SMARTDNS6_PREROUTING 2>/dev/null; then
    ip6tables -t nat -I PREROUTING 1 -j SMARTDNS6_PREROUTING
fi

ip6tables -t filter -A SMARTDNS6_INPUT -p tcp ! --syn -m conntrack --ctstate INVALID -j REJECT --reject-with tcp-reset
ip6tables -t filter -A SMARTDNS6_INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

if [[ "${DOT_WL_ENABLED}" == "true" ]]; then
    ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 853 -m set --match-set "${DOT_SET_V6}" src \
        -m hashlimit --hashlimit-name dot_v6_rate --hashlimit-mode srcip --hashlimit-upto 30/min --hashlimit-burst 40 -j ACCEPT
    ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 853 -j DROP
else
    ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 853 --syn \
        -m hashlimit --hashlimit-name dot_v6_rate --hashlimit-mode srcip --hashlimit-above 30/min --hashlimit-burst 40 -j DROP
    ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 853 -j ACCEPT
fi

ip6tables -t filter -A SMARTDNS6_INPUT -i lo -j ACCEPT
ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 9443 -m conntrack --ctstate DNAT --ctorigdstport 443 -j ACCEPT
ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 9443 -j DROP
ip6tables -t filter -A SMARTDNS6_INPUT -p tcp -m multiport --dports 8443,9444,8853,5353,8053,3000 -j DROP
ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 8444 -m conntrack --ctstate DNAT --ctorigdstport 443 -m set --match-set smartdns_clients6 src -j ACCEPT
if [[ "${DOT_WL_MODE}" == "separate" ]]; then
    ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 8444 -m conntrack --ctstate DNAT --ctorigdstport 443 -m set --match-set dot_clients6 src -j ACCEPT
fi
ip6tables -t filter -A SMARTDNS6_INPUT -p tcp --dport 8444 -j DROP
ip6tables -t filter -A SMARTDNS6_INPUT -p udp --dport 5353 -j DROP

if ! ip6tables -t filter -C INPUT -j SMARTDNS6_INPUT 2>/dev/null; then
    ip6tables -t filter -I INPUT 1 -j SMARTDNS6_INPUT
fi

ip6tables -t filter -A SMARTDNS6_OUTPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
for cidr6 in ::1/128 fe80::/10 fc00::/7; do
    ip6tables -t filter -A SMARTDNS6_OUTPUT -m owner --uid-owner "${XRAY_UID}" -p tcp -d "${cidr6}" -j REJECT --reject-with tcp-reset
    ip6tables -t filter -A SMARTDNS6_OUTPUT -m owner --uid-owner "${XRAY_UID}" -d "${cidr6}" -j DROP
done
if [[ -n "${SERVER_IPV6:-}" ]]; then
    ip6tables -t filter -A SMARTDNS6_OUTPUT -m owner --uid-owner "${XRAY_UID}" -p tcp -d "${SERVER_IPV6}/128" -j REJECT --reject-with tcp-reset
    ip6tables -t filter -A SMARTDNS6_OUTPUT -m owner --uid-owner "${XRAY_UID}" -d "${SERVER_IPV6}/128" -j DROP
fi
if ! ip6tables -t filter -C OUTPUT -j SMARTDNS6_OUTPUT 2>/dev/null; then
    ip6tables -t filter -I OUTPUT 1 -j SMARTDNS6_OUTPUT
fi

ipset save > "${IPSET_SAVE_FILE}.tmp" 2>/dev/null && mv -f "${IPSET_SAVE_FILE}.tmp" "${IPSET_SAVE_FILE}" || true
EOF
    chmod 0755 /usr/local/bin/smartdns-firewall-apply.sh

    local ssh_port
    ssh_port="$(ss -tlnp | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')"
    ssh_port="${ssh_port:-22}"

    backup_file_before_modify "/etc/ufw" "firewall" || return 1
    ufw allow "${ssh_port}/tcp" comment 'SSH Access' >/dev/null
    ufw allow 80/tcp comment 'HTTP Redirect' >/dev/null
    ufw allow 443/tcp comment 'SmartDNS HTTPS / SNI Proxy' >/dev/null
    ufw allow 853/tcp comment 'SmartDNS DoT' >/dev/null
    firewall_allow_all_ssh_ports_ufw
    ufw --force enable >/dev/null

    /usr/local/bin/smartdns-firewall-apply.sh
    seed_initial_admin_ip
    log_info_tr "firewall.log" "M_0143" "${IPTABLES_BACKEND}" "${DOT_WHITELIST_ENABLED}" "${DOT_WHITELIST_MODE}"
    firewall_verify_ssh_ports_open
}

seed_initial_admin_ip() {
    local admin_ip=""
    if [[ -n "${SSH_CLIENT:-}" ]]; then
        admin_ip="$(awk '{print $1}' <<<"${SSH_CLIENT}")"
    elif [[ -n "${SSH_CONNECTION:-}" ]]; then
        admin_ip="$(awk '{print $1}' <<<"${SSH_CONNECTION}")"
    fi
    admin_ip="${admin_ip#::ffff:}"

    if [[ -z "${admin_ip}" ]]; then
        return 0
    fi

    if validate_single_ipv4 "${admin_ip}"; then
        if [[ ! "${admin_ip}" =~ ^(127\.|10\.|192\.168\.|169\.254\.) ]]; then
            ipset add smartdns_clients "${admin_ip}" timeout 86400 -exist
            ipset add dot_clients "${admin_ip}" timeout 86400 -exist
            persist_ipset_state
            log_info_tr "firewall.log" "M_0144" "${admin_ip}"
        fi
    elif validate_single_ipv6 "${admin_ip}"; then
        if [[ "${admin_ip}" != "::1" && ! "${admin_ip}" =~ ^fe80: && ! "${admin_ip}" =~ ^fc00: && ! "${admin_ip}" =~ ^fd00: ]]; then
            ipset add smartdns_clients6 "${admin_ip}" timeout 86400 -exist
            ipset add dot_clients6 "${admin_ip}" timeout 86400 -exist
            persist_ipset_state
            log_info_tr "firewall.log" "M_0145" "${admin_ip}"
        fi
    fi
}

# ------------------------------ Systemd Units ---------------------------------
write_dns_engine_systemd_unit() {
    if [[ "${DNS_ENGINE}" == "oxidns" ]]; then
        cat > /etc/systemd/system/oxidns.service <<'EOF'
[Unit]
Description=OxiDNS SmartDNS Server
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
User=oxidns
Group=oxidns
SupplementaryGroups=xray
WorkingDirectory=/var/lib/oxidns
ExecStartPre=/usr/local/bin/oxidns check -c /etc/oxidns/config.yaml -d /var/lib/oxidns
ExecStart=/usr/local/bin/oxidns start -c /etc/oxidns/config.yaml -d /var/lib/oxidns
Restart=on-failure
RestartSec=3s
TimeoutStartSec=60s
TimeoutStopSec=15s

AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
ReadWritePaths=/var/lib/oxidns
ReadOnlyPaths=/etc/oxidns /var/lib/dns-assets

[Install]
WantedBy=multi-user.target
EOF
    else
        cat > /etc/systemd/system/adguardhome.service <<'EOF'
[Unit]
Description=AdGuardHome SmartDNS Server
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
User=adguard
Group=adguard
SupplementaryGroups=xray
WorkingDirectory=/var/lib/adguardhome
ExecStart=/usr/local/bin/AdGuardHome -c /etc/adguardhome/AdGuardHome.yaml -w /var/lib/adguardhome --no-check-update
Restart=on-failure
RestartSec=3s

AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
ReadWritePaths=/etc/adguardhome /var/lib/adguardhome
ReadOnlyPaths=/var/lib/dns-assets

[Install]
WantedBy=multi-user.target
EOF
    fi
}

install_systemd_units() {
    log_info_tr "installation.log" "M_0146"

    cat > /etc/systemd/system/smartdns-firewall.service <<'EOF'
[Unit]
Description=SmartDNS ipset and Netfilter Rules Manager
After=network-online.target ufw.service
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/smartdns-firewall-apply.sh
ExecStop=/bin/sh -c 'ipset save > /var/lib/oxidns-installer/ipset-whitelist.save'

[Install]
WantedBy=multi-user.target
EOF

    write_dns_engine_systemd_unit

    cat > /etc/systemd/system/xray.service <<'EOF'
[Unit]
Description=Xray Transparent SNI Proxy Service
After=network-online.target smartdns-firewall.service
Wants=network-online.target
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
User=xray
Group=xray
ExecStartPre=/usr/local/bin/xray run -test -confdir /etc/xray/conf.d
ExecStart=/usr/local/bin/xray run -confdir /etc/xray/conf.d
Restart=on-failure
RestartSec=3s
TimeoutStartSec=60s
TimeoutStopSec=15s

AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
ReadWritePaths=/var/log/xray
ReadOnlyPaths=/etc/xray/conf.d /etc/xray/rules.d

[Install]
WantedBy=multi-user.target
EOF

    cat > /usr/local/bin/xray-safe-reload.sh <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

exec 9>/run/lock/xray-safe-reload.lock
if ! flock -n 9; then
    exit 0
fi

LOG_FILE="/var/log/oxidns-installer/xray.log"
BACKUP_GOOD="/var/lib/oxidns-installer/10-smartdns-routing.json.lastgood"
TARGET_JSON="/etc/xray/rules.d/10-smartdns-routing.json"

if /usr/local/bin/xray run -test -confdir /etc/xray/conf.d >> "${LOG_FILE}" 2>&1; then
    cp -a "${TARGET_JSON}" "${BACKUP_GOOD}"
    systemctl restart xray
    printf '[%s] [XRAY-RELOAD] Проверка пройдена, Xray успешно перезагружен.\n' "$(date -Is)" >> "${LOG_FILE}"
else
    printf '[%s] [XRAY-RELOAD] ОШИБКА проверки конфигурации! Восстановление предыдущего рабочего JSON.\n' "$(date -Is)" >> "${LOG_FILE}"
    if [[ -f "${BACKUP_GOOD}" ]]; then
        cp -a "${BACKUP_GOOD}" "${TARGET_JSON}"
    fi
    exit 1
fi
EOF
    chmod 0755 /usr/local/bin/xray-safe-reload.sh

    cat > /etc/systemd/system/xray-reload.path <<'EOF'
[Unit]
Description=Monitor /etc/xray/rules.d/10-smartdns-routing.json for changes

[Path]
PathChanged=/etc/xray/rules.d/10-smartdns-routing.json
Unit=xray-reload.service

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/xray-reload.service <<'EOF'
[Unit]
Description=Validated Xray Configuration Reload Service
After=xray.service

[Service]
Type=oneshot
ExecStart=/usr/local/bin/xray-safe-reload.sh
EOF

    backup_file_before_modify "/etc/systemd/system/nginx.service.d/hardening.conf" "nginx" || return 1
    install -d -m 0755 /etc/systemd/system/nginx.service.d
    cat > /etc/systemd/system/nginx.service.d/hardening.conf <<'EOF'
[Service]
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
RestrictSUIDSGID=true
LockPersonality=true
EOF

    cat > /etc/systemd/system/doh-ipset-watcher.service <<'EOF'
[Unit]
Description=SmartDNS DoH Authorization ipset Watcher
After=nginx.service smartdns-firewall.service
Requires=smartdns-firewall.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/local/bin/doh-ipset-watcher.sh
Restart=on-failure
RestartSec=3s
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/dot-ipset-watcher.service <<'EOF'
[Unit]
Description=SmartDNS DoT Authorization ipset Watcher
After=xray.service nginx.service smartdns-firewall.service
Requires=smartdns-firewall.service
StartLimitIntervalSec=120
StartLimitBurst=5

[Service]
Type=simple
ExecStart=/usr/local/bin/dot-ipset-watcher.sh
Restart=on-failure
RestartSec=3s
NoNewPrivileges=true
PrivateTmp=true
ProtectHome=true
ProtectKernelTunables=true
ProtectKernelModules=true

[Install]
WantedBy=multi-user.target
EOF

    cat > /etc/systemd/system/geosite-update.service <<'EOF'
[Unit]
Description=Update geosite.dat for SmartDNS
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-geosite.sh
EOF

    cat > /etc/systemd/system/geosite-update.timer <<'EOF'
[Unit]
Description=Daily geosite.dat update at 04:00 Europe/Moscow

[Timer]
OnCalendar=*-*-* 04:00:00 Europe/Moscow
Persistent=true

[Install]
WantedBy=timers.target
EOF

    cat > /etc/systemd/system/geohide-update.service <<'EOF'
[Unit]
Description=Update GeoHideDNS domains and Xray routing rules
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/update-geohide-domains.sh
EOF

    cat > /etc/systemd/system/geohide-update.timer <<'EOF'
[Unit]
Description=Daily GeoHideDNS update at 04:05 Europe/Moscow

[Timer]
OnCalendar=*-*-* 04:05:00 Europe/Moscow
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl daemon-reload
    systemctl enable smartdns-firewall.service "${DNS_ENGINE}.service" xray.service \
        xray-reload.path nginx.service doh-ipset-watcher.service dot-ipset-watcher.service \
        geosite-update.timer geohide-update.timer
    if ! is_hostname_profile && [[ -f /etc/systemd/system/smartdns-cert-renew.timer ]]; then
        systemctl enable smartdns-cert-renew.timer
    fi

    systemctl restart smartdns-firewall.service
    systemctl restart "${DNS_ENGINE}.service"
    wait_for_dns_backend_ready "${DNS_ENGINE}" || true
    systemctl restart nginx.service
    systemctl restart xray.service
    systemctl start xray-reload.path
    systemctl restart doh-ipset-watcher.service dot-ipset-watcher.service
    systemctl start geosite-update.timer geohide-update.timer
    if ! is_hostname_profile && [[ -f /etc/systemd/system/smartdns-cert-renew.timer ]]; then
        systemctl start smartdns-cert-renew.timer
    fi
}

# ------------------------------ Isolated Backend Verification & Switcher ------
wait_for_dns_backend_ready() {
    local target_svc="${1:-${DNS_ENGINE}}"
    local _attempt
    for _attempt in {1..20}; do
        if systemctl is-active --quiet "${target_svc}" 2>/dev/null \
            && ss -ulnp 2>/dev/null | grep -q "127.0.0.1:5353 " \
            && ss -tlnp 2>/dev/null | grep -q "127.0.0.1:5353 " \
            && ss -tlnp 2>/dev/null | grep -q "127.0.0.1:8053 "; then
            return 0
        fi
        sleep 1
    done
    return 1
}

verify_dns_backend_isolated() {
    local expected_engine="${DNS_ENGINE}"
    local other_engine="adguardhome"
    [[ "${expected_engine}" == "adguardhome" ]] && other_engine="oxidns"

    printf '==============================================================================\n'
    printf_tr "M_0147" "${expected_engine}"
    printf '==============================================================================\n'

    # 1. Service state & no port conflict
    if ! systemctl is-active --quiet "${expected_engine}"; then
        log_error_tr "dns.log" "M_0148" "${expected_engine}"
        return 1
    fi
    if systemctl is-active --quiet "${other_engine}" 2>/dev/null; then
        log_error_tr "dns.log" "M_0149" "${other_engine}"
        return 1
    fi
    printf_tr "M_0150" "${expected_engine}" "${other_engine}"

    # 2. Listening sockets check (127.0.0.1:5353 UDP/TCP and 127.0.0.1:8053 TCP)
    if ss -ulnp | grep -q "127.0.0.1:5353 " && ss -tlnp | grep -q "127.0.0.1:5353 " && ss -tlnp | grep -q "127.0.0.1:8053 "; then
        printf_tr "M_0151"
    else
        log_error_tr "dns.log" "M_0152" "${expected_engine}"
        return 1
    fi

    # 3. Upstream A resolution + Cache test
    local upstream_ip
    upstream_ip="$(dig +time=4 +tries=2 +short @127.0.0.1 -p 5353 example.com A | sed -n '1p' || true)"
    if ! validate_single_ipv4 "${upstream_ip}" || [[ "${upstream_ip}" == "${SERVER_IPV4}" ]]; then
        log_error_tr "dns.log" "M_0153" "${expected_engine}" "${upstream_ip:-пусто}"
        return 1
    fi
    local cached_ip
    cached_ip="$(dig +time=2 +tries=1 +short @127.0.0.1 -p 5353 example.com A | sed -n '1p' || true)"
    if [[ "${cached_ip}" != "${upstream_ip}" ]]; then
        log_error_tr "dns.log" "M_0154"
        return 1
    fi
    printf_tr "M_0155" "${upstream_ip}"

    # 4-5. SmartDNS A spoofing, AAAA NODATA & HTTPS TYPE65 (динамический домен из активных групп)
    local test_dom
    test_dom="$(get_test_proxied_domain)"
    if [[ -z "${test_dom}" ]]; then
        printf_tr "M_0366" "${SELECTED_DOMAIN_GROUPS:-NONE}"
    else
        local spoofed_ip=""
        for i in {1..15}; do
            spoofed_ip="$(dig +time=2 +tries=1 +short @127.0.0.1 -p 5353 "probe-${i}.${test_dom}" A | sed -n '1p' || true)"
            if [[ "${spoofed_ip}" == "${SERVER_IPV4}" ]]; then
                break
            fi
            sleep 1
        done
        spoofed_ip="$(dig +time=3 +tries=2 +short @127.0.0.1 -p 5353 "${test_dom}" A | sed -n '1p' || true)"
        if [[ "${spoofed_ip}" != "${SERVER_IPV4}" ]]; then
            log_error_tr "dns.log" "M_0156" "${expected_engine}" "${SERVER_IPV4}" "${spoofed_ip:-пусто}"
            return 1
        fi
        printf_tr "M_0157" "${SERVER_IPV4}"

        local aaaa_resp https_resp
        aaaa_resp="$(dig +time=3 +tries=2 @127.0.0.1 -p 5353 "${test_dom}" AAAA || true)"
        https_resp="$(dig +time=3 +tries=2 @127.0.0.1 -p 5353 "${test_dom}" TYPE65 || true)"
        if ! grep -q "status: NOERROR" <<<"${aaaa_resp}" || ! grep -q "ANSWER: 0" <<<"${aaaa_resp}"; then
            log_error_tr "dns.log" "M_0158" "${expected_engine}"
            return 1
        fi
        if ! grep -Eq "status: (NOERROR|REFUSED)" <<<"${https_resp}" || ! grep -q "ANSWER: 0" <<<"${https_resp}"; then
            log_error_tr "dns.log" "M_0159" "${expected_engine}"
            return 1
        fi
        printf_tr "M_0160"
    fi

    # 6. Ad-blocking filter test (allow up to 10s on first AdGuardHome start while filter list initializes)
    local ad_blocked=0
    for _ in {1..10}; do
        local ad_out
        ad_out="$(dig +time=2 +tries=1 @127.0.0.1 -p 5353 doubleclick.net A || true)"
        if grep -q "NXDOMAIN" <<<"${ad_out}" || grep -Eq '[[:space:]]0\.0\.0\.0$' <<<"${ad_out}"; then
            ad_blocked=1
            break
        fi
        sleep 1
    done
    if [[ "${ad_blocked}" -ne 1 ]]; then
        log_error_tr "dns.log" "M_0161" "${expected_engine}"
        return 1
    fi
    printf_tr "M_0162"

    # 7. Direct RFC 8484 HTTP DoH POST on 127.0.0.1:8053/dns-query
    local local_doh_check
    local_doh_check="$(printf '\x12\x34\x01\x00\x00\x01\x00\x00\x00\x00\x00\x00\x07example\x03com\x00\x00\x01\x00\x01' | \
        curl -s -o /dev/null -w '%{http_code}:%{content_type}' \
        -H 'Content-Type: application/dns-message' --data-binary @- \
        'http://127.0.0.1:8053/dns-query' || echo '000:none')"
    if [[ "${local_doh_check}" != "200:application/dns-message" ]]; then
        log_error_tr "dns.log" "M_0163" "${local_doh_check}"
        return 1
    fi
    printf_tr "M_0164" "${local_doh_check}"
    printf '==============================================================================\n'
    return 0
}

run_switch_engine() {
    local target_engine="${1:-}"
    if [[ "${target_engine}" != "oxidns" && "${target_engine}" != "adguardhome" ]]; then
        printf_err_tr "M_0165" "${SCRIPT_NAME}"
        exit 1
    fi

    if [[ ! -f "${SETTINGS_FILE}" || ! -f "${SECRETS_FILE}" ]]; then
        printf_err_tr "M_0166" "${SETTINGS_FILE}"
        exit 1
    fi

    detect_environment
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"
    # shellcheck disable=SC1091
    source "${SECRETS_FILE}"

    local previous_engine="${DNS_ENGINE}"
    if [[ "${previous_engine}" == "${target_engine}" ]] && systemctl is-active --quiet "${target_engine}"; then
        printf_tr "M_0167" "${target_engine}"
        verify_dns_backend_isolated
        run_test_suite
        return 0
    fi

    if [[ "${target_engine}" == "oxidns" && "${CPU_ARCH}" != "x86_64" ]]; then
        printf_err_tr "M_0168"
        exit 1
    fi

    log_info_tr "dns.log" "M_0169" "${previous_engine}" "${target_engine}"
    create_system_backup
    TRANSACTION_ACTIVE=1

    if [[ "${target_engine}" == "adguardhome" ]]; then
        if [[ ! -x /usr/local/bin/AdGuardHome ]]; then
            install_adguardhome_binary
        fi
        DNS_ENGINE="adguardhome"
        DNS_USER="adguard"
    else
        if [[ ! -x /usr/local/bin/oxidns ]]; then
            install_oxidns_binary
        fi
        DNS_ENGINE="oxidns"
        DNS_USER="oxidns"
    fi

    setup_users_and_dirs
    save_persistent_settings
    configure_dns_engine
    write_dns_engine_systemd_unit
    systemctl daemon-reload

    log_info_tr "dns.log" "M_0170" "${previous_engine}" "${target_engine}"
    systemctl disable --now "${previous_engine}.service" 2>/dev/null || true

    for _ in {1..10}; do
        if ! ss -ulnp 2>/dev/null | grep -q ":5353 " && ! ss -tlnp 2>/dev/null | grep -q ":8053 "; then
            break
        fi
        sleep 1
    done

    systemctl enable --now "${target_engine}.service"

    local ready=0
    for _ in {1..15}; do
        if ss -ulnp 2>/dev/null | grep -q "127.0.0.1:5353 " && ss -tlnp 2>/dev/null | grep -q "127.0.0.1:8053 "; then
            ready=1
            break
        fi
        sleep 1
    done

    if [[ "${ready}" -ne 1 ]]; then
        log_error_tr "dns.log" "M_0171" "${target_engine}"
        return 1
    fi

    verify_dns_backend_isolated
    nginx -t && systemctl reload nginx
    run_test_suite
    record_full_install_manifest

    TRANSACTION_ACTIVE=0
    log_info_tr "dns.log" "M_0172" "${target_engine}"

    if [[ "${target_engine}" == "adguardhome" ]]; then
        # shellcheck disable=SC1091
        source "${SECRETS_FILE}"
        printf '\n==============================================================================\n'
        printf_tr "M_0173"
        printf '==============================================================================\n'
        printf_tr "M_0174"
        printf_tr "M_0175"
        printf_tr "M_0176" "${AGH_ADMIN_USER:-см. secrets.env}"
        printf_tr "M_0177" "${SECRETS_FILE}"
        printf_tr "M_0178" "${SCRIPT_NAME}"
        printf '==============================================================================\n'
    else
        printf '\n==============================================================================\n'
        printf_tr "M_0179"
        printf '==============================================================================\n'
    fi
}

# ------------------------------ DoT Whitelist Management ----------------------
load_whitelist_sets() {
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"
    if [[ "${DOT_WHITELIST_MODE:-shared}" == "separate" ]]; then
        ACTIVE_DOT_SET_V4="dot_clients"
        ACTIVE_DOT_SET_V6="dot_clients6"
    else
        ACTIVE_DOT_SET_V4="smartdns_clients"
        ACTIVE_DOT_SET_V6="smartdns_clients6"
    fi
}

persist_ipset_state() {
    ipset save > "${IPSET_SAVE_FILE}.tmp" 2>/dev/null && mv -f "${IPSET_SAVE_FILE}.tmp" "${IPSET_SAVE_FILE}"
    chmod 0600 "${IPSET_SAVE_FILE}"
}

run_whitelist_status() {
    load_whitelist_sets
    local wl_banner="DISABLED"
    [[ "${DOT_WHITELIST_ENABLED:-false}" == "true" ]] && wl_banner="ENABLED"

    printf '==============================================================================\n'
    printf 'DoT IP-whitelist: %s\n' "${wl_banner}"
    printf 'DOT_WHITELIST_ENABLED : %s\n' "${DOT_WHITELIST_ENABLED:-false}"
    printf_tr "M_0181" "${DOT_WHITELIST_MODE:-shared}" "${ACTIVE_DOT_SET_V4}" "${ACTIVE_DOT_SET_V6}"
    printf_tr "M_0182"
    printf_tr "M_0183" "${IPSET_SAVE_FILE}"
    printf -- '------------------------------------------------------------------------------\n'
    printf_tr "M_0184" "${ACTIVE_DOT_SET_V4}"
    ipset list "${ACTIVE_DOT_SET_V4}" 2>/dev/null | awk '/^[0-9]/ {print "  - " $0}' || printf "$(tr_msg M_0185)"
    if [[ "${DOT_WHITELIST_MODE:-shared}" == "separate" ]]; then
        printf -- '------------------------------------------------------------------------------\n'
        printf_tr "M_0186"
        ipset list smartdns_clients 2>/dev/null | awk '/^[0-9]/ {print "  - " $0}' || printf "$(tr_msg M_0185)"
    fi
    printf -- '------------------------------------------------------------------------------\n'
    printf_tr "M_0187" "${ACTIVE_DOT_SET_V6}"
    ipset list "${ACTIVE_DOT_SET_V6}" 2>/dev/null | awk '/^[0-9a-fA-F:]/ && $0 ~ /:/ && $0 !~ /^Name|^Type|^Revision|^Header|^Size|^References|^Number|^Members/ {print "  - " $0}' || printf "$(tr_msg M_0185)"
    printf '==============================================================================\n'
}

run_whitelist_add() {
    local target_ip="${1:-}"
    if [[ -z "${target_ip}" ]]; then
        printf_err_tr "M_0188" "${SCRIPT_NAME}"
        exit 1
    fi
    if [[ "${target_ip}" == *"/"* ]]; then
        printf_err_tr "M_0189"
        exit 1
    fi
    load_whitelist_sets

    if validate_single_ipv4 "${target_ip}"; then
        ipset add "${ACTIVE_DOT_SET_V4}" "${target_ip}" timeout 86400 -exist
        ipset add smartdns_clients "${target_ip}" timeout 86400 -exist
        persist_ipset_state
        log_info_tr "firewall.log" "M_0190" "${target_ip}" "${ACTIVE_DOT_SET_V4}"
        printf_tr "M_0191" "${target_ip}" "${ACTIVE_DOT_SET_V4}"
    elif validate_single_ipv6 "${target_ip}"; then
        ipset add "${ACTIVE_DOT_SET_V6}" "${target_ip}" timeout 86400 -exist
        ipset add smartdns_clients6 "${target_ip}" timeout 86400 -exist
        persist_ipset_state
        log_info_tr "firewall.log" "M_0192" "${target_ip}" "${ACTIVE_DOT_SET_V6}"
        printf_tr "M_0193" "${target_ip}" "${ACTIVE_DOT_SET_V6}"
    else
        printf_err_tr "M_0194" "${target_ip}"
        exit 1
    fi
}

run_whitelist_remove() {
    local target_ip="${1:-}"
    if [[ -z "${target_ip}" ]]; then
        printf_err_tr "M_0195"
        exit 1
    fi
    load_whitelist_sets

    if validate_single_ipv4 "${target_ip}"; then
        ipset del "${ACTIVE_DOT_SET_V4}" "${target_ip}" -exist
        ipset del smartdns_clients "${target_ip}" -exist
        persist_ipset_state
        log_info_tr "firewall.log" "M_0196" "${target_ip}" "${ACTIVE_DOT_SET_V4}"
        printf_tr "M_0197" "${target_ip}" "${ACTIVE_DOT_SET_V4}"
    elif validate_single_ipv6 "${target_ip}"; then
        ipset del "${ACTIVE_DOT_SET_V6}" "${target_ip}" -exist
        ipset del smartdns_clients6 "${target_ip}" -exist
        persist_ipset_state
        log_info_tr "firewall.log" "M_0198" "${target_ip}" "${ACTIVE_DOT_SET_V6}"
        printf_tr "M_0199" "${target_ip}" "${ACTIVE_DOT_SET_V6}"
    else
        printf_err_tr "M_0194" "${target_ip}"
        exit 1
    fi
}

run_whitelist_flush() {
    load_whitelist_sets
    ipset flush "${ACTIVE_DOT_SET_V4}"
    ipset flush "${ACTIVE_DOT_SET_V6}"
    persist_ipset_state
    log_info_tr "firewall.log" "M_0200" "${ACTIVE_DOT_SET_V4}" "${ACTIVE_DOT_SET_V6}"
    printf_tr "M_0201" "${ACTIVE_DOT_SET_V4}" "${ACTIVE_DOT_SET_V6}"
}

run_whitelist_toggle() {
    local desired="${1:-toggle}"
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"

    local current_state="${DOT_WHITELIST_ENABLED:-false}"
    local new_state=""

    case "${desired,,}" in
        toggle|"")
            if [[ "${current_state}" == "true" ]]; then
                new_state="false"
            else
                new_state="true"
            fi
            ;;
        on|enable|enabled|true|1)
            new_state="true"
            ;;
        off|disable|disabled|false|0)
            new_state="false"
            ;;
        *)
            printf_err_tr "M_0202" "${desired}" "${SCRIPT_NAME}"
            exit 1
            ;;
    esac

    if grep -q '^DOT_WHITELIST_ENABLED=' "${SETTINGS_FILE}"; then
        sed -i "s|^DOT_WHITELIST_ENABLED=.*|DOT_WHITELIST_ENABLED=\"${new_state}\"|" "${SETTINGS_FILE}"
    else
        printf 'DOT_WHITELIST_ENABLED="%s"\n' "${new_state}" >> "${SETTINGS_FILE}"
    fi

    if [[ -f "${ROUTING_VARS_FILE}" ]]; then
        if grep -q '^DOT_WHITELIST_ENABLED=' "${ROUTING_VARS_FILE}"; then
            sed -i "s|^DOT_WHITELIST_ENABLED=.*|DOT_WHITELIST_ENABLED=\"${new_state}\"|" "${ROUTING_VARS_FILE}"
        else
            printf 'DOT_WHITELIST_ENABLED="%s"\n' "${new_state}" >> "${ROUTING_VARS_FILE}"
        fi
    fi

    /usr/local/bin/smartdns-firewall-apply.sh
    if [[ "${new_state}" == "true" ]]; then
        seed_initial_admin_ip
    fi

    log_info_tr "firewall.log" "M_0203" "${current_state}" "${new_state}" "${DOT_WHITELIST_MODE:-shared}"
    printf_tr "M_0204" "${current_state}" "${new_state}"
    run_whitelist_status
}

run_whitelist_mode() {
    local new_mode="${1:-}"
    if [[ "${new_mode}" != "shared" && "${new_mode}" != "separate" ]]; then
        printf_err_tr "M_0205" "${SCRIPT_NAME}"
        exit 1
    fi
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"

    local old_mode="${DOT_WHITELIST_MODE:-shared}"
    if grep -q '^DOT_WHITELIST_MODE=' "${SETTINGS_FILE}"; then
        sed -i "s|^DOT_WHITELIST_MODE=.*|DOT_WHITELIST_MODE=\"${new_mode}\"|" "${SETTINGS_FILE}"
    else
        printf 'DOT_WHITELIST_MODE="%s"\n' "${new_mode}" >> "${SETTINGS_FILE}"
    fi

    if [[ -f "${ROUTING_VARS_FILE}" ]]; then
        if grep -q '^DOT_WHITELIST_MODE=' "${ROUTING_VARS_FILE}"; then
            sed -i "s|^DOT_WHITELIST_MODE=.*|DOT_WHITELIST_MODE=\"${new_mode}\"|" "${ROUTING_VARS_FILE}"
        else
            printf 'DOT_WHITELIST_MODE="%s"\n' "${new_mode}" >> "${ROUTING_VARS_FILE}"
        fi
    fi

    /usr/local/bin/smartdns-firewall-apply.sh
    if [[ "${DOT_WHITELIST_ENABLED:-false}" == "true" ]]; then
        seed_initial_admin_ip
    fi

    log_info_tr "firewall.log" "M_0206" "${old_mode}" "${new_mode}"
    printf_tr "M_0207" "${old_mode}" "${new_mode}"
    run_whitelist_status
}

# ------------------------------ IP Synchronization (--sync-ip) ----------------
run_sync_ip() {
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi

    local old_ipv4 old_ipv6
    old_ipv4="$(awk -F'"' '/^SERVER_IPV4=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || true)"
    old_ipv6="$(awk -F'"' '/^SERVER_IPV6=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || true)"

    detect_environment
    if [[ -z "${SERVER_IPV4}" ]]; then
        log_error_tr "update.log" "M_0208"
        exit 1
    fi

    local new_ipv4="${SERVER_IPV4}"
    local new_ipv6="${SERVER_IPV6:-}"

    load_settings_safely "${SETTINGS_FILE}" || exit 1
    if is_hostname_profile; then
        restore_hostname_profile
        new_ipv4="${PUBLIC_IPV4}"
        new_ipv6="${PUBLIC_IPV6:-}"
        HAS_IPV6=0
        [[ -n "${new_ipv6}" ]] && HAS_IPV6=1
    fi
    SERVER_IPV4="${new_ipv4}"
    SERVER_IPV6="${new_ipv6}"

    log_info_tr "update.log" "M_0209" "${old_ipv4:-нет}" "${new_ipv4}" "${new_ipv6:-нет}"

    create_system_backup
    TRANSACTION_ACTIVE=1

    sed -i "s|^SERVER_IPV4=.*|SERVER_IPV4=\"${new_ipv4}\"|" "${SETTINGS_FILE}" "${ROUTING_VARS_FILE}"
    sed -i "s|^SERVER_IPV6=.*|SERVER_IPV6=\"${new_ipv6}\"|" "${SETTINGS_FILE}"
    sed -i "s|^HAS_IPV6=.*|HAS_IPV6=\"${HAS_IPV6}\"|" "${SETTINGS_FILE}"
    sed -i "s|^PRIMARY_IFACE=.*|PRIMARY_IFACE=\"${PRIMARY_IFACE}\"|" "${SETTINGS_FILE}"

    if is_hostname_profile; then
        save_persistent_settings
        verify_provider_hostname_dns "${new_ipv4}" "${new_ipv6}"
    else
        if ! sync_cloudflare_dns_records "${new_ipv4}" "${new_ipv6}"; then
            log_warn_tr "update.log" "M_0210"
        fi
    fi

    /usr/local/bin/update-geohide-domains.sh
    /usr/local/bin/smartdns-firewall-apply.sh

    systemctl restart "${DNS_ENGINE}" xray
    nginx -t && systemctl reload nginx

    run_test_suite
    TRANSACTION_ACTIVE=0
    log_info_tr "update.log" "M_0211" "${new_ipv4}"
}

# ------------------------------ Fast Domain Change (--change-domain) ----------
run_change_domain() {
    if [[ ! -f "${SETTINGS_FILE}" || ! -f "${SECRETS_FILE}" ]]; then
        printf_err_tr "M_0212"
        exit 1
    fi

    detect_environment
    load_settings_safely "${SETTINGS_FILE}" || exit 1
    if is_hostname_profile; then
        printf_err_tr "HN_20"
        return 1
    fi
    # shellcheck disable=SC1091
    source "${SECRETS_FILE}"

    local old_root_domain="${ROOT_DOMAIN}"
    local old_dot_host="${DOT_HOST}"

    local dot_prefix="${old_dot_host%.${old_root_domain}}"
    if [[ -z "${dot_prefix}" || "${dot_prefix}" == "${old_dot_host}" ]]; then
        dot_prefix="${old_dot_host%%.*}"
    fi

    printf '\n==============================================================================\n'
    printf_tr "M_0213"
    printf '==============================================================================\n'
    printf_tr "M_0214" "${old_root_domain}"
    printf_tr "M_0215" "${old_dot_host}" "${dot_prefix}"
    printf_tr "M_0216" "${#DOH_PATH}"

    local new_root_domain="${1:-}"
    if [[ -n "${new_root_domain}" ]]; then
        new_root_domain="${new_root_domain,,}"
        if ! validate_domain_syntax "${new_root_domain}"; then
            printf_err_tr "M_0217" "${new_root_domain}"
            exit 1
        fi
    else
        while true; do
            read_tr "M_0218" new_root_domain
            new_root_domain="${new_root_domain,,}"
            if validate_domain_syntax "${new_root_domain}"; then
                break
            fi
            printf_tr "M_0044"
        done
    fi

    local new_dot_host="${dot_prefix}.${new_root_domain}"

    if [[ -t 0 ]]; then
        read -r -s -p "Введите Cloudflare API Token для зоны ${new_root_domain} (Enter — использовать текущий токен): " input_cf_token
        printf '\n'
        if [[ -n "${input_cf_token}" ]]; then
            CF_API_TOKEN="${input_cf_token}"
        fi
    fi

    if [[ -z "${CF_API_TOKEN:-}" || "${CF_API_TOKEN}" == "REUSE_EXISTING_CERT_TOKEN" ]]; then
        printf_err_tr "M_0219"
        exit 1
    fi

    printf_tr "M_0220"
    printf_tr "M_0221" "${new_root_domain}"
    printf_tr "M_0222" "${new_dot_host}" "${dot_prefix}"
    printf_tr "M_0223"
    if [[ -t 0 ]]; then
        read_tr "M_0224" confirm_dom
        if [[ ! "${confirm_dom:-N}" =~ ^[Yy]$ ]]; then
            printf_tr "M_0225"
            exit 0
        fi
    fi

    create_system_backup
    TRANSACTION_ACTIVE=1

    ROOT_DOMAIN="${new_root_domain}"
    DOH_HOST="${new_root_domain}"
    DOT_HOST="${new_dot_host}"
    ACME_EMAIL="admin@${new_root_domain}"

    save_persistent_settings

    log_info_tr "update.log" "M_0226" "${ROOT_DOMAIN}"
    sync_cloudflare_dns_records "${SERVER_IPV4}" "${SERVER_IPV6:-}" || true

    log_info_tr "certificate.log" "M_0227" "${ROOT_DOMAIN}"
    issue_wildcard_certificate

    sync_cover_site_domain_metadata
    configure_nginx

    if [[ "${DNS_ENGINE}" == "adguardhome" && -f /etc/adguardhome/AdGuardHome.yaml ]]; then
        sed -i "s|^  server_name:.*|  server_name: \"${ROOT_DOMAIN}\"|" /etc/adguardhome/AdGuardHome.yaml
    fi

    /usr/local/bin/update-geohide-domains.sh

    systemctl restart "${DNS_ENGINE}" xray
    nginx -t && systemctl reload nginx

    run_test_suite
    TRANSACTION_ACTIVE=0

    log_info_tr "update.log" "M_0228" "${old_root_domain}" "${ROOT_DOMAIN}" "${DOT_HOST}"
    printf '\n==============================================================================\n'
    printf_tr "M_0229"
    printf '==============================================================================\n'
    printf_tr "M_0230" "${ROOT_DOMAIN}" "${DOH_PATH}"
    printf_tr "M_0231" "${ROOT_DOMAIN}" "${DOH_PATH}"
    printf_tr "M_0232" "${DOT_HOST}"
    printf '==============================================================================\n'
}

# ------------------------------ Comprehensive Test Suite ----------------------
run_test_suite() {
    detect_environment
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"
    # shellcheck disable=SC1091
    source "${SECRETS_FILE}"
    load_whitelist_sets

    local failures=0
    printf '==============================================================================\n'
    printf_tr "M_0233"
    printf_tr "M_0234" "${DNS_ENGINE}"
    printf '==============================================================================\n'

    check_step() {
        local name="$1"
        local result="$2"
        if [[ "${result}" == "PASS" ]]; then
            printf '[ PASS ] %s\n' "${name}"
        else
            printf '[ FAIL ] %s\n' "${name}"
            failures=$((failures + 1))
        fi
    }

    # 1. Service status & non-root execution
    for svc in "${DNS_ENGINE}" xray nginx doh-ipset-watcher dot-ipset-watcher; do
        if systemctl is-active --quiet "${svc}"; then
            check_step "$(tr_msg "M_0235" "${svc}")" "PASS"
        else
            check_step "$(tr_msg "M_0235" "${svc}")" "FAIL"
        fi
    done

    local xray_proc_user
    xray_proc_user="$(ps -o user= -C xray | sed -n '1p' | tr -d ' ')"
    check_step "$(tr_msg "M_0236" "${xray_proc_user}")" "$( [[ "${xray_proc_user}" == "xray" ]] && echo PASS || echo FAIL )"

    # 2. Certificate cryptographic verification & auto-renewal check
    if is_hostname_profile; then
        restore_hostname_profile
        if /usr/local/bin/verify-hostname-tls-keys.sh "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${ROOT_DOMAIN}" >/dev/null 2>&1; then
            check_step "$(tr_msg "M_0237")" "PASS"
        else
            check_step "$(tr_msg "M_0237")" "FAIL"
        fi

        local hn_renew_ok=1
        if [[ ! -x /usr/local/bin/smartdns-hostname-cert-deploy.sh || ! -x /etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh ]]; then
            hn_renew_ok=0
        fi
        if ! grep -Fq 'location ^~ /.well-known/acme-challenge/' /etc/nginx/nginx.conf 2>/dev/null; then
            hn_renew_ok=0
        fi
        if [[ ! -f "${HOSTNAME_RENEWAL_CONF:-/nonexistent}" ]]; then
            hn_renew_ok=0
        fi
        check_step "$(tr_msg "HN_TEST_RENEW")" "$( [[ "${hn_renew_ok}" -eq 1 ]] && echo PASS || echo FAIL )"
    else
        if /usr/local/bin/verify-tls-keys.sh "${CERT_DIR}/fullchain.pem" "${CERT_DIR}/privkey.pem" "${ROOT_DOMAIN}" >/dev/null 2>&1; then
            check_step "$(tr_msg "M_0237")" "PASS"
        else
            check_step "$(tr_msg "M_0237")" "FAIL"
        fi

        local cert_renew_ok=1
        if ! systemctl is-active --quiet smartdns-cert-renew.timer || ! systemctl is-enabled --quiet smartdns-cert-renew.timer; then
            cert_renew_ok=0
        fi
        if [[ ! -x /usr/local/bin/smartdns-cert-renew.sh || ! -x /usr/local/bin/smartdns-cert-deploy.sh ]]; then
            cert_renew_ok=0
        fi
        local acme_dom_conf="/root/.acme.sh/${ROOT_DOMAIN}_ecc/${ROOT_DOMAIN}.conf"
        if [[ -f "${acme_dom_conf}" ]]; then
            if grep -q "Le_RealFullChainPath='/tmp/" "${acme_dom_conf}" 2>/dev/null || grep -q "^Le_ReloadCmd=''" "${acme_dom_conf}" 2>/dev/null; then
                cert_renew_ok=0
            fi
        fi
        check_step "$(tr_msg "M_0372")" "$( [[ "${cert_renew_ok}" -eq 1 ]] && echo PASS || echo FAIL )"
    fi

    # 3. Ordinary DNS resolution via internal listener
    local normal_a
    normal_a="$(dig +time=3 +tries=2 +short @127.0.0.1 -p 5353 example.com A || true)"
    normal_a="$(printf '%s\n' "${normal_a}" | sed -n '1p')"
    check_step "$(tr_msg "M_0238" "${normal_a}")" "$( validate_single_ipv4 "${normal_a}" && [[ "${normal_a}" != "${SERVER_IPV4}" ]] && echo PASS || echo FAIL )"

    # 4-5. SmartDNS A spoofing, AAAA NODATA & HTTPS TYPE65 (динамический домен)
    local suite_test_dom
    suite_test_dom="$(get_test_proxied_domain)"
    if [[ -z "${suite_test_dom}" ]]; then
        check_step "$(tr_msg "M_0367" "${SELECTED_DOMAIN_GROUPS:-NONE}")" "PASS"
    else
        local spoof_a
        spoof_a="$(dig +time=3 +tries=2 +short @127.0.0.1 -p 5353 "${suite_test_dom}" A || true)"
        spoof_a="$(printf '%s\n' "${spoof_a}" | sed -n '1p')"
        check_step "$(tr_msg "M_0239" "${SERVER_IPV4}")" "$( [[ "${spoof_a}" == "${SERVER_IPV4}" ]] && echo PASS || echo FAIL )"

        local aaaa_out
        aaaa_out="$(dig +time=3 +tries=2 @127.0.0.1 -p 5353 "${suite_test_dom}" AAAA || true)"
        if grep -q "status: NOERROR" <<<"${aaaa_out}" && grep -q "ANSWER: 0" <<<"${aaaa_out}"; then
            check_step "$(tr_msg "M_0240")" "PASS"
        else
            check_step "$(tr_msg "M_0240")" "FAIL"
        fi

        local https_out
        https_out="$(dig +time=3 +tries=2 @127.0.0.1 -p 5353 "${suite_test_dom}" TYPE65 || true)"
        if grep -Eq "status: (NOERROR|REFUSED)" <<<"${https_out}" && grep -q "ANSWER: 0" <<<"${https_out}"; then
            check_step "$(tr_msg "M_0241")" "PASS"
        else
            check_step "$(tr_msg "M_0241")" "FAIL"
        fi
    fi

    # 6. Negative Test: Wrong DoH path on ROOT_DOMAIN returns disguised 404
    local wrong_doh_code
    wrong_doh_code="$(curl -sk -o /dev/null -w '%{http_code}' --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" "https://${ROOT_DOMAIN}:9443/resolve/wrongpath12345" || echo 000)"
    check_step "$(tr_msg "M_0242" "${ROOT_DOMAIN}" "${wrong_doh_code}")" "$( [[ "${wrong_doh_code}" == "404" ]] && echo PASS || echo FAIL )"

    # 7. Valid DoH RFC 8484 query on ROOT_DOMAIN
    local valid_doh_ctype
    valid_doh_ctype="$(curl -sk -o /dev/null -w '%{content_type}' --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" \
        "https://${ROOT_DOMAIN}:9443/resolve/${DOH_PATH}?dns=AAABAAABAAAAAAAAB2V4YW1wbGUDY29tAAABAAE" || true)"
    check_step "$(tr_msg "M_0243" "${ROOT_DOMAIN}")" "$( [[ "${valid_doh_ctype}" == "application/dns-message" ]] && echo PASS || echo FAIL )"

    # 8. Web-Auth bookmark endpoint check
    local web_auth_check
    web_auth_check="$(curl -sk --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" "https://${ROOT_DOMAIN}:9443/auth/${DOH_PATH}" || true)"
    check_step "$(tr_msg "M_0244")" "$( grep -q "Session Synchronized" <<<"${web_auth_check}" && echo PASS || echo FAIL )"

    # 9. DoT IPv4/IPv6 Whitelist, TTL Expiration, Re-auth, and Wrong SNI Checks
    if [[ "${DOT_WHITELIST_ENABLED:-false}" == "true" ]]; then
        ipset del "${ACTIVE_DOT_SET_V4}" 127.0.0.2 -exist
        if ! timeout 2 openssl s_client -connect 127.0.0.2:853 -servername "${DOT_HOST}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0245")" "PASS"
        else
            check_step "$(tr_msg "M_0245")" "FAIL"
        fi

        ipset add "${ACTIVE_DOT_SET_V4}" 127.0.0.1 timeout 86400 -exist
        if timeout 4 openssl s_client -connect 127.0.0.1:853 -servername "${DOT_HOST}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0246")" "PASS"
        else
            check_step "$(tr_msg "M_0246")" "FAIL"
        fi

        if ! timeout 3 openssl s_client -connect 127.0.0.1:853 -servername "invalid.sni.${ROOT_DOMAIN}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0247")" "PASS"
        else
            check_step "$(tr_msg "M_0247")" "FAIL"
        fi

        ipset del "${ACTIVE_DOT_SET_V6}" ::1 -exist
        if ! timeout 2 openssl s_client -6 -connect "[::1]:853" -servername "${DOT_HOST}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0248")" "PASS"
        else
            check_step "$(tr_msg "M_0248")" "FAIL"
        fi

        ipset add "${ACTIVE_DOT_SET_V6}" ::1 timeout 86400 -exist
        if ipset test "${ACTIVE_DOT_SET_V6}" ::1 >/dev/null 2>&1 && ip6tables -t filter -C SMARTDNS6_INPUT -p tcp --dport 853 -m set --match-set "${ACTIVE_DOT_SET_V6}" src -m hashlimit --hashlimit-name dot_v6_rate --hashlimit-mode srcip --hashlimit-upto 30/min --hashlimit-burst 40 -j ACCEPT 2>/dev/null; then
            check_step "$(tr_msg "M_0249")" "PASS"
        else
            check_step "$(tr_msg "M_0249")" "FAIL"
        fi
        ipset del "${ACTIVE_DOT_SET_V6}" ::1 -exist

        ipset add "${ACTIVE_DOT_SET_V4}" 198.51.100.250 timeout 2 -exist
        sleep 3
        if ! ipset test "${ACTIVE_DOT_SET_V4}" 198.51.100.250 >/dev/null 2>&1; then
            check_step "$(tr_msg "M_0250")" "PASS"
        else
            check_step "$(tr_msg "M_0250")" "FAIL"
        fi

        ipset add "${ACTIVE_DOT_SET_V4}" 198.51.100.250 timeout 100 -exist
        ipset add "${ACTIVE_DOT_SET_V4}" 198.51.100.250 timeout 86400 -exist
        local refreshed_ttl
        refreshed_ttl="$(ipset list "${ACTIVE_DOT_SET_V4}" | awk '$1 == "198.51.100.250" {print $3}')"
        ipset del "${ACTIVE_DOT_SET_V4}" 198.51.100.250 -exist
        ipset del "${ACTIVE_DOT_SET_V4}" 127.0.0.1 -exist
        check_step "$(tr_msg "M_0251" "${refreshed_ttl:-0}")" "$( [[ "${refreshed_ttl:-0}" -gt 86000 ]] && echo PASS || echo FAIL )"
    else
        ipset del "${ACTIVE_DOT_SET_V4}" 127.0.0.1 -exist
        if ! timeout 3 openssl s_client -connect 127.0.0.1:853 -servername "invalid.sni.${ROOT_DOMAIN}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0252")" "PASS"
        else
            check_step "$(tr_msg "M_0252")" "FAIL"
        fi

        if timeout 5 openssl s_client -connect 127.0.0.1:853 -servername "${DOT_HOST}" </dev/null 2>/dev/null | grep -q "BEGIN CERTIFICATE"; then
            check_step "$(tr_msg "M_0253")" "PASS"
        else
            check_step "$(tr_msg "M_0253")" "FAIL"
        fi
    fi

    # 10. Persistence & Internal Ports Protection Check
    if systemctl is-enabled --quiet smartdns-firewall.service && [[ -f "${IPSET_SAVE_FILE}" ]] && iptables -t filter -C SMARTDNS_INPUT -p tcp -m multiport --dports 8443,9444,8853,5353,8053,3000 -j DROP 2>/dev/null; then
        check_step "$(tr_msg "M_0254")" "PASS"
    else
        check_step "$(tr_msg "M_0254")" "FAIL"
    fi

    # 11. Procedural Cover Site availability & structural integrity check
    local site_html site_code css_code
    site_code="$(curl -sk -o /dev/null -w '%{http_code}' --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" "https://${ROOT_DOMAIN}:9443/" || echo 000)"
    site_html="$(curl -sk --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" "https://${ROOT_DOMAIN}:9443/" || true)"
    css_code="$(curl -sk -o /dev/null -w '%{http_code}' --resolve "${ROOT_DOMAIN}:9443:127.0.0.1" "https://${ROOT_DOMAIN}:9443/assets/style.css" || echo 000)"
    if [[ "${site_code}" == "200" && "${css_code}" == "200" ]] && grep -Fq "<!DOCTYPE html>" <<<"${site_html}" && grep -Fq "<main>" <<<"${site_html}" && grep -Fq "<footer" <<<"${site_html}"; then
        check_step "$(tr_msg "M_0255")" "PASS"
    else
        check_step "$(tr_msg "M_0255")" "FAIL"
    fi

    # 12. Negative Test: Damaged JSON rejected by xray-safe-reload
    local tmp_bad="/tmp/bad-routing.json"
    printf '{ "routing": INVALID_JSON }' > "${tmp_bad}"
    if ! /usr/local/bin/xray run -test -config "${XRAY_CONF_DIR}/00-base.json" -config "${tmp_bad}" >/dev/null 2>&1; then
        check_step "$(tr_msg "M_0256")" "PASS"
    else
        check_step "$(tr_msg "M_0256")" "FAIL"
    fi
    rm -f "${tmp_bad}"

    # 13. Firewall & ipset status check
    if ipset list smartdns_clients >/dev/null 2>&1 && iptables -t nat -C PREROUTING -j SMARTDNS_PREROUTING 2>/dev/null; then
        check_step "$(tr_msg "M_0257")" "PASS"
    else
        check_step "$(tr_msg "M_0257")" "FAIL"
    fi

    printf '==============================================================================\n'
    if [[ "${failures}" -eq 0 ]]; then
        printf_tr "M_0258"
        return 0
    else
        printf_tr "M_0259" "${failures}" "${LOG_DIR}"
        return 1
    fi
}

# ------------------------------ Installation Report ---------------------------
generate_installation_report() {
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"
    # shellcheck disable=SC1091
    source "${VERSIONS_FILE}"
    # shellcheck disable=SC1091
    source "${SECRETS_FILE}"
    # shellcheck disable=SC1091
    [[ -f "${STATE_DIR}/geohide-stats.env" ]] && source "${STATE_DIR}/geohide-stats.env"
    load_whitelist_sets

    local report_file="${LAUNCH_DIR}/smartdns-installation-report-${TIMESTAMP}.txt"
    local secret_report_file="${STATE_DIR}/credentials-${TIMESTAMP}.txt"
    local auth_ip_count
    auth_ip_count="$(ipset list smartdns_clients 2>/dev/null | awk '/Number of entries:/ {print $4}' || echo 0)"
    local dot_ip4_count
    dot_ip4_count="$(ipset list "${ACTIVE_DOT_SET_V4}" 2>/dev/null | awk '/Number of entries:/ {print $4}' || echo 0)"
    local dot_ip6_count
    dot_ip6_count="$(ipset list "${ACTIVE_DOT_SET_V6}" 2>/dev/null | awk '/Number of entries:/ {print $4}' || echo 0)"
    local dot_wl_banner="DISABLED"
    [[ "${DOT_WHITELIST_ENABLED:-false}" == "true" ]] && dot_wl_banner="ENABLED"

    cat > "${report_file}" <<EOF
================================================================================
     ИТОГОВЫЙ ОТЧЁТ УСТАНОВКИ UNIFIED SMARTDNS + SNI PROXY (STEALTH MODE)
================================================================================
1. ОБЩАЯ ИНФОРМАЦИЯ
   Дата установки            : ${INSTALL_DATE}
   Версия установщика        : ${INSTALLER_VERSION}
   Операционная система      : ${OS_PRETTY} (${CPU_ARCH}, ядро ${KERNEL_VER})
   Публичный IPv4            : ${SERVER_IPV4}
   Публичный IPv6            : ${SERVER_IPV6:-отсутствует}
   Выбранный DNS-движок      : ${DNS_ENGINE}
   Версия DNS-движка         : ${DNS_VERSION}
   Версия Xray-core          : ${XRAY_VERSION}
   Версия Nginx              : ${NGINX_VERSION}

2. ИСТОЧНИКИ И СОСТОЯНИЕ СПИСКОВ (OxiDNS & GeoHideDNS)
   OxiDNS repository         : ${OXIDNS_REPO}
   OxiDNS release            : ${DNS_VERSION}
   OxiDNS binary             : /usr/local/bin/oxidns
   GeoHideDNS repository     : ${GEOHIDE_REPO}
   GeoHideDNS source         : ${GEOHIDE_RAW_URL}
   Последнее обновление      : ${LAST_UPDATE:-неизвестно}
   Количество исходных домен.: ${RAW_DOMAIN_COUNT:-0}
   Количество итоговых домен.: ${FINAL_DOMAIN_COUNT:-0}
   Выбранные группы доменов  : ${SELECTED_DOMAIN_GROUPS:-ALL}
   EXCLUDE_GOOGLE_SYS        : ${EXCLUDE_GOOGLE_SYS}
   INCLUDE_XBOX_IPIFY        : ${INCLUDE_XBOX_IPIFY}
   Xray rules                : ${XRAY_RULES_STATUS:-VERIFIED_OK}

3. DNS, МАСКИРОВКА И ФИЛЬТРАЦИЯ
   Единый домен (Сайт + DoH) : https://${ROOT_DOMAIN}/resolve/[СКРЫТО_В_ФАЙЛЕ_СЕКРЕТОВ]
   Веб-авторизация Wi-Fi     : https://${ROOT_DOMAIN}/auth/[СКРЫТО_В_ФАЙЛЕ_СЕКРЕТОВ]
   DoT Hostname              : ${DOT_HOST} (порт 853/TCP)
   DNS Upstream              : Cloudflare (1.1.1.1), Google (8.8.8.8) по HTTPS
   Расписание обновлений     : 04:00 MSK (geosite.dat), 04:05 MSK (GeoHideDNS)

4. КОНТРОЛЬ ДОСТУПА DoT (TCP 853 WHITELIST)
   DoT IP-whitelist: ${dot_wl_banner}
   DOT_WHITELIST_ENABLED     : ${DOT_WHITELIST_ENABLED:-false}
   Режим whitelist           : ${DOT_WHITELIST_MODE:-shared} (${ACTIVE_DOT_SET_V4} / ${ACTIVE_DOT_SET_V6})
   Количество разрешённых IP : IPv4=${dot_ip4_count}, IPv6=${dot_ip6_count}
   TTL записей               : 86400 секунд
   Состояние firewall        : $(systemctl is-active smartdns-firewall) (${IPTABLES_BACKEND})
   Команды управления        :
     - ${SCRIPT_NAME} --switch-engine [oxidns|adguardhome]
     - ${SCRIPT_NAME} --whitelist-status
     - ${SCRIPT_NAME} --whitelist-toggle [on|off]
     - ${SCRIPT_NAME} --whitelist-mode [shared|separate]
     - ${SCRIPT_NAME} --whitelist-add IP
     - ${SCRIPT_NAME} --whitelist-remove IP
     - ${SCRIPT_NAME} --whitelist-flush
     - ${SCRIPT_NAME} --sync-ip
     - ${SCRIPT_NAME} --change-domain [NEW_DOMAIN]
     - ${SCRIPT_NAME} --domain-groups

5. XRAY TRANSPARENT SNI PROXY
   Статус службы             : $(systemctl is-active xray)
   Входящие (Inbounds)       : https-in (0.0.0.0:8444 dokodemo-door), dot-in (0.0.0.0:853)
   Исходящие (Outbounds)     : direct-v4 (UseIPv4), nginx-local (127.0.0.1:9444 PROXY protocol), dot-backend (127.0.0.1:8853), block
   Проксируемых доменов      : ${FINAL_DOMAIN_COUNT:-0}
   Автоперезагрузка правил   : $(systemctl is-active xray-reload.path)

6. NGINX И САЙТ-ЗАГЛУШКА STUDIO NORD
   Статус службы             : $(systemctl is-active nginx)
   Домен сайта Studio Nord   : https://${ROOT_DOMAIN}
   Внутренние TLS-порты      : 9443/TCP (DNAT), 127.0.0.1:9444/TCP (PROXY protocol от Xray)
   Сертификат TLS            : ${CERT_DIR}/fullchain.pem (SAN: $( is_hostname_profile && printf '%s (existing Certbot)' "${ROOT_DOMAIN}" || printf '%s, *.%s' "${ROOT_DOMAIN}" "${ROOT_DOMAIN}" ))
   Автопродление TLS         : $( is_hostname_profile && printf 'certbot.timer (%s) + /etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh' "$(systemctl is-active certbot.timer 2>/dev/null || echo inactive)" || printf 'smartdns-cert-renew.timer (%s, 03:30 MSK)' "$(systemctl is-active smartdns-cert-renew.timer 2>/dev/null || echo inactive)" )

7. FIREWALL И IPSET
   Используемый backend      : ${IPTABLES_BACKEND} + UFW
   Публичные порты           : 80/TCP, 443/TCP, 853/TCP
   Закрытые внутренние порты : 8444, 9444, 8853, 5353, 8053, 3000
   Набор ipset               : smartdns_clients (TTL 86400s), авторизовано IP: ${auth_ip_count}
   Состояние защиты IPv6     : Активна (ip6tables + smartdns_clients6 + DNS NODATA для AAAA)
================================================================================
EOF
    chmod 0640 "${report_file}"

    cat > "${secret_report_file}" <<EOF
================================================================================
 СЕКРЕТНЫЕ ДАННЫЕ ПОДКЛЮЧЕНИЯ (ХРАНИТЬ В БЕЗОПАСНОМ МЕСТЕ, ПРАВА 0600)
================================================================================
Полный DoH URL (используется корневой домен без поддоменов):
  https://${ROOT_DOMAIN}/resolve/${DOH_PATH}

Секретная ссылка-закладка для быстрой авторизации нового Wi-Fi с телефона:
  https://${ROOT_DOMAIN}/auth/${DOH_PATH}

Хост DoT (для Android Private DNS / роутеров, порт 853/TCP):
  ${DOT_HOST}
EOF
    if [[ "${DNS_ENGINE}" == "adguardhome" ]]; then
        cat >> "${secret_report_file}" <<EOF

Учётные данные панели AdGuardHome (доступ только через SSH-туннель 127.0.0.1:8053):
  Логин             : ${AGH_ADMIN_USER:-admin}
  Временный пароль  : ${AGH_ADMIN_PASS:-см. мастер}
EOF
    fi
    chmod 0600 "${secret_report_file}"

    cat "${report_file}"
    printf_tr "M_0260" "${report_file}"
    printf_tr "M_0261" "${secret_report_file}"

    read_tr "M_0262" show_sec
    if [[ "${show_sec:-N}" =~ ^[Yy]$ ]]; then
        cat "${secret_report_file}"
    fi
    print_initial_setup_report_summary
}

run_regenerate_cover() {
    detect_environment
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0180" "${SETTINGS_FILE}"
        exit 1
    fi
    # shellcheck disable=SC1091
    source "${SETTINGS_FILE}"

    create_system_backup
    TRANSACTION_ACTIVE=1
    generate_procedural_cover_site "${WEB_ROOT}" "1"
    nginx -t && systemctl reload nginx
    run_test_suite
    TRANSACTION_ACTIVE=0
    log_info_tr "installation.log" "M_0263"
}

run_manage_domain_groups() {
    detect_environment
    if [[ ! -f "${SETTINGS_FILE}" || ! -f "${SECRETS_FILE}" ]]; then
        printf_err_tr "M_0212"
        exit 1
    fi
    # shellcheck disable=SC1090
    source "${SETTINGS_FILE}"
    # shellcheck disable=SC1090
    source "${SECRETS_FILE}"

    local current_groups="${SELECTED_DOMAIN_GROUPS:-ALL}"
    local current_custom_cnt=0
    if [[ -s "${CUSTOM_ALLOW_FILE}" ]]; then
        current_custom_cnt="$(wc -l < "${CUSTOM_ALLOW_FILE}" | tr -d ' ')"
    fi

    printf_tr "M_0362" "${current_groups}"
    printf_tr "M_0363" "${current_custom_cnt}"

    if ! prompt_domain_groups_selection "${current_groups}"; then
        return 0
    fi
    prompt_custom_domains_import
    cleanup_domain_index_tmp

    local confirm_apply=""
    read_tr "M_0364" confirm_apply "${SELECTED_DOMAIN_GROUPS}"
    if [[ ! "${confirm_apply:-N}" =~ ^[Yy]$ ]]; then
        rm -f "${PENDING_CUSTOM_DOMAINS_FILE:-}" 2>/dev/null || true
        printf_tr "M_0225"
        return 0
    fi

    create_system_backup
    TRANSACTION_ACTIVE=1

    apply_pending_custom_domains
    save_persistent_settings
    install_domain_update_scripts
    /usr/local/bin/update-geohide-domains.sh

    systemctl restart "${DNS_ENGINE}" xray
    wait_for_dns_backend_ready "${DNS_ENGINE}" || true
    verify_dns_backend_isolated
    record_full_install_manifest

    TRANSACTION_ACTIVE=0
    log_info_tr "dns.log" "M_0365" "${SELECTED_DOMAIN_GROUPS}"
}

# ------------------------------ Status / Update / Uninstall -------------------
run_status() {
    detect_environment
    printf_tr "M_0264"
    local status_timers="smartdns-cert-renew.timer"
    if [[ -f "${SETTINGS_FILE}" ]]; then
        load_settings_safely "${SETTINGS_FILE}" || true
        printf '  %-26s : %s\n' "$(tr_msg M_0265)" "${DNS_ENGINE:-unknown}"
        printf '  %-26s : %s\n' "INSTALL_PROFILE" "${INSTALL_PROFILE:-cloudflare}"
        if is_hostname_profile; then
            status_timers="certbot.timer"
        fi
    fi
    for svc in smartdns-firewall oxidns adguardhome xray xray-reload.path nginx doh-ipset-watcher dot-ipset-watcher geosite-update.timer geohide-update.timer ${status_timers}; do
        if systemctl list-unit-files "${svc}*" >/dev/null 2>&1; then
            printf '  %-26s : %s\n' "${svc}" "$(systemctl is-active "${svc}" 2>/dev/null || echo inactive)"
        fi
    done
    if [[ -f "${SETTINGS_FILE}" ]]; then
        printf '\n'
        run_whitelist_status
    fi
}

run_update() {
    detect_environment
    if [[ ! -f "${SETTINGS_FILE}" ]]; then
        printf_err_tr "M_0266"
        exit 1
    fi
    load_settings_safely "${SETTINGS_FILE}" || exit 1
    if is_hostname_profile; then
        restore_hostname_profile
    fi
    DOH_HOST="${ROOT_DOMAIN}"
    sed -i "s/^DOH_HOST=.*/DOH_HOST=\"${ROOT_DOMAIN}\"/" "${SETTINGS_FILE}"
    # shellcheck disable=SC1091
    source "${SECRETS_FILE}"

    create_system_backup
    TRANSACTION_ACTIVE=1
    setup_users_and_dirs
    install_xray_binary
    if [[ "${DNS_ENGINE}" == "oxidns" ]]; then
        install_oxidns_binary
    else
        install_adguardhome_binary
    fi
    if is_hostname_profile; then
        verify_provider_hostname_dns "${SERVER_IPV4}" "${SERVER_IPV6:-}"
        deploy_existing_hostname_certificate
    else
        sync_cloudflare_dns_records "${SERVER_IPV4}" "${SERVER_IPV6:-}" || true
        configure_cert_auto_renewal
    fi
    install_domain_update_scripts
    configure_xray_base
    log_info_tr "update.log" "M_0374"
    /usr/local/bin/update-geosite.sh
    log_info_tr "update.log" "M_0375"
    /usr/local/bin/update-geohide-domains.sh
    configure_dns_engine
    generate_procedural_cover_site "${WEB_ROOT}" "0"
    configure_nginx
    install_ipset_watchers
    configure_firewall_and_sysctl
    record_installed_versions
    systemctl restart "${DNS_ENGINE}" xray nginx doh-ipset-watcher dot-ipset-watcher
    wait_for_dns_backend_ready "${DNS_ENGINE}" || true
    verify_dns_backend_isolated
    run_test_suite
    record_full_install_manifest
    TRANSACTION_ACTIVE=0
    log_info_tr "update.log" "M_0267"
}

# ------------------------------ Safe Selective Uninstall ----------------------
UNINSTALL_LEGACY_MODE=0
UNINSTALL_BACKUP_OK=0
UNINSTALL_REMOVE_USER_DATA=0
UNINSTALL_REMOVE_ACME=0
UNINSTALL_REMOVE_PACKAGES=0
declare -a UNINSTALL_DETECTED_COMPS=()
declare -a UNINSTALL_CANDIDATE_PKGS=()
declare -A UNINSTALL_COMP_SELECTED=()

uninstall_comp_label() {
    local cid="$1"
    if [[ "${SCRIPT_LANG:-ru}" == "en" ]]; then
        case "${cid}" in
            nginx)          printf '%s' "Nginx (SmartDNS config, hardening drop-in & repo)" ;;
            xray)           printf '%s' "Xray-core (transparent SNI proxy & reload path)" ;;
            oxidns)         printf '%s' "OxiDNS (Rust SmartDNS backend)" ;;
            adguardhome)    printf '%s' "AdGuardHome (Go SmartDNS backend)" ;;
            ipset-watchers) printf '%s' "Dynamic ipset Watchers (DoH / DoT auth)" ;;
            firewall)       printf '%s' "Firewall rules (SMARTDNS_* chains, ipset, UFW, sysctl)" ;;
            systemd-timers) printf '%s' "Systemd update timers (geosite & GeoHideDNS)" ;;
            certificates)   printf '%s' "TLS Certificates & ACME renewal (/etc/ssl/smartdns)" ;;
            domain-rules)   printf '%s' "Proxy domain rules & DNS assets (/var/lib/dns-assets)" ;;
            cover-site)     printf '%s' "Cover Site (/var/www/studio-nord)" ;;
            installer-core) printf '%s' "Installer state, manifest & logs (/var/lib/oxidns-installer)" ;;
            *)              printf '%s' "${cid}" ;;
        esac
    else
        case "${cid}" in
            nginx)          printf '%s' "Nginx (конфиг SmartDNS, drop-in hardening и репозиторий)" ;;
            xray)           printf '%s' "Xray-core (прозрачный SNI-прокси и автоперезагрузка)" ;;
            oxidns)         printf '%s' "OxiDNS (DNS-движок Rust)" ;;
            adguardhome)    printf '%s' "AdGuardHome (DNS-движок Go)" ;;
            ipset-watchers) printf '%s' "Службы динамической авторизации ipset (DoH / DoT)" ;;
            firewall)       printf '%s' "Правила Firewall (цепочки SMARTDNS_*, ipset, UFW, sysctl)" ;;
            systemd-timers) printf '%s' "Systemd-таймеры обновления (geosite и GeoHideDNS)" ;;
            certificates)   printf '%s' "TLS-сертификаты и автопродление ACME (/etc/ssl/smartdns)" ;;
            domain-rules)   printf '%s' "Правила проксируемых доменов (/var/lib/dns-assets)" ;;
            cover-site)     printf '%s' "Сайт-заглушка Cover Site (/var/www/studio-nord)" ;;
            installer-core) printf '%s' "Состояние, manifest и логи установщика (/var/lib/oxidns-installer)" ;;
            *)              printf '%s' "${cid}" ;;
        esac
    fi
}

validate_install_manifest_file() {
    [[ -f "${INSTALL_MANIFEST_FILE}" ]] || return 1
    grep -q '^# FORMAT=v1$' "${INSTALL_MANIFEST_FILE}" 2>/dev/null || return 1
    awk -F'\t' '!/^#/ && NF != 5 { bad=1 } END { exit bad }' "${INSTALL_MANIFEST_FILE}" 2>/dev/null || return 1
    return 0
}

manifest_has_component() {
    local cid="$1"
    [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 && -f "${INSTALL_MANIFEST_FILE}" ]] || return 1
    awk -F'\t' -v c="${cid}" '!/^#/ && $1 == "COMPONENT" && $2 == c { found=1 } END { exit !found }' "${INSTALL_MANIFEST_FILE}"
}

manifest_get_file_sha() {
    local target_path="$1"
    [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 && -f "${INSTALL_MANIFEST_FILE}" ]] || return 1
    awk -F'\t' -v p="${target_path}" '!/^#/ && ($1 == "FILE" || $1 == "SCRIPT" || $1 == "CERT" || $1 == "UNIT" || $1 == "TIMER" || $1 == "PATH_UNIT") && $3 == p { sha=$5 } END { if (sha != "") print sha }' "${INSTALL_MANIFEST_FILE}"
}

manifest_has_account() {
    local acc_type="$1"
    local acc_name="$2"
    [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 && -f "${INSTALL_MANIFEST_FILE}" ]] || return 1
    awk -F'\t' -v t="${acc_type}" -v n="${acc_name}" '!/^#/ && $1 == t && $3 == n { found=1 } END { exit !found }' "${INSTALL_MANIFEST_FILE}"
}

manifest_remove_component_entries() {
    local cid="$1"
    [[ -f "${INSTALL_MANIFEST_FILE}" ]] || return 0
    local tmp_mf="${INSTALL_MANIFEST_FILE}.tmp"
    awk -F'\t' -v c="${cid}" '/^#/ { print; next } $2 == c { next } { print }' "${INSTALL_MANIFEST_FILE}" > "${tmp_mf}"
    chmod 0600 "${tmp_mf}"
    mv -f "${tmp_mf}" "${INSTALL_MANIFEST_FILE}"
}

initial_backup_lookup() {
    local target_path="$1"
    [[ -f "${INITIAL_BACKUP_MANIFEST}" ]] || return 1
    awk -F'\t' -v p="${target_path}" '!/^#/ && $2 == p { print $3 "\t" $4 "\t" $5 "\t" $6 "\t" $7 "\t" $8 "\t" $9; exit }' "${INITIAL_BACKUP_MANIFEST}"
}

detect_installed_components() {
    UNINSTALL_DETECTED_COMPS=()
    UNINSTALL_COMP_SELECTED=()
    UNINSTALL_LEGACY_MODE=0
    UNINSTALL_BACKUP_OK=0

    if ! validate_install_manifest_file; then
        UNINSTALL_LEGACY_MODE=1
    fi

    if [[ -f "${INITIAL_BACKUP_MANIFEST}" ]] && verify_backup_integrity "${INITIAL_BACKUP_DIR}" >/dev/null 2>&1; then
        UNINSTALL_BACKUP_OK=1
    fi

    if manifest_has_component "nginx" || [[ -f /etc/systemd/system/nginx.service.d/hardening.conf ]] || { [[ -f /etc/nginx/nginx.conf ]] && grep -q 'doh-auth.log' /etc/nginx/nginx.conf 2>/dev/null; }; then
        UNINSTALL_DETECTED_COMPS+=("nginx")
    fi
    if manifest_has_component "xray" || [[ -x /usr/local/bin/xray || -f /etc/systemd/system/xray.service || -f "${XRAY_CONF_DIR}/00-base.json" ]]; then
        UNINSTALL_DETECTED_COMPS+=("xray")
    fi
    if manifest_has_component "oxidns" || [[ -x /usr/local/bin/oxidns || -f /etc/systemd/system/oxidns.service || -f /etc/oxidns/config.yaml ]]; then
        UNINSTALL_DETECTED_COMPS+=("oxidns")
    fi
    if manifest_has_component "adguardhome" || [[ -x /usr/local/bin/AdGuardHome || -f /etc/systemd/system/adguardhome.service || -f /etc/adguardhome/AdGuardHome.yaml ]]; then
        UNINSTALL_DETECTED_COMPS+=("adguardhome")
    fi
    if manifest_has_component "ipset-watchers" || [[ -x /usr/local/bin/doh-ipset-watcher.sh || -f /etc/systemd/system/doh-ipset-watcher.service || -f /etc/systemd/system/dot-ipset-watcher.service ]]; then
        UNINSTALL_DETECTED_COMPS+=("ipset-watchers")
    fi
    if manifest_has_component "firewall" || [[ -x /usr/local/bin/smartdns-firewall-apply.sh || -f /etc/systemd/system/smartdns-firewall.service || -f /etc/sysctl.d/90-smartdns-keepalive.conf ]] || iptables -t nat -S SMARTDNS_PREROUTING >/dev/null 2>&1; then
        UNINSTALL_DETECTED_COMPS+=("firewall")
    fi
    if manifest_has_component "systemd-timers" || [[ -f /etc/systemd/system/geosite-update.timer || -f /etc/systemd/system/geohide-update.timer ]]; then
        UNINSTALL_DETECTED_COMPS+=("systemd-timers")
    fi
    if manifest_has_component "certificates" || [[ -f "${CERT_DIR}/fullchain.pem" || -x /usr/local/bin/smartdns-cert-deploy.sh || -f /etc/systemd/system/smartdns-cert-renew.timer ]]; then
        UNINSTALL_DETECTED_COMPS+=("certificates")
    fi
    if manifest_has_component "domain-rules" || [[ -f "${GEOHIDE_LIST_FILE}" || -f "${XRAY_ROUTING_JSON}" || -x /usr/local/bin/update-geohide-domains.sh ]]; then
        UNINSTALL_DETECTED_COMPS+=("domain-rules")
    fi
    if manifest_has_component "cover-site" || [[ -f "${WEB_ROOT}/index.html" ]]; then
        UNINSTALL_DETECTED_COMPS+=("cover-site")
    fi
    if manifest_has_component "installer-core" || [[ -f "${SETTINGS_FILE}" || -f "${INSTALL_MANIFEST_FILE}" || -d "${STATE_DIR}" ]]; then
        UNINSTALL_DETECTED_COMPS+=("installer-core")
    fi

    local cid
    for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
        UNINSTALL_COMP_SELECTED["${cid}"]=0
    done
}

comp_is_detected() {
    local target="$1"
    local cid
    for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
        [[ "${cid}" == "${target}" ]] && return 0
    done
    return 1
}

comp_is_removing() {
    local target="$1"
    comp_is_detected "${target}" && [[ "${UNINSTALL_COMP_SELECTED[${target}]:-0}" -eq 1 ]]
}

comp_is_keeping() {
    local target="$1"
    comp_is_detected "${target}" && [[ "${UNINSTALL_COMP_SELECTED[${target}]:-0}" -eq 0 ]]
}

print_uninstall_component_menu() {
    printf_tr "M_0293"
    local i=0
    local cid mark label
    for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
        i=$((i + 1))
        mark=" "
        [[ "${UNINSTALL_COMP_SELECTED[${cid}]:-0}" -eq 1 ]] && mark="x"
        label="$(uninstall_comp_label "${cid}")"
        printf '  [%s] [%2d] %s\n' "${mark}" "${i}" "${label}"
    done
}

prompt_uninstall_selection() {
    local choice=""
    local cid
    while true; do
        print_uninstall_component_menu
        read_tr "M_0294" choice
        choice="${choice^^}"
        choice="${choice:-Q}"

        case "${choice}" in
            A)
                for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
                    UNINSTALL_COMP_SELECTED["${cid}"]=1
                done
                return 0
                ;;
            S|Q)
                printf_tr "M_0295"
                return 1
                ;;
            C)
                local custom_in=""
                while true; do
                    print_uninstall_component_menu
                    printf '\n'
                    read_tr "M_0296" custom_in
                    custom_in="${custom_in//$'\r'/}"
                    case "${custom_in^^}" in
                        Q)
                            printf_tr "M_0295"
                            return 1
                            ;;
                        A)
                            for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
                                UNINSTALL_COMP_SELECTED["${cid}"]=1
                            done
                            ;;
                        N)
                            for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
                                UNINSTALL_COMP_SELECTED["${cid}"]=0
                            done
                            ;;
                        D)
                            return 0
                            ;;
                        *)
                            local tok idx target_cid
                            for tok in ${custom_in//,/ }; do
                                if [[ "${tok}" =~ ^[0-9]+$ ]] && [[ "${tok}" -ge 1 && "${tok}" -le "${#UNINSTALL_DETECTED_COMPS[@]}" ]]; then
                                    idx=$((tok - 1))
                                    target_cid="${UNINSTALL_DETECTED_COMPS[${idx}]}"
                                    if [[ "${UNINSTALL_COMP_SELECTED[${target_cid}]:-0}" -eq 1 ]]; then
                                        UNINSTALL_COMP_SELECTED["${target_cid}"]=0
                                    else
                                        UNINSTALL_COMP_SELECTED["${target_cid}"]=1
                                    fi
                                fi
                            done
                            ;;
                    esac
                done
                ;;
        esac
    done
}

validate_uninstall_dependencies() {
    while true; do
        local -a dep_from=()
        local -a dep_need=()
        local -a dep_reason=()

        if comp_is_keeping "xray"; then
            if comp_is_removing "nginx"; then
                dep_from+=("xray"); dep_need+=("nginx"); dep_reason+=("nginx-local 127.0.0.1:9444 / dot-backend 127.0.0.1:8853")
            fi
            if comp_is_removing "domain-rules"; then
                dep_from+=("xray"); dep_need+=("domain-rules"); dep_reason+=("10-smartdns-routing.json")
            fi
            if comp_is_removing "firewall"; then
                dep_from+=("xray"); dep_need+=("firewall"); dep_reason+=("PREROUTING & anti-loop OUTPUT")
            fi
        fi

        if comp_is_keeping "nginx"; then
            if comp_is_removing "certificates"; then
                dep_from+=("nginx"); dep_need+=("certificates"); dep_reason+=("ssl_certificate /etc/ssl/smartdns")
            fi
            local active_dns="oxidns"
            if [[ -f "${SETTINGS_FILE}" ]]; then
                active_dns="$(awk -F'"' '/^DNS_ENGINE=/ {print $2}' "${SETTINGS_FILE}" 2>/dev/null || echo "oxidns")"
            fi
            if comp_is_removing "${active_dns}"; then
                local other_dns="adguardhome"
                [[ "${active_dns}" == "adguardhome" ]] && other_dns="oxidns"
                if ! comp_is_keeping "${other_dns}"; then
                    dep_from+=("nginx"); dep_need+=("${active_dns}"); dep_reason+=("upstream 127.0.0.1:5353 / 8053")
                fi
            fi
        fi

        if comp_is_keeping "ipset-watchers" && comp_is_removing "firewall"; then
            dep_from+=("ipset-watchers"); dep_need+=("firewall"); dep_reason+=("ipset smartdns_clients / dot_clients")
        fi

        if comp_is_keeping "systemd-timers" && comp_is_removing "domain-rules"; then
            dep_from+=("systemd-timers"); dep_need+=("domain-rules"); dep_reason+=("update-geosite.sh / update-geohide-domains.sh")
        fi

        if comp_is_removing "installer-core"; then
            local kcomp
            for kcomp in firewall ipset-watchers domain-rules systemd-timers xray nginx oxidns adguardhome; do
                if comp_is_keeping "${kcomp}"; then
                    dep_from+=("${kcomp}"); dep_need+=("installer-core"); dep_reason+=("/var/lib/oxidns-installer/settings")
                    break
                fi
            done
        fi

        if [[ "${#dep_from[@]}" -eq 0 ]]; then
            return 0
        fi

        printf_tr "M_0298"
        local i=0
        while [[ "${i}" -lt "${#dep_from[@]}" ]]; do
            printf_tr "M_0299" "${dep_from[${i}]}" "${dep_need[${i}]}" "${dep_reason[${i}]}"
            i=$((i + 1))
        done

        local dep_choice=""
        read_tr "M_0300" dep_choice
        dep_choice="${dep_choice^^}"
        dep_choice="${dep_choice:-1}"
        case "${dep_choice}" in
            1)
                local req
                for req in "${dep_need[@]}"; do
                    UNINSTALL_COMP_SELECTED["${req}"]=0
                done
                ;;
            2)
                return 2
                ;;
            *)
                printf_tr "M_0295"
                return 1
                ;;
        esac
    done
}

collect_removable_packages() {
    UNINSTALL_CANDIDATE_PKGS=()
    [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 && -f "${INSTALL_MANIFEST_FILE}" ]] || return 0

    local pkg
    while IFS= read -r pkg; do
        [[ -n "${pkg}" ]] || continue
        case "${pkg}" in
            nginx)
                if comp_is_removing "nginx"; then UNINSTALL_CANDIDATE_PKGS+=("${pkg}"); fi
                ;;
            ipset|conntrack)
                if comp_is_removing "firewall"; then UNINSTALL_CANDIDATE_PKGS+=("${pkg}"); fi
                ;;
            jq|dnsutils|unzip|socat|python3-bcrypt)
                # Предлагаем к удалению только при удалении всего стека
                if comp_is_removing "installer-core"; then
                    UNINSTALL_CANDIDATE_PKGS+=("${pkg}")
                fi
                ;;
        esac
    done < <(awk -F'\t' '!/^#/ && $1 == "PACKAGE" { print $3 }' "${INSTALL_MANIFEST_FILE}" | sort -u)
}

restore_file_from_initial_backup() {
    local target_path="$1"
    local bak_info="$2"

    local b_type b_mode b_owner b_group b_link b_sha b_rel
    IFS=$'\t' read -r b_type b_mode b_owner b_group b_link b_sha b_rel <<<"${bak_info}"
    local bak_full="${INITIAL_BACKUP_DIR}/${b_rel}"

    if [[ "${b_type}" == "file" ]]; then
        if [[ ! -f "${bak_full}" ]]; then
            log_error_tr "rollback.log" "M_0320" "${target_path}"
            return 1
        fi
        local bak_sha_now
        bak_sha_now="$(sha256sum "${bak_full}" | awk '{print $1}')"
        if [[ "${bak_sha_now}" != "${b_sha}" ]]; then
            log_error_tr "rollback.log" "M_0320" "${target_path}"
            return 1
        fi
        mkdir -p "$(dirname "${target_path}")"
        cp -a "${bak_full}" "${target_path}.restore.tmp" || return 1
        mv -f "${target_path}.restore.tmp" "${target_path}"
        chown "${b_owner}:${b_group}" "${target_path}" 2>/dev/null || true
        chmod "${b_mode}" "${target_path}" 2>/dev/null || true
        if [[ -f "${bak_full}.acl" ]] && command -v setfacl >/dev/null 2>&1; then
            setfacl --restore="${bak_full}.acl" 2>/dev/null || true
        fi
        log_info_tr "rollback.log" "M_0319" "${target_path}"
        return 0
    elif [[ "${b_type}" == "symlink" ]]; then
        mkdir -p "$(dirname "${target_path}")"
        rm -f "${target_path}"
        ln -s "${b_link}" "${target_path}"
        log_info_tr "rollback.log" "M_0319" "${target_path}"
        return 0
    fi
    return 1
}

uninstall_safe_remove_or_restore_file() {
    local target_path="$1"
    local allow_delete_without_manifest="${2:-0}"

    if [[ ! -e "${target_path}" && ! -L "${target_path}" ]]; then
        return 0
    fi

    local bak_info=""
    local has_backup=0
    if [[ -f "${INITIAL_BACKUP_MANIFEST}" ]]; then
        bak_info="$(initial_backup_lookup "${target_path}" || true)"
        if [[ -n "${bak_info}" ]]; then has_backup=1; fi
    fi

    local expected_sha=""
    if [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 ]]; then
        expected_sha="$(manifest_get_file_sha "${target_path}" || true)"
    fi

    local user_modified=0
    if [[ -f "${target_path}" && ! -L "${target_path}" ]]; then
        if [[ -n "${expected_sha}" && "${expected_sha}" != "-" && "${expected_sha}" != symlink:* ]]; then
            local cur_sha
            cur_sha="$(sha256sum "${target_path}" | awk '{print $1}')"
            if [[ "${cur_sha}" != "${expected_sha}" ]]; then
                user_modified=1
            fi
        elif [[ "${UNINSTALL_LEGACY_MODE}" -eq 1 && "${allow_delete_without_manifest}" -ne 1 ]]; then
            user_modified=1
        fi
    fi

    if [[ "${user_modified}" -eq 1 ]]; then
        printf_tr "M_0312" "${target_path}"
        while true; do
            printf_tr "M_0313" "${target_path}"
            if [[ "${has_backup}" -eq 1 && "${UNINSTALL_BACKUP_OK}" -eq 1 ]]; then
                printf_tr "M_0314"
                printf_tr "M_0315"
            else
                printf_tr "M_0316"
            fi
            local fchoice=""
            read_tr "M_0317" fchoice
            fchoice="${fchoice^^}"
            fchoice="${fchoice:-K}"

            case "${fchoice}" in
                K|C)
                    log_info_tr "rollback.log" "M_0318" "${target_path}"
                    return 0
                    ;;
                D)
                    if [[ "${has_backup}" -eq 1 ]]; then
                        local b_rel
                        b_rel="$(awk -F'\t' '{print $7}' <<<"${bak_info}")"
                        diff -u "${INITIAL_BACKUP_DIR}/${b_rel}" "${target_path}" || true
                    else
                        printf_tr "M_0332" "${target_path}"
                    fi
                    ;;
                R)
                    if [[ "${has_backup}" -eq 1 && "${UNINSTALL_BACKUP_OK}" -eq 1 ]]; then
                        restore_file_from_initial_backup "${target_path}" "${bak_info}"
                        return $?
                    fi
                    ;;
                X)
                    if [[ "${has_backup}" -eq 0 ]]; then
                        rm -f "${target_path}"
                        log_info_tr "rollback.log" "M_0321" "${target_path}"
                        return 0
                    fi
                    ;;
            esac
        done
    fi

    if [[ "${has_backup}" -eq 1 ]]; then
        if [[ "${UNINSTALL_BACKUP_OK}" -eq 1 ]]; then
            restore_file_from_initial_backup "${target_path}" "${bak_info}"
            return $?
        else
            log_warn_tr "rollback.log" "M_0322" "${target_path}"
            return 0
        fi
    fi

    rm -f "${target_path}"
    log_info_tr "rollback.log" "M_0321" "${target_path}"
    return 0
}

remove_dir_if_empty() {
    local dir_path="$1"
    [[ -d "${dir_path}" ]] || return 0
    if [[ -z "$(ls -A "${dir_path}" 2>/dev/null)" ]]; then
        rmdir "${dir_path}" 2>/dev/null || true
    else
        log_info_tr "rollback.log" "M_0330" "${dir_path}"
    fi
}

remove_manifest_account_if_owned() {
    local acc_type="$1"
    local acc_name="$2"
    if [[ "${acc_name}" == "www-data" || "${acc_name}" == "root" ]]; then return 0; fi
    if manifest_has_account "${acc_type}" "${acc_name}"; then
        if [[ "${acc_type}" == "USER" ]] && id -u "${acc_name}" >/dev/null 2>&1; then
            userdel "${acc_name}" 2>/dev/null || true
        elif [[ "${acc_type}" == "GROUP" ]] && getent group "${acc_name}" >/dev/null 2>&1; then
            groupdel "${acc_name}" 2>/dev/null || true
        fi
    fi
}

uninstall_component_ipset_watchers() {
    systemctl disable --now doh-ipset-watcher.service dot-ipset-watcher.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/doh-ipset-watcher.service" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/dot-ipset-watcher.service" 1
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/usr/local/bin/doh-ipset-watcher.sh" 1
    uninstall_safe_remove_or_restore_file "/usr/local/bin/dot-ipset-watcher.sh" 1
}

uninstall_component_systemd_timers() {
    systemctl disable --now geosite-update.timer geohide-update.timer geosite-update.service geohide-update.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/geosite-update.timer" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/geosite-update.service" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/geohide-update.timer" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/geohide-update.service" 1
    systemctl daemon-reload || true
}

uninstall_component_xray() {
    systemctl disable --now xray-reload.path xray-reload.service xray.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/xray-reload.path" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/xray-reload.service" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/xray.service" 1
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/etc/xray/conf.d/10-smartdns-routing.json" 1
    uninstall_safe_remove_or_restore_file "${XRAY_CONF_DIR}/00-base.json" 0
    uninstall_safe_remove_or_restore_file "/usr/local/bin/xray" 1
    uninstall_safe_remove_or_restore_file "/usr/local/bin/xray-safe-reload.sh" 1
    rm -f /var/log/xray/access.log /var/log/xray/error.log 2>/dev/null || true
    remove_dir_if_empty /var/log/xray
    remove_dir_if_empty "${XRAY_CONF_DIR}"
    remove_dir_if_empty "${XRAY_RULES_DIR}"
    remove_dir_if_empty /etc/xray
    remove_manifest_account_if_owned "USER" "xray"
    remove_manifest_account_if_owned "GROUP" "xray"
}

uninstall_component_nginx() {
    systemctl stop nginx.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/nginx.service.d/hardening.conf" 1
    remove_dir_if_empty /etc/systemd/system/nginx.service.d
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/etc/nginx/nginx.conf" 0
    uninstall_safe_remove_or_restore_file "/etc/apt/sources.list.d/nginx-official.list" 1
    uninstall_safe_remove_or_restore_file "/etc/apt/preferences.d/99nginx-official" 1
    uninstall_safe_remove_or_restore_file "/etc/apt/keyrings/nginx-archive-keyring.gpg" 1
    rm -f /var/log/nginx/doh-auth.log /var/log/nginx/dot-auth.log 2>/dev/null || true
    gpasswd -d www-data ssl-smartdns >/dev/null 2>&1 || true

    # Если nginx существовал до установки и его оригинальный конфиг восстановлен, вернуть в работу
    if [[ -f "${INITIAL_BACKUP_DIR}/preinstall-packages.list" ]] && grep -qx 'nginx' "${INITIAL_BACKUP_DIR}/preinstall-packages.list" 2>/dev/null; then
        if nginx -t >/dev/null 2>&1; then
            systemctl restart nginx.service 2>/dev/null || true
        fi
    else
        systemctl disable nginx.service 2>/dev/null || true
    fi
}

uninstall_component_oxidns() {
    systemctl disable --now oxidns.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/oxidns.service" 1
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/etc/oxidns/config.yaml" 0
    uninstall_safe_remove_or_restore_file "/usr/local/bin/oxidns" 1
    remove_dir_if_empty /etc/oxidns
    remove_dir_if_empty /var/lib/oxidns
    remove_manifest_account_if_owned "USER" "oxidns"
    remove_manifest_account_if_owned "GROUP" "oxidns"
}

uninstall_component_adguardhome() {
    systemctl disable --now adguardhome.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/adguardhome.service" 1
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/etc/adguardhome/AdGuardHome.yaml" 0
    uninstall_safe_remove_or_restore_file "/usr/local/bin/AdGuardHome" 1
    remove_dir_if_empty /etc/adguardhome
    remove_dir_if_empty /var/lib/adguardhome
    remove_manifest_account_if_owned "USER" "adguard"
    remove_manifest_account_if_owned "GROUP" "adguard"
}

uninstall_component_domain_rules() {
    local f
    for f in /usr/local/bin/update-geosite.sh /usr/local/bin/update-geohide-domains.sh \
             "${XRAY_ROUTING_JSON}" "${ROUTING_VARS_FILE}" "${GEOHIDE_LIST_FILE}" \
             "${GEOHIDE_HOSTS_FILE}" "${AGH_RULES_FILE}" "${DNS_ASSETS_DIR}/geosite.dat" \
             "${DNS_ASSETS_DIR}/domain-groups.map"; do
        uninstall_safe_remove_or_restore_file "${f}" 1
    done
    if [[ "${UNINSTALL_REMOVE_USER_DATA}" -eq 1 ]]; then
        uninstall_safe_remove_or_restore_file "${CUSTOM_ALLOW_FILE}" 1
        uninstall_safe_remove_or_restore_file "${CUSTOM_DENY_FILE}" 1
    fi
    remove_dir_if_empty "${DNS_ASSETS_DIR}"
    remove_dir_if_empty "${XRAY_RULES_DIR}"
}

uninstall_component_cover_site() {
    local f
    for f in "${WEB_ROOT}/index.html" "${WEB_ROOT}/404.html" "${WEB_ROOT}/favicon.svg" \
             "${WEB_ROOT}/robots.txt" "${WEB_ROOT}/sitemap.xml" \
             "${WEB_ROOT}/assets/style.css" "${WEB_ROOT}/assets/app.js"; do
        uninstall_safe_remove_or_restore_file "${f}" 0
    done
    remove_dir_if_empty "${WEB_ROOT}/assets"
    remove_dir_if_empty "${WEB_ROOT}"
}

uninstall_component_certificates() {
    if [[ -f "${SETTINGS_FILE}" ]]; then
        load_settings_safely "${SETTINGS_FILE}" || true
    fi
    if is_hostname_profile; then
        # Remove only SmartDNS hostname hooks & deployed copies; preserve user Certbot lineages and certbot.timer.
        uninstall_safe_remove_or_restore_file "/etc/letsencrypt/renewal-hooks/deploy/smartdns-hostname.sh" 1
        uninstall_safe_remove_or_restore_file "/usr/local/bin/smartdns-hostname-cert-deploy.sh" 1
        uninstall_safe_remove_or_restore_file "/usr/local/bin/verify-hostname-tls-keys.sh" 1
        uninstall_safe_remove_or_restore_file "${CERT_DIR}/fullchain.pem" 0
        uninstall_safe_remove_or_restore_file "${CERT_DIR}/privkey.pem" 0
        remove_dir_if_empty "${CERT_DIR}"
        remove_manifest_account_if_owned "GROUP" "ssl-smartdns"
        return 0
    fi
    systemctl disable --now smartdns-cert-renew.timer smartdns-cert-renew.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/smartdns-cert-renew.timer" 1
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/smartdns-cert-renew.service" 1
    systemctl daemon-reload || true
    uninstall_safe_remove_or_restore_file "/usr/local/bin/verify-tls-keys.sh" 1
    uninstall_safe_remove_or_restore_file "/usr/local/bin/smartdns-cert-deploy.sh" 1
    uninstall_safe_remove_or_restore_file "/usr/local/bin/smartdns-cert-renew.sh" 1
    uninstall_safe_remove_or_restore_file "${CERT_DIR}/fullchain.pem" 0
    uninstall_safe_remove_or_restore_file "${CERT_DIR}/privkey.pem" 0
    rm -rf "${STATE_DIR}/cert-stage" 2>/dev/null || true
    remove_dir_if_empty "${CERT_DIR}"
    if [[ "${UNINSTALL_REMOVE_ACME}" -eq 1 && -d /root/.acme.sh ]]; then
        /root/.acme.sh/acme.sh --uninstall >/dev/null 2>&1 || true
        rm -rf /root/.acme.sh 2>/dev/null || true
    fi
    remove_manifest_account_if_owned "GROUP" "ssl-smartdns"
}

uninstall_component_firewall() {
    systemctl disable --now smartdns-firewall.service 2>/dev/null || true
    uninstall_safe_remove_or_restore_file "/etc/systemd/system/smartdns-firewall.service" 1
    systemctl daemon-reload || true

    # Удаляем строго цепочки установщика, не затрагивая остальные правила iptables
    while iptables -t nat -C PREROUTING -j SMARTDNS_PREROUTING 2>/dev/null; do
        iptables -t nat -D PREROUTING -j SMARTDNS_PREROUTING || break
    done
    iptables -t nat -F SMARTDNS_PREROUTING 2>/dev/null || true
    iptables -t nat -X SMARTDNS_PREROUTING 2>/dev/null || true

    while iptables -t filter -C INPUT -j SMARTDNS_INPUT 2>/dev/null; do
        iptables -t filter -D INPUT -j SMARTDNS_INPUT || break
    done
    iptables -t filter -F SMARTDNS_INPUT 2>/dev/null || true
    iptables -t filter -X SMARTDNS_INPUT 2>/dev/null || true

    while iptables -t filter -C OUTPUT -j SMARTDNS_OUTPUT 2>/dev/null; do
        iptables -t filter -D OUTPUT -j SMARTDNS_OUTPUT || break
    done
    iptables -t filter -F SMARTDNS_OUTPUT 2>/dev/null || true
    iptables -t filter -X SMARTDNS_OUTPUT 2>/dev/null || true

    while ip6tables -t nat -C PREROUTING -j SMARTDNS6_PREROUTING 2>/dev/null; do
        ip6tables -t nat -D PREROUTING -j SMARTDNS6_PREROUTING || break
    done
    ip6tables -t nat -F SMARTDNS6_PREROUTING 2>/dev/null || true
    ip6tables -t nat -X SMARTDNS6_PREROUTING 2>/dev/null || true

    while ip6tables -t filter -C INPUT -j SMARTDNS6_INPUT 2>/dev/null; do
        ip6tables -t filter -D INPUT -j SMARTDNS6_INPUT || break
    done
    ip6tables -t filter -F SMARTDNS6_INPUT 2>/dev/null || true
    ip6tables -t filter -X SMARTDNS6_INPUT 2>/dev/null || true

    while ip6tables -t filter -C OUTPUT -j SMARTDNS6_OUTPUT 2>/dev/null; do
        ip6tables -t filter -D OUTPUT -j SMARTDNS6_OUTPUT || break
    done
    ip6tables -t filter -F SMARTDNS6_OUTPUT 2>/dev/null || true
    ip6tables -t filter -X SMARTDNS6_OUTPUT 2>/dev/null || true

    if command -v ipset >/dev/null 2>&1; then
        local iset
        for iset in smartdns_clients smartdns_clients6 dot_clients dot_clients6; do
            ipset destroy "${iset}" 2>/dev/null || true
        done
    fi

    uninstall_safe_remove_or_restore_file "/etc/sysctl.d/90-smartdns-keepalive.conf" 1
    sysctl --system >/dev/null 2>&1 || true

    if command -v ufw >/dev/null 2>&1; then
        local ssh_port
        ssh_port="$(ss -tlnp 2>/dev/null | awk '/sshd/ {split($4,a,":"); print a[length(a)]; exit}')"
        ssh_port="${ssh_port:-22}"
        ufw allow "${ssh_port}/tcp" >/dev/null 2>&1 || true

        ufw delete allow 853/tcp >/dev/null 2>&1 || true
        if ! comp_is_keeping "nginx"; then
            ufw delete allow 80/tcp >/dev/null 2>&1 || true
            ufw delete allow 443/tcp >/dev/null 2>&1 || true
        fi

        if [[ -f "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt" ]]; then
            if grep -Eq 'Status: (inactive|not-installed)' "${INITIAL_BACKUP_DIR}/preinstall-ufw-state.txt" 2>/dev/null; then
                ufw --force disable >/dev/null 2>&1 || true
            fi
        fi
    fi

    uninstall_safe_remove_or_restore_file "/usr/local/bin/smartdns-firewall-apply.sh" 1
    if command -v ufw >/dev/null 2>&1 && LC_ALL=C ufw status 2>/dev/null | grep -qi '^Status:[[:space:]]*active'; then
        firewall_allow_all_ssh_ports_ufw
    fi
}

run_uninstall() {
    detect_environment
    detect_installed_components

    printf '\n'
    printf_tr "M_0285"
    if [[ "${#UNINSTALL_DETECTED_COMPS[@]}" -eq 0 ]]; then
        printf_tr "M_0286"
        return 0
    fi

    if [[ "${UNINSTALL_LEGACY_MODE}" -eq 0 ]]; then
        printf_tr "M_0287" "$(tr_msg M_0289)"
    else
        printf_tr "M_0287" "$(tr_msg M_0290)"
    fi

    if [[ "${UNINSTALL_BACKUP_OK}" -eq 1 ]]; then
        printf_tr "M_0288" "$(tr_msg M_0291)"
    else
        printf_tr "M_0288" "$(tr_msg M_0292)"
    fi

    # Выбор компонентов с проверкой зависимостей (можно отменить на любом шаге)
    while true; do
        if ! prompt_uninstall_selection; then
            return 0
        fi

        local selected_count=0
        local cid
        for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
            if comp_is_removing "${cid}"; then
                selected_count=$((selected_count + 1))
            fi
        done
        if [[ "${selected_count}" -eq 0 ]]; then
            printf_tr "M_0297"
            return 0
        fi

        local dep_rc=0
        validate_uninstall_dependencies || dep_rc=$?
        if [[ "${dep_rc}" -eq 0 ]]; then
            selected_count=0
            for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
                if comp_is_removing "${cid}"; then
                    selected_count=$((selected_count + 1))
                fi
            done
            if [[ "${selected_count}" -eq 0 ]]; then
                printf_tr "M_0297"
                return 0
            fi
            break
        elif [[ "${dep_rc}" -eq 2 ]]; then
            continue
        else
            return 0
        fi
    done

    # Дополнительные безопасные опции (пользовательские данные, acme.sh, пакеты)
    UNINSTALL_REMOVE_USER_DATA=0
    if comp_is_removing "domain-rules" && { [[ -s "${CUSTOM_ALLOW_FILE}" ]] || [[ -s "${CUSTOM_DENY_FILE}" ]]; }; then
        local ans_ud=""
        read_tr "M_0308" ans_ud
        if [[ "${ans_ud:-N}" =~ ^[Yy]$ ]]; then UNINSTALL_REMOVE_USER_DATA=1; fi
    fi

    UNINSTALL_REMOVE_ACME=0
    if comp_is_removing "certificates" && [[ -d /root/.acme.sh ]]; then
        local ans_acme=""
        read_tr "M_0331" ans_acme
        if [[ "${ans_acme:-N}" =~ ^[Yy]$ ]]; then UNINSTALL_REMOVE_ACME=1; fi
    fi

    UNINSTALL_REMOVE_PACKAGES=0
    collect_removable_packages
    if [[ "${#UNINSTALL_CANDIDATE_PKGS[@]}" -gt 0 ]]; then
        local pkg_list_str
        pkg_list_str="$(printf '%s ' "${UNINSTALL_CANDIDATE_PKGS[@]}")"
        local ans_pkg=""
        read_tr "M_0309" ans_pkg "${pkg_list_str% }"
        if [[ "${ans_pkg:-N}" =~ ^[Yy]$ ]]; then UNINSTALL_REMOVE_PACKAGES=1; fi
    fi

    # Показ полного плана удаления
    printf_tr "M_0301"
    printf_tr "M_0302"
    local rem_any=0 keep_any=0
    for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
        if comp_is_removing "${cid}"; then
            printf '  - [%s] %s\n' "${cid}" "$(uninstall_comp_label "${cid}")"
            rem_any=1
        fi
    done
    if [[ "${rem_any}" -eq 0 ]]; then printf_tr "M_0304"; fi

    printf '\n'
    printf_tr "M_0303"
    for cid in "${UNINSTALL_DETECTED_COMPS[@]}"; do
        if comp_is_keeping "${cid}"; then
            printf '  - [%s] %s\n' "${cid}" "$(uninstall_comp_label "${cid}")"
            keep_any=1
        fi
    done
    if [[ "${keep_any}" -eq 0 ]]; then printf_tr "M_0304"; fi

    printf '\n'
    if comp_is_removing "domain-rules"; then
        printf_tr "M_0305" "$( [[ "${UNINSTALL_REMOVE_USER_DATA}" -eq 1 ]] && tr_msg M_0306 || tr_msg M_0307 )"
    fi
    if [[ "${UNINSTALL_REMOVE_PACKAGES}" -eq 1 && "${#UNINSTALL_CANDIDATE_PKGS[@]}" -gt 0 ]]; then
        printf_tr "M_0310" "$(printf '%s ' "${UNINSTALL_CANDIDATE_PKGS[@]}")"
    fi
    printf '=========================================================\n\n'

    local final_confirm=""
    read_tr "M_0311" final_confirm
    if [[ "${final_confirm^^}" != "YES" ]]; then
        printf_tr "M_0295"
        return 0
    fi

    # Инициализируем логи только после подтверждения пользователя
    init_logging

    # Строгий порядок удаления с учётом зависимостей
    local -a ordered_removal=(
        "ipset-watchers"
        "systemd-timers"
        "xray"
        "nginx"
        "oxidns"
        "adguardhome"
        "domain-rules"
        "cover-site"
        "certificates"
        "firewall"
    )

    local errors=0
    local failed_comps=""
    local comp_rc=0

    for cid in "${ordered_removal[@]}"; do
        if ! comp_is_removing "${cid}"; then
            continue
        fi
        log_info_tr "rollback.log" "M_0323" "${cid}"
        comp_rc=0
        case "${cid}" in
            ipset-watchers) uninstall_component_ipset_watchers || comp_rc=$? ;;
            systemd-timers) uninstall_component_systemd_timers || comp_rc=$? ;;
            xray)           uninstall_component_xray || comp_rc=$? ;;
            nginx)          uninstall_component_nginx || comp_rc=$? ;;
            oxidns)         uninstall_component_oxidns || comp_rc=$? ;;
            adguardhome)    uninstall_component_adguardhome || comp_rc=$? ;;
            domain-rules)   uninstall_component_domain_rules || comp_rc=$? ;;
            cover-site)     uninstall_component_cover_site || comp_rc=$? ;;
            certificates)   uninstall_component_certificates || comp_rc=$? ;;
            firewall)       uninstall_component_firewall || comp_rc=$? ;;
        esac

        if [[ "${comp_rc}" -ne 0 ]]; then
            errors=$((errors + 1))
            failed_comps+="${cid} "
            log_error_tr "rollback.log" "M_0324" "${cid}"
            # Не удаляем критические зависимости при сбое удаления зависимого компонента
            break
        else
            manifest_remove_component_entries "${cid}"
        fi
    done

    # Опциональное удаление пакетов (только если не было ошибок; remove без purge сохраняет сторонние и восстановленные конфиги в /etc/)
    if [[ "${errors}" -eq 0 && "${UNINSTALL_REMOVE_PACKAGES}" -eq 1 && "${#UNINSTALL_CANDIDATE_PKGS[@]}" -gt 0 ]]; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get remove -y -q "${UNINSTALL_CANDIDATE_PKGS[@]}" || errors=$((errors + 1))
        apt-get autoremove -y -q >/dev/null 2>&1 || true
    fi

    # Удаление state/manifest выполняется строго последним и только без ошибок
    if [[ "${errors}" -ne 0 ]]; then
        printf_tr "M_0328" "${failed_comps% }" "${STATE_DIR}"
        return 1
    fi

    if comp_is_removing "installer-core" && [[ "${keep_any}" -eq 0 ]]; then
        local sf
        for sf in "${SETTINGS_FILE}" "${VERSIONS_FILE}" "${SECRETS_FILE}" "${IPSET_SAVE_FILE}" \
                  "${STATE_DIR}/geohide-stats.env" "${STATE_DIR}/cover-site.sha256" \
                  "${STATE_DIR}/10-smartdns-routing.json.lastgood" "${STATE_DIR}/latest_backup"; do
            rm -f "${sf}" 2>/dev/null || true
        done
        rm -rf "${STATE_DIR}/fw-backup" 2>/dev/null || true

        local ans_bak=""
        read_tr "M_0325" ans_bak "${INITIAL_BACKUP_DIR}" "${BACKUP_ROOT}"
        if [[ "${ans_bak:-N}" =~ ^[Yy]$ ]]; then
            rm -rf "${INITIAL_BACKUP_DIR}" "${BACKUP_ROOT}" 2>/dev/null || true
            rm -f "${INSTALL_MANIFEST_FILE}" 2>/dev/null || true
            rm -f "${STATE_DIR}"/credentials-*.txt 2>/dev/null || true
            remove_dir_if_empty "${STATE_DIR}"
            rm -f "${LOG_DIR}"/*.log 2>/dev/null || true
            remove_dir_if_empty "${LOG_DIR}"
            printf_tr "M_0327"
        else
            rm -f "${INSTALL_MANIFEST_FILE}" 2>/dev/null || true
            printf_tr "M_0326" "${STATE_DIR}"
        fi
    else
        printf_tr "M_0329"
    fi
    return 0
}

# ------------------------------ Full Installation Flow ------------------------
run_install() {
    detect_environment
    prompt_install_profile_choice
    if is_hostname_profile; then
        initialize_hostname_profile || exit 1
    fi
    validate_os_and_resources
    if is_hostname_profile; then
        assert_fresh_install_target || exit 1
        run_hostname_check || exit 1
    fi

    init_logging
    init_reboot_lock "enforce"
    if [[ -t 0 && "${SKIP_INITIAL_SETUP_IN_INSTALL:-0}" -ne 1 ]]; then
        run_initial_server_setup "install"
    fi

    if is_hostname_profile && [[ ! -t 0 ]]; then
        run_noninteractive_hostname_wizard
    else
        run_interactive_wizard
    fi

    init_logging
    log_info_tr "installation.log" "M_0270" "${INSTALLER_VERSION}"

    init_initial_backup_store
    init_install_manifest
    create_system_backup
    setup_users_and_dirs
    TRANSACTION_ACTIVE=1

    apply_pending_custom_domains
    save_persistent_settings
    install_system_packages
    install_xray_binary
    if [[ "${DNS_ENGINE}" == "oxidns" ]]; then
        install_oxidns_binary
    else
        install_adguardhome_binary
    fi
    record_installed_versions

    if is_hostname_profile; then
        verify_provider_hostname_dns "${SERVER_IPV4}" "${SERVER_IPV6:-}"
        deploy_existing_hostname_certificate
    else
        log_info_tr "installation.log" "M_0271" "${ROOT_DOMAIN}"
        if ! sync_cloudflare_dns_records "${SERVER_IPV4}" "${SERVER_IPV6:-}"; then
            log_warn_tr "installation.log" "M_0272"
        fi

        issue_wildcard_certificate
    fi
    install_domain_update_scripts
    configure_xray_base
    log_info_tr "installation.log" "M_0374"
    /usr/local/bin/update-geosite.sh
    log_info_tr "installation.log" "M_0375"
    /usr/local/bin/update-geohide-domains.sh
    configure_dns_engine

    generate_procedural_cover_site "${WEB_ROOT}" "1"
    configure_nginx
    install_ipset_watchers
    configure_firewall_and_sysctl
    install_systemd_units

    verify_dns_backend_isolated
    run_test_suite
    unlock_reboot_after_smartdns "1" || true
    record_postinstall_packages_and_accounts
    record_full_install_manifest
    seal_initial_backup
    TRANSACTION_ACTIVE=0
    generate_installation_report
    prompt_deferred_reboot_if_needed
}

# ------------------------------ CLI Argument Parser ---------------------------
print_help() {
    printf '%s\n' "$(tr_msg "M_0273")"
    printf_tr "HN_21"
    printf_tr "HN_22"
    printf_tr "HN_23"
    printf_tr "HN_24"
    printf_tr "HN_25"
}

main() {
    local -a parsed_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --profile)
                if [[ $# -lt 2 ]]; then
                    printf_err_tr "HN_PROFILE_BAD" ""
                    exit 1
                fi
                INSTALL_PROFILE="${2,,}"
                if [[ "${INSTALL_PROFILE}" != "cloudflare" && "${INSTALL_PROFILE}" != "hostname" ]]; then
                    printf_err_tr "HN_PROFILE_BAD" "${INSTALL_PROFILE}"
                    exit 1
                fi
                shift 2
                ;;
            --profile=*)
                INSTALL_PROFILE="${1#--profile=}"
                INSTALL_PROFILE="${INSTALL_PROFILE,,}"
                if [[ "${INSTALL_PROFILE}" != "cloudflare" && "${INSTALL_PROFILE}" != "hostname" ]]; then
                    printf_err_tr "HN_PROFILE_BAD" "${INSTALL_PROFILE}"
                    exit 1
                fi
                shift
                ;;
            *)
                parsed_args+=("$1")
                shift
                ;;
        esac
    done
    set -- "${parsed_args[@]}"

    if [[ $# -eq 0 && -t 0 ]]; then
        select_interface_language
        run_main_launcher_menu
        return 0
    fi
    select_interface_language
    if [[ $# -eq 0 ]]; then
        print_help
        exit 0
    fi

    case "$1" in
        --hostname-check)
            INSTALL_PROFILE="hostname"
            ;;
        --update|--sync-ip|--switch-engine|--regenerate-cover|--test)
            detect_install_profile_from_context || exit 1
            if is_hostname_profile; then
                initialize_hostname_profile || exit 1
            fi
            ;;
    esac

    case "$1" in
        --help|-h)
            ACTION_MODE="help"
            print_help
            ;;
        --hostname-check)
            ACTION_MODE="preflight"
            check_root
            initialize_hostname_profile || exit 1
            run_hostname_check || exit 1
            ;;
        --preflight)
            ACTION_MODE="preflight"
            check_root
            run_preflight
            ;;
        --initial-setup)
            check_root
            acquire_lock
            detect_environment
            validate_os_and_resources
            init_logging
            init_reboot_lock "enforce"
            run_initial_server_setup "standalone"
            ;;
        --install)
            ACTION_MODE="install"
            check_root
            acquire_lock
            run_install
            ;;
        --switch-engine)
            ACTION_MODE="switch-engine"
            check_root
            acquire_lock
            init_logging
            run_switch_engine "${2:-}"
            ;;
        --sync-ip)
            ACTION_MODE="sync-ip"
            check_root
            acquire_lock
            init_logging
            run_sync_ip
            ;;
        --change-domain)
            ACTION_MODE="change-domain"
            check_root
            acquire_lock
            init_logging
            run_change_domain "${2:-}" || exit 1
            ;;
        --domain-groups)
            ACTION_MODE="domain-groups"
            check_root
            acquire_lock
            init_logging
            run_manage_domain_groups
            ;;
        --update)
            ACTION_MODE="update"
            check_root
            acquire_lock
            init_logging
            run_update
            ;;
        --regenerate-cover)
            ACTION_MODE="regenerate-cover"
            check_root
            acquire_lock
            init_logging
            run_regenerate_cover
            ;;
        --status)
            ACTION_MODE="status"
            check_root
            run_status
            ;;
        --test)
            ACTION_MODE="test"
            check_root
            run_test_suite
            ;;
        --backup)
            ACTION_MODE="backup"
            check_root
            acquire_lock
            init_logging
            create_system_backup
            ;;
        --rollback)
            ACTION_MODE="rollback"
            check_root
            acquire_lock
            init_logging
            perform_rollback "${2:-}"
            ;;
        --uninstall)
            ACTION_MODE="uninstall"
            check_root
            acquire_lock
            run_uninstall
            ;;
        --whitelist-status)
            ACTION_MODE="whitelist"
            check_root
            run_whitelist_status
            ;;
        --whitelist-toggle)
            ACTION_MODE="whitelist"
            check_root
            acquire_lock
            init_logging
            run_whitelist_toggle "${2:-toggle}"
            ;;
        --whitelist-mode)
            ACTION_MODE="whitelist"
            check_root
            acquire_lock
            init_logging
            run_whitelist_mode "${2:-}"
            ;;
        --whitelist-add)
            ACTION_MODE="whitelist"
            check_root
            acquire_lock
            init_logging
            run_whitelist_add "${2:-}"
            ;;
        --whitelist-remove)
            ACTION_MODE="whitelist"
            check_root
            acquire_lock
            init_logging
            run_whitelist_remove "${2:-}"
            ;;
        --whitelist-flush)
            ACTION_MODE="whitelist"
            check_root
            acquire_lock
            init_logging
            run_whitelist_flush
            ;;
        *)
            printf_err_tr "M_0274" "$1"
            print_help
            exit 1
            ;;
    esac
}

main "$@"
