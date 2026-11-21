# Поддержка и диагностика / Support & Diagnostics

## Перед обращением за помощью

1. Изучите раздел **[9. Устранение неполадок (Troubleshooting)](README.md#9-устранение-неполадок-troubleshooting)** в документации (`README.md` / `README_EN.md`) и при использовании профиля без Cloudflare — **[HOSTNAME_SETUP.md](HOSTNAME_SETUP.md)**.
2. Запустите встроенный комплекс из 26 автотестов на сервере:

   Выделенный сервер (Режим № 2):
   ```bash
   sudo ./smartdns-installer-v3.1.0-stealth.sh --test
   ```

   Изолированный контейнер `systemd-nspawn` на 2-м IP (Режим № 3):
   ```bash
   sudo ./smartdns-installer-v3.1.0-stealth.sh --target container --test
   ```

3. Проверьте состояние служб, сети и белого списка IP:

   ```bash
   # Выделенный сервер (хост)
   sudo ./smartdns-installer-v3.1.0-stealth.sh --status
   sudo ./smartdns-installer-v3.1.0-stealth.sh --whitelist-status

   # Изолированный контейнер systemd-nspawn (2-й IP)
   sudo ./smartdns-installer-v3.1.0-stealth.sh --target container --status
   sudo ./smartdns-installer-v3.1.0-stealth.sh --target container --whitelist-status
   sudo /usr/local/bin/smartdns-nspawn-host-net.sh status

   # Read-only диагностика до установки
   sudo ./smartdns-installer-v3.1.0-stealth.sh --preflight-second-IP
   sudo ./smartdns-installer-v3.1.0-stealth.sh --hostname-check
   ```

## Куда обращаться

* **Ошибки и сбои установки:** создайте обращение через форму **[Ошибка / Bug Report](https://github.com/EvgenyElizarenko/smartdns-installer/issues/new?template=bug_report.yml)**, приложив вывод `--test` и фрагмент журнала из `/var/log/oxidns-installer/` (для контейнера `systemd-nspawn` — `/var/lib/machines/smartdns-v3.1.0/var/log/oxidns-installer/`).
* **Идеи и предложения по улучшению:** используйте форму **[Предложение / Feature Request](https://github.com/EvgenyElizarenko/smartdns-installer/issues/new?template=feature_request.yml)**.

> **Важно:** перед публикацией логов обязательно удалите свой **Cloudflare API Token**, 48-символьный секретный путь **DOH_PATH** и реальное доменное имя.
