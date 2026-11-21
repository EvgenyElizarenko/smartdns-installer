# Поддержка и диагностика / Support & Diagnostics

## Перед обращением за помощью

1. Изучите раздел **[9. Устранение неполадок (Troubleshooting)](README.md#9-устранение-неполадок-troubleshooting)** в документации (`README.md` / `README_EN.md`) и при использовании профиля без Cloudflare — **[HOSTNAME_SETUP.md](HOSTNAME_SETUP.md)**.
2. Запустите встроенный комплекс из 26 автотестов на сервере:

   Выделенный сервер (Режим № 2):
   ```bash
   sudo ./smartdns-installer.sh --test
   ```

   Изолированный контейнер `systemd-nspawn` на 2-м IP (Режим № 3):
   ```bash
   sudo ./smartdns-installer.sh --target container --test
   ```

3. Проверьте состояние служб, сети, белого списка IP и Telegram-бота:

   ```bash
   # Выделенный сервер (хост)
   sudo ./smartdns-installer.sh --status
   sudo ./smartdns-installer.sh --whitelist-status
   sudo ./smartdns-installer.sh --telegram-bot-status
   sudo ./smartdns-installer.sh --telegram-bot-check

   # Изолированный контейнер systemd-nspawn (2-й IP)
   sudo ./smartdns-installer.sh --target container --status
   sudo ./smartdns-installer.sh --target container --whitelist-status
   sudo ./smartdns-installer.sh --target container --telegram-bot-status
   sudo ./smartdns-installer.sh --target container --telegram-bot-check
   sudo /usr/local/bin/smartdns-nspawn-host-net.sh status

   # Read-only диагностика до установки
   sudo ./smartdns-installer.sh --preflight-second-IP
   sudo ./smartdns-installer.sh --hostname-check
   ```

## Куда обращаться

* **Ошибки и сбои установки:** создайте обращение через форму **[Ошибка / Bug Report](https://github.com/EvgenyElizarenko/smartdns-installer/issues/new?template=bug_report.yml)**, приложив вывод `--test` / `--telegram-bot-check` и фрагмент журнала из `/var/log/oxidns-installer/` или `/var/log/smartdns-tgbot/` (для контейнера `systemd-nspawn` — внутри `/var/lib/machines/smartdns-v3.1.0/var/log/`).
* **Идеи и предложения по улучшению:** используйте форму **[Предложение / Feature Request](https://github.com/EvgenyElizarenko/smartdns-installer/issues/new?template=feature_request.yml)**.

> **Важно:** перед публикацией логов обязательно удалите **Telegram Bot Token**, **Cloudflare API Token**, 48-символьный секретный путь **DOH_PATH** и реальное доменное имя.
