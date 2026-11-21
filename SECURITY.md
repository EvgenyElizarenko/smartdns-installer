# Политика безопасности / Security Policy

## Поддерживаемые версии / Supported Versions

Обновления безопасности и исправления ошибок выпускаются только для актуальной релизной ветки:

| Версия / Version | Поддержка / Supported |
| :--- | :---: |
| `v4.0.x-stealth` (`smartdns-installer.sh`) | Да / Yes |
| `< v4.0.0` (`old/`) | Нет / No |

---

## Сообщение об уязвимостях / Reporting a Vulnerability

Если вы обнаружили уязвимость в скрипте установщика, модуле Telegram-бота (`smartdns-tgbot`, Unix-сокет `/run/smartdns-tg-ctl/ctl.sock`, проверка `SO_PEERCRED`, авторизация `Owner-Only`, хранение `/etc/smartdns-tgbot/token.env`), правилах фильтрации `iptables`/`ip6tables`/`nftables`/`ipset`, изоляции контейнера `systemd-nspawn` (`SMARTDNS_NSPAWN_*`), конфигурации `Nginx`/`Xray-core`, странице `/auth/` или утечку данных в `Cover Site`:

1. **Не создавайте публичный Issue** с описанием эксплойта или воспроизведением уязвимости.
2. Отправьте приватное сообщение через механизм **GitHub Security Advisories** (`https://github.com/EvgenyElizarenko/smartdns-installer/security/advisories/new`) либо свяжитесь с сопровождающим репозитория напрямую.
3. Укажите в отчёте:
   * версию скрипта (`INSTALLER_VERSION`), режим установки (`--install` или `--install-on-second-IP`), профиль (`cloudflare` или `hostname`), наличие Telegram-бота, ОС и архитектуру CPU;
   * шаги для воспроизведения проблемы;
   * потенциальное влияние на безопасность сервера, контейнера, Telegram-бота или клиентов.

Первичный ответ предоставляется в течение **72 часов**. После подтверждения и подготовки исправления публикуется патч-релиз с указанием благодарности исследователю (по желанию).
