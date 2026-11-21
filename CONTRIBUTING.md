# Руководство для участников / Contributing Guide

Мы приветствуем вклад в развитие **Unified SmartDNS + Transparent SNI Proxy Installer**.

## Требования к изменениям (Pull Requests)

1. **Проверка синтаксиса, статический анализ и автотесты:** все изменения в основном скрипте должны проходить локальную проверку без предупреждений и ошибок:

   Проверка синтаксиса:
   ```bash
   bash -n smartdns-installer-v3.1.0-stealth.sh
   ```

   Статический анализ ShellCheck:
   ```bash
   shellcheck -S warning \
     -e SC1090,SC2034,SC2154 \
     smartdns-installer-v3.1.0-stealth.sh
   ```

   Регрессионные и конфликтные автотесты:
   ```bash
   python3 tests/test_hostname_profile.py
   python3 tests/test_nspawn_second_ip.py
   ```

2. **Двуязычная локализация (`RU / EN`):** любые новые пользовательские сообщения, подсказки и заголовки должны регистрироваться одновременно в обоих словарях (`MSG_RU` и `MSG_EN`) без хардкода кириллицы в логике вывода.
3. **Транзакционность, изоляция и обратная совместимость:**
   - изменения не должны нарушать механизм отката (`--rollback`), права непривилегированных пользователей (`xray`, `oxidns`, `adguardhome`, `nginx`) и защиту внутренних портов;
   - в режиме `systemd-nspawn` (`--install-on-second-IP`) запрещены глобальный сброс правил firewall хоста (`iptables -F`, `nft flush ruleset`, `ufw reset`) и модификация существующих служб хоста;
   - механизм автопродления Cloudflare (`v3.0-stealth`) и архивные релизы в `old/` должны оставаться неизменными.
4. **Документация:** при добавлении новых флагов CLI или изменении поведения обновляйте `README.md`, `README_EN.md`, `HOSTNAME_SETUP.md` (при необходимости) и `CHANGELOG.md`.

## Порядок работы

1. Создайте форк репозитория и ответвление от ветки `main` (`git checkout -b feat/my-feature`).
2. Внесите изменения и проверьте их на тестовом сервере Debian 12/13 или Ubuntu 22.04/24.04 (`--preflight`, `--preflight-second-IP`, `--hostname-check`, `--install` / `--install-on-second-IP`, `--test`).
3. Отправьте Pull Request, заполнив чек-лист в шаблоне PR.
