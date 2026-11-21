#!/usr/bin/env python3
"""Comprehensive automated test suite for SmartDNS v4.0.0-stealth Telegram Bot.
Covers Sections 18.1-18.10: installer structure, authorization, single/batch/file
domain management, whitelist, links, status, D1-D5/W1-W2/S1-S2/B1 features,
security (injection/traversal/redaction/locking/rollback), and v3.1.0 immutability.
"""

from __future__ import annotations

import ast
import hashlib
import importlib.util
import io
import json
import os
import py_compile
import re
import subprocess
import sys
import tempfile
import time
import types
import urllib.error
from pathlib import Path
from typing import Any

REPO_ROOT = Path(__file__).resolve().parent.parent
V310_SCRIPT = REPO_ROOT / "smartdns-installer-v3.1.0-stealth.sh"
V400_SCRIPT = REPO_ROOT / os.environ.get("SMARTDNS_INSTALLER", "smartdns-installer-v4.0.0-stealth.sh")
V310_EXPECTED_SHA = "ae5cd601e1e003a4e363df1778fbd9215cfba511b268b18d5f26d989f21b040b"


def install_windows_posix_shims() -> None:
    """Allow full unit/integration execution of Linux-targeted ctl.py under Windows Git Bash."""
    if sys.platform != "win32":
        return

    if not hasattr(os, "geteuid"):
        os.geteuid = lambda: 1000  # type: ignore[attr-defined]
    if not hasattr(os, "getloadavg"):
        os.getloadavg = lambda: (0.21, 0.18, 0.15)  # type: ignore[attr-defined]

    if "fcntl" not in sys.modules:
        fcntl_mod = types.ModuleType("fcntl")
        fcntl_mod.LOCK_EX = 2  # type: ignore[attr-defined]
        fcntl_mod.LOCK_NB = 4  # type: ignore[attr-defined]
        fcntl_mod.LOCK_UN = 8  # type: ignore[attr-defined]
        _held_locks: set[int] = set()

        def _flock(fd: int, op: int) -> None:
            if op & 8:  # LOCK_UN
                _held_locks.discard(fd)
                return
            if _held_locks and (op & 4):
                raise BlockingIOError("Lock already held")
            _held_locks.add(fd)

        fcntl_mod.flock = _flock  # type: ignore[attr-defined]
        sys.modules["fcntl"] = fcntl_mod

    if "pwd" not in sys.modules:
        pwd_mod = types.ModuleType("pwd")
        pwd_mod.getpwnam = lambda name: types.SimpleNamespace(pw_uid=1001, pw_gid=1001)  # type: ignore[attr-defined]
        sys.modules["pwd"] = pwd_mod


def extract_heredoc(script_text: str, marker: str) -> str:
    pat = re.compile(rf"<<'{re.escape(marker)}'\n(.*?)\n{re.escape(marker)}\b", re.S)
    m = pat.search(script_text)
    assert m, f"Embedded heredoc {marker} not found in {V400_SCRIPT.name}"
    return m.group(1) + "\n"


def load_module_from_path(name: str, file_path: Path) -> Any:
    spec = importlib.util.spec_from_file_location(name, str(file_path))
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    sys.modules[name] = mod
    spec.loader.exec_module(mod)
    return mod


def ast_security_audit(source: str, label: str) -> None:
    tree = ast.parse(source, filename=label)
    for node in ast.walk(tree):
        if isinstance(node, ast.Call):
            fn = node.func
            if isinstance(fn, ast.Name) and fn.id in ("eval", "exec", "__import__"):
                raise AssertionError(f"Forbidden builtin {fn.id}() in {label}")
            if isinstance(fn, ast.Attribute) and fn.attr in ("system", "popen"):
                raise AssertionError(f"Forbidden shell call .{fn.attr}() in {label}")
            for kw in node.keywords:
                if kw.arg == "shell" and isinstance(kw.value, ast.Constant) and kw.value.value is True:
                    raise AssertionError(f"Forbidden shell=True in {label}")
        if isinstance(node, (ast.Import, ast.ImportFrom)):
            mod_name = getattr(node, "module", "") or ""
            names = [a.name for a in node.names]
            if "threading" in mod_name or "threading" in names:
                raise AssertionError(f"Unexpected threading import in {label} (M1 must not be included)")


def run_bash_snippet(code: str, env_extra: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    env = dict(os.environ)
    env.setdefault("SCRIPT_LANG", "en")
    if env_extra:
        env.update(env_extra)
    return subprocess.run(
        ["bash", "-c", code],
        stdin=subprocess.DEVNULL,
        capture_output=True,
        text=True,
        env=env,
        timeout=15,
    )


def main() -> None:
    install_windows_posix_shims()

    # =========================================================================
    # 1. Immutability, Structure, CLI, Menu, Hardening & AST Security Checks
    # =========================================================================
    v310_sha = hashlib.sha256(V310_SCRIPT.read_bytes()).hexdigest()
    assert v310_sha == V310_EXPECTED_SHA, f"v3.1.0-stealth modified! got {v310_sha}"
    print("PASS: v3.1.0-stealth is byte-for-byte unchanged")

    v400_text = V400_SCRIPT.read_text(encoding="utf-8").replace("\r\n", "\n")
    assert 'INSTALLER_VERSION="4.0.0-stealth"' in v400_text
    assert 'SCRIPT_NAME="smartdns-installer-v4.0.0-stealth.sh"' in v400_text
    assert "Выберите пункт [0-19]:" in v400_text and "Select an option [0-19]:" in v400_text
    assert "[19] Telegram Bot setup & management" in v400_text
    assert "[19] Установка и управление Telegram-ботом" in v400_text
    assert 'if [[ -n "${TG_BOT_TOKEN:-}" ]]; then' in v400_text
    assert "NoNewPrivileges=true" in v400_text
    assert "SocketMode=0660" in v400_text
    assert "run_telegram_bot_remove()" in v400_text
    print("PASS: v4.0.0 structure, menu [0-19], systemd socket/hardening & redaction present")

    # Verify --help outputs all Telegram Bot CLI flags cleanly without hanging
    res_help = subprocess.run(
        ["bash", str(V400_SCRIPT), "--help"],
        stdin=subprocess.DEVNULL,
        env=dict(os.environ, SCRIPT_LANG="en"),
        capture_output=True,
        text=True,
        timeout=10,
    )
    assert res_help.returncode == 0, res_help.stderr
    for flag in (
        "--install-telegram-bot",
        "--telegram-bot-config",
        "--telegram-bot-check",
        "--telegram-bot-status",
        "--telegram-bot-start",
        "--telegram-bot-stop",
        "--telegram-bot-restart",
        "--telegram-bot-remove",
    ):
        assert flag in res_help.stdout, f"Missing {flag} in --help output"
    print("PASS: --help exposes all 8 Telegram Bot CLI flags cleanly")

    # Verify Bash token/admin validators & redact_secrets directly via sourced library copy
    with tempfile.TemporaryDirectory(prefix="smartdns-v400-test-") as td:
        tmp_dir = Path(td)
        lib_script = tmp_dir / "v400-lib.sh"
        lib_script.write_text(v400_text.replace('\nmain "$@"\n', "\n# main disabled for unit test\n"), encoding="utf-8", newline="\n")

        fake_tok = "123456789:AAFakeSecretToken_0123456789abcdef"
        res_bash = run_bash_snippet(
            f'source "{lib_script.as_posix()}"; trap - ERR; '
            f'tgbot_validate_token_format "{fake_tok}" && '
            f'! tgbot_validate_token_format "bad_token" && '
            f'tgbot_validate_user_id "123456789" && '
            f'! tgbot_validate_user_id "0" && '
            f'! tgbot_validate_user_id "abc;rm" && '
            f'TG_BOT_TOKEN="{fake_tok}"; '
            f'out="$(redact_secrets "err token={fake_tok} end")"; '
            f'[[ "${{out}}" == *"[REDACTED_TG_TOKEN]"* && "${{out}}" != *"{fake_tok}"* ]]'
        )
        assert res_bash.returncode == 0, f"Bash validator/redaction check failed: {res_bash.stderr}"
        print("PASS: Bash token/admin validation & redact_secrets mask TG_BOT_TOKEN")

        # Verify container routing includes all telegram-bot commands
        assert "|--install-telegram-bot|--telegram-bot-config|--telegram-bot-check|--telegram-bot-status|--telegram-bot-start|--telegram-bot-stop|--telegram-bot-restart|--telegram-bot-remove)" in v400_text
        print("PASS: Container (--target container) routing covers all Telegram Bot commands")

        # Verify run_telegram_bot_remove never deletes SmartDNS files/units/ipset
        rm_fn = re.search(r"^run_telegram_bot_remove\(\)\s*\{(.*?)^\}", v400_text, flags=re.M | re.S)
        assert rm_fn
        rm_body = rm_fn.group(1)
        for forbidden in ("oxidns", "xray", "nginx", "ipset", "smartdns-firewall", "/etc/ssl/smartdns", "custom-allow"):
            assert forbidden not in rm_body, f"run_telegram_bot_remove must not touch {forbidden}"
        print("PASS: run_telegram_bot_remove strictly isolated from SmartDNS components")

        # Extract embedded ctl.py & bot.py, compile & AST-audit
        ctl_src = extract_heredoc(v400_text, "EOF_SMARTDNS_TGBOT_CTL_PY")
        bot_src = extract_heredoc(v400_text, "EOF_SMARTDNS_TGBOT_BOT_PY")
        ctl_file = tmp_dir / "ctl.py"
        bot_file = tmp_dir / "bot.py"
        ctl_file.write_text(ctl_src, encoding="utf-8", newline="\n")
        bot_file.write_text(bot_src, encoding="utf-8", newline="\n")
        py_compile.compile(str(ctl_file), doraise=True)
        py_compile.compile(str(bot_file), doraise=True)
        ast_security_audit(ctl_src, "ctl.py")
        ast_security_audit(bot_src, "bot.py")
        print("PASS: Embedded ctl.py & bot.py compile cleanly and pass AST security audit (no eval/shell=True/M1)")

        # =====================================================================
        # 2. Sandboxed Functional & Security Tests for ctl.py and bot.py
        # =====================================================================
        sandbox = tmp_dir / "rootfs"
        os.environ["TGBOT_TEST_ROOT"] = str(sandbox)
        os.environ["TGBOT_ETC_DIR"] = str(sandbox / "etc/smartdns-tgbot")
        os.environ["TGBOT_TMP_DIR"] = str(sandbox / "var/lib/smartdns-tgbot/tmp")
        os.environ["TGBOT_LOG_FILE"] = str(sandbox / "var/log/smartdns-tgbot/bot.log")

        def mk(rel: str, content: str) -> Path:
            target = sandbox / rel.lstrip("/")
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8", newline="\n")
            return target

        ADMIN_ID = 111222333
        SECOND_ADMIN_ID = 444555666
        ATTACKER_ID = 999888777
        SECRET_DOH_PATH = "SuperSecretDoHPath48CharsLong0123456789ABCDEFGH"
        SECRET_CF_TOKEN = "cf_secret_token_never_leak_987654321"
        SECRET_AGH_PASS = "AghSecretPass!2026"

        mk("/var/lib/oxidns-installer/settings", (
            'INSTALL_PROFILE="cloudflare"\n'
            'CONTAINER_MODE="0"\n'
            'DNS_ENGINE="oxidns"\n'
            'DNS_USER="oxidns"\n'
            'ROOT_DOMAIN="example.test"\n'
            'DOH_HOST="example.test"\n'
            'DOT_HOST="abc1234567.example.test"\n'
            'DOT_WHITELIST_ENABLED="true"\n'
            'DOT_WHITELIST_MODE="shared"\n'
            'SERVER_IPV4="203.0.113.10"\n'
        ))
        mk("/var/lib/oxidns-installer/secrets.env", (
            f'DOH_PATH="{SECRET_DOH_PATH}"\n'
            f'CF_API_TOKEN="{SECRET_CF_TOKEN}"\n'
            f'AGH_ADMIN_PASS="{SECRET_AGH_PASS}"\n'
        ))
        mk("/var/lib/oxidns-installer/ipset-whitelist.save", "create smartdns_clients hash:ip family inet timeout 86400\n")
        mk("/var/lib/dns-assets/geohide-domains.txt", "openai.com\nclaude.ai\n")
        mk("/var/lib/dns-assets/custom-allow.txt", "custom-existing.org\n")
        mk("/var/lib/dns-assets/custom-deny.txt", "blocked-by-user.org\n")
        mk("/etc/xray/rules.d/10-smartdns-routing.json", json.dumps({
            "routing": {"rules": [{"type": "field", "domain": ["domain:openai.com", "domain:claude.ai", "domain:custom-existing.org"]}]}
        }))
        mk("/etc/xray/conf.d/00-base.json", "{}\n")
        mk("/usr/local/bin/xray", "#!/bin/sh\nexit 0\n")
        mk("/usr/local/bin/update-geohide-domains.sh", "#!/bin/sh\nexit 0\n")
        mk("/etc/ssl/smartdns/fullchain.pem", "DUMMY CERT\n")
        mk("/var/log/oxidns-installer/dns.log", f"line1 cf={SECRET_CF_TOKEN} doh={SECRET_DOH_PATH} tok={fake_tok}\n")
        mk("/etc/smartdns-tgbot/token.env", f"TELEGRAM_BOT_TOKEN={fake_tok}\n")
        mk("/etc/smartdns-tgbot/config.json", json.dumps({
            "primary_admin_id": ADMIN_ID,
            "allowed_user_ids": [ADMIN_ID],
            "language": "ru",
            "max_file_bytes": 262144,
            "max_batch_domains": 10,  # Low cap in test to verify limit enforcement cleanly
            "confirm_ttl_sec": 300,
            "enabled_modules": {
                "domains": True, "whitelist": True, "links": True,
                "status": True, "services": True, "logs": True,
            },
        }))

        ctl = load_module_from_path("smartdns_ctl_test", ctl_file)
        bot = load_module_from_path("smartdns_bot_test", bot_file)

        # Stateful fake system command backend for ctl.py
        state: dict[str, Any] = {
            "fail_update": False,
            "fail_ipset_add": False,
            "services": {
                "oxidns": "active", "adguardhome": "inactive", "xray": "active",
                "nginx": "active", "doh-ipset-watcher": "active", "dot-ipset-watcher": "active",
                "smartdns-firewall": "active", "smartdns-tg-bot": "active",
            },
            "ipset": {
                "smartdns_clients": {"8.8.8.8": 86000},
                "smartdns_clients6": {"2001:4860:4860::8888": 85000},
                "dot_clients": {},
                "dot_clients6": {},
            },
            "restarted": [],
        }

        def fake_run_cmd(args: list[str], timeout: int = 30) -> tuple[int, str, str]:
            cmd = args[0]
            if cmd == str(ctl.UPDATE_GEOHIDE_BIN):
                if state["fail_update"]:
                    return 1, "", f"Simulated GitHub outage with secret {SECRET_CF_TOKEN}"
                base = {"openai.com", "claude.ai"}
                custom = set(ctl.read_domain_set(ctl.CUSTOM_ALLOW_FILE))
                merged = sorted(base | custom)
                ctl.GEOHIDE_LIST_FILE.write_text("\n".join(merged) + "\n", encoding="utf-8")
                ctl.XRAY_ROUTING_JSON.write_text(json.dumps({
                    "routing": {"rules": [{"type": "field", "domain": [f"domain:{d}" for d in merged]}]}
                }), encoding="utf-8")
                return 0, "ok", ""
            if cmd == "systemctl":
                sub, unit = args[1], args[2]
                if sub == "is-active":
                    st = state["services"].get(unit, "inactive")
                    return (0 if st == "active" else 3), st + "\n", ""
                if sub == "restart":
                    state["restarted"].append(unit)
                    state["services"][unit] = "active"
                    return 0, "", ""
            if cmd == "ipset":
                sub = args[1]
                if sub == "list":
                    sname = args[2]
                    if "-name" in args:
                        return (0 if sname in state["ipset"] else 1), sname + "\n", ""
                    members = state["ipset"].get(sname, {})
                    out = [f"Name: {sname}", "Members:"] + [f"{ip} timeout {ttl}" for ip, ttl in members.items()]
                    return 0, "\n".join(out) + "\n", ""
                if sub == "add":
                    if state["fail_ipset_add"]:
                        return 1, "", "ipset kernel error"
                    sname, ip = args[2], args[3]
                    state["ipset"].setdefault(sname, {})[ip] = 86400
                    return 0, "", ""
                if sub == "del":
                    sname, ip = args[2], args[3]
                    state["ipset"].setdefault(sname, {}).pop(ip, None)
                    return 0, "", ""
                if sub == "test":
                    sname, ip = args[2], args[3]
                    return (0 if ip in state["ipset"].get(sname, {}) else 1), "", ""
                if sub == "save":
                    lines = []
                    for sn, members in state["ipset"].items():
                        for ip, ttl in members.items():
                            lines.append(f"add {sn} {ip} timeout {ttl}")
                    return 0, "\n".join(lines) + "\n", ""
            if cmd == "dig":
                dom = args[-2]
                qtype = args[-1]
                active = set(ctl.read_domain_set(ctl.GEOHIDE_LIST_FILE))
                if qtype == "A":
                    return 0, ("203.0.113.10\n" if dom in active else "93.184.216.34\n"), ""
                return 0, "", ""
            if cmd == "nginx":
                return 0, "", ""
            if cmd == str(ctl.XRAY_BIN):
                return 0, "Configuration OK.\n", ""
            if cmd == "iptables":
                return 0, "", ""
            if cmd == "openssl":
                return 0, "notAfter=Dec 31 23:59:59 2027 GMT\n", ""
            return 1, "", f"unexpected cmd: {args}"

        ctl.run_cmd = fake_run_cmd

        # Direct CtlClient shim calling ctl.dispatch_request
        class LocalCtlClient:
            def call(self, user_id: int, action: str, params: dict[str, Any] | None = None, timeout: int = 95) -> dict[str, Any]:
                return ctl.dispatch_request({"user_id": user_id, "action": action, "params": params or {}})

        class FakeTelegramAPI:
            def __init__(self) -> None:
                self.sent: list[dict[str, Any]] = []
                self.edited: list[dict[str, Any]] = []
                self.docs: list[dict[str, Any]] = []
                self.callbacks: list[dict[str, Any]] = []
                self.next_download: tuple[bool, bytes | str] = (True, b"")

            def send_message(self, chat_id: int, text: str, reply_markup: dict[str, Any] | None = None) -> dict[str, Any]:
                self.sent.append({"chat_id": chat_id, "text": text, "kb": reply_markup})
                return {"ok": True}

            def edit_message(self, chat_id: int, msg_id: int, text: str, reply_markup: dict[str, Any] | None = None) -> dict[str, Any]:
                self.edited.append({"chat_id": chat_id, "msg_id": msg_id, "text": text, "kb": reply_markup})
                return {"ok": True}

            def answer_callback(self, callback_id: str, text: str = "", show_alert: bool = False) -> None:
                self.callbacks.append({"id": callback_id, "text": text, "alert": show_alert})

            def send_document_bytes(self, chat_id: int, filename: str, content_bytes: bytes, caption: str = "") -> dict[str, Any]:
                self.docs.append({"chat_id": chat_id, "filename": filename, "bytes": content_bytes, "caption": caption})
                return {"ok": True}

            def download_file_safely(self, file_id: str, max_bytes: int) -> tuple[bool, bytes | str]:
                return self.next_download

        logger = bot.setup_logger(fake_tok)
        try:
            fake_api = FakeTelegramAPI()
            tg = bot.SmartDnsBot(fake_api, LocalCtlClient(), logger)

            def send_msg(uid: int, text: str = "", doc: dict[str, Any] | None = None) -> None:
                msg: dict[str, Any] = {"from": {"id": uid}, "chat": {"id": uid}}
                if text:
                    msg["text"] = text
                if doc is not None:
                    msg["document"] = doc
                tg.handle_update({"message": msg})

            def click(uid: int, data: str) -> None:
                tg.handle_update({
                    "callback_query": {
                        "id": "cb1",
                        "from": {"id": uid},
                        "data": data,
                        "message": {"chat": {"id": uid}, "message_id": 10},
                    }
                })

            def last_cb_for(kb: dict[str, Any], prefix: str) -> str:
                for row in (kb or {}).get("inline_keyboard", []):
                    for btn in row:
                        if btn.get("callback_data", "").startswith(prefix):
                            return btn["callback_data"]
                raise AssertionError(f"Button {prefix} not found in {kb}")

            # --- 18.2 Authorization ---
            send_msg(ATTACKER_ID, "/start")
            assert "Доступ запрещён" in fake_api.sent[-1]["text"]
            click(ATTACKER_ID, "m:links")
            assert fake_api.callbacks[-1]["alert"] is True
            direct_bypass = ctl.dispatch_request({"user_id": ATTACKER_ID, "action": "get_links", "params": {}})
            assert direct_bypass["ok"] is False and "Unauthorized" in direct_bypass["error"]
            send_msg(ADMIN_ID, "/start")
            assert "Панель управления" in fake_api.sent[-1]["text"]
            print("PASS [18.2]: Authorization enforced on bot messages, callbacks & ctl.py backend")

            # --- 18.3 Single domain (valid, invalid, existing, cancel, rollback on error) ---
            click(ADMIN_ID, "dom:add_one")
            send_msg(ADMIN_ID, "not a domain; rm -rf /")
            assert "ровно один домен" in fake_api.sent[-1]["text"] or "Некорректных" in fake_api.sent[-1]["text"]

            click(ADMIN_ID, "dom:add_one")
            send_msg(ADMIN_ID, "newsite.example.com")
            preview_msg = fake_api.sent[-1]
            assert "Будет добавлено: <b>1</b>" in preview_msg["text"]
            cancel_cb = last_cb_for(preview_msg["kb"], "cf:no:")
            click(ADMIN_ID, cancel_cb)
            assert "newsite.example.com" not in ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8")

            # Apply failure -> rollback custom-allow.txt & redact secrets in error
            state["fail_update"] = True
            before_custom = ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8")
            click(ADMIN_ID, "dom:add_one")
            send_msg(ADMIN_ID, "rollback-test.org")
            yes_cb = last_cb_for(fake_api.sent[-1]["kb"], "cf:yes:")
            click(ADMIN_ID, yes_cb)
            err_reply = fake_api.edited[-1]["text"]
            assert "rolled back" in err_reply.lower()
            assert SECRET_CF_TOKEN not in err_reply
            assert ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8") == before_custom
            state["fail_update"] = False

            # Successful single domain add
            click(ADMIN_ID, "dom:add_one")
            send_msg(ADMIN_ID, "NEW-SINGLE.ORG")
            yes_cb = last_cb_for(fake_api.sent[-1]["kb"], "cf:yes:")
            click(ADMIN_ID, yes_cb)
            assert "Добавлено доменов: <b>1</b>" in fake_api.edited[-1]["text"]
            assert "new-single.org" in ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8")
            assert "new-single.org" in ctl.GEOHIDE_LIST_FILE.read_text(encoding="utf-8")
            # Duplicate confirmation click must be rejected cleanly
            click(ADMIN_ID, yes_cb)
            assert "устарела" in fake_api.edited[-1]["text"].lower() or "expired" in fake_api.edited[-1]["text"].lower()
            print("PASS [18.3]: Single domain add, cancel, double-click guard & failure rollback verified")

            # --- 18.4 Batch text domains ---
            batch_text = (
                "# Header comment\n"
                "alpha.example.org, beta.example.org; alpha.example.org\n"
                "\n"
                "  OPENAI.COM  \n"
                "x.com\n"
                "bad_domain!!!\n"
                "gamma.example.org # inline comment\n"
            )
            click(ADMIN_ID, "dom:add_batch")
            send_msg(ADMIN_ID, batch_text)
            b_msg = fake_api.sent[-1]
            assert "Дубликатов в списке: <b>1</b>" in b_msg["text"]
            assert "Уже присутствуют: <b>1</b>" in b_msg["text"]
            assert "Системные исключения: <b>1</b>" in b_msg["text"]
            assert "Некорректных записей: <b>1</b>" in b_msg["text"]
            assert "Будет добавлено: <b>3</b>" in b_msg["text"]
            # Preview pagination button works
            pv_cb = last_cb_for(b_msg["kb"], "pv:")
            click(ADMIN_ID, pv_cb)
            assert "alpha.example.org" in fake_api.edited[-1]["text"]
            yes_cb = last_cb_for(b_msg["kb"], "cf:yes:")
            click(ADMIN_ID, yes_cb)
            assert "Добавлено доменов: <b>3</b>" in fake_api.edited[-1]["text"]

            # Exceeding batch limit (max_batch_domains=10 in test config)
            click(ADMIN_ID, "dom:add_batch")
            send_msg(ADMIN_ID, "\n".join(f"d{i}.example.org" for i in range(15)))
            assert "maximum allowed" in fake_api.sent[-1]["text"].lower()
            print("PASS [18.4]: Batch text parsing, dedup, exclusions, preview pagination & limit enforcement")

            # --- 18.5 File upload (.txt, BOM, binary, magic header, bad ext, oversized, temp cleanup) ---
            click(ADMIN_ID, "dom:add_file")
            send_msg(ADMIN_ID, doc={"file_name": "archive.zip", "file_id": "f1", "file_size": 100})
            assert ".txt" in fake_api.sent[-1]["text"]

            send_msg(ADMIN_ID, doc={"file_name": "huge.txt", "file_id": "f2", "file_size": 999999})
            assert "большой" in fake_api.sent[-1]["text"].lower() or "large" in fake_api.sent[-1]["text"].lower()

            # Binary & fake .txt archive magic checks
            ok_b, err_b = bot.decode_and_validate_txt_bytes(b"abc\x00def", 262144)
            assert not ok_b and "Binary" in err_b
            ok_z, err_z = bot.decode_and_validate_txt_bytes(b"PK\x03\x04fakezip", 262144)
            assert not ok_z and "archive" in err_z.lower()
            ok_u, err_u = bot.decode_and_validate_txt_bytes(b"\xff\xfe\xfd", 262144)
            assert not ok_u and "UTF-8" in err_u
            ok_e, _ = bot.decode_and_validate_txt_bytes(b"", 262144)
            assert not ok_e

            # Valid UTF-8 with BOM + comments + valid domains
            bom_txt = "\ufeff# BOM file\nfile-one.org\nfile-two.org\nfile-one.org\n".encode("utf-8")
            fake_api.next_download = (True, bom_txt)
            send_msg(ADMIN_ID, doc={"file_name": "domains.txt", "file_id": "f3", "file_size": len(bom_txt)})
            f_msg = fake_api.sent[-1]
            assert "domains.txt" in f_msg["text"] and "Будет добавлено: <b>2</b>" in f_msg["text"]
            click(ADMIN_ID, last_cb_for(f_msg["kb"], "cf:yes:"))
            assert "file-one.org" in ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8")

            # Real download_file_safely temp cleanup on success AND on download failure
            real_api = bot.TelegramAPI(fake_tok, logger)
            real_api._request = lambda m, d=None, timeout=15: {"ok": True, "result": {"file_path": "documents/ok.txt", "file_size": 12}}
            orig_urlopen = bot.urllib.request.urlopen
            try:
                bot.urllib.request.urlopen = lambda req, timeout=25, context=None: io.BytesIO(b"ok.org\n")  # type: ignore[assignment]
                ok_d, data_d = real_api.download_file_safely("f_ok", 262144)
                assert ok_d and data_d == b"ok.org\n"
                assert list(bot.BOT_TMP_DIR.iterdir()) == [], "Temp file not deleted after success"

                def _raise_err(*_a: Any, **_k: Any) -> Any:
                    raise urllib.error.URLError(f"boom {fake_tok}")

                bot.urllib.request.urlopen = _raise_err  # type: ignore[assignment]
                ok_d2, err_d2 = real_api.download_file_safely("f_err", 262144)
                assert not ok_d2 and fake_tok not in str(err_d2)
                assert list(bot.BOT_TMP_DIR.iterdir()) == [], "Temp file not deleted after error"

                # Path traversal in Telegram file_path rejected
                real_api._request = lambda m, d=None, timeout=15: {"ok": True, "result": {"file_path": "../../etc/passwd", "file_size": 12}}
                ok_d3, err_d3 = real_api.download_file_safely("f_trav", 262144)
                assert not ok_d3 and "Unsafe" in str(err_d3)
            finally:
                bot.urllib.request.urlopen = orig_urlopen
            print("PASS [18.5]: .txt upload (UTF-8/BOM/limits/binary/archive/traversal) & temp cleanup verified")

            # --- D1-D5 Domain extras (list, search, DNS/Proxy check, export, history, remove) ---
            res_search = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "list_domains", "params": {"query": "file-one"}})
            assert res_search["ok"] and res_search["total"] == 1 and res_search["items"][0]["custom"] is True
            res_px = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "check_domain_proxy", "params": {"domain": "file-one.org"}})
            assert res_px["ok"] and res_px["proxied_ready"] is True
            click(ADMIN_ID, "dom:export")
            assert fake_api.docs[-1]["filename"] == "smartdns-custom-domains.txt"
            res_rm = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "remove_custom_domains", "params": {"domains": ["file-one.org", "file-two.org"]}})
            assert res_rm["ok"] and res_rm["removed_count"] == 2
            assert "file-one.org" not in ctl.CUSTOM_ALLOW_FILE.read_text(encoding="utf-8")
            res_hist = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "get_domain_history", "params": {}})
            assert res_hist["ok"] and len(res_hist["items"]) >= 3
            print("PASS [D1-D5]: Domain search, DNS/proxy check, export/backup, history & custom removal verified")

            # --- 18.6 Whitelist (IPv4, IPv6, invalid, CIDR, private, batch, remove, search, export, rollback) ---
            prev_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "preview_whitelist_ips", "params": {
                "ips": ["1.1.1.1", "2606:4700:4700::1111", "8.8.8.8", "192.168.1.1", "1.1.1.0/24", "not-an-ip"]
            }})
            assert prev_wl["ok"]
            wrep = prev_wl["report"]
            assert wrep["to_add_count"] == 2 and wrep["already_present_count"] == 1 and wrep["invalid_count"] == 3

            state["fail_ipset_add"] = True
            fail_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "apply_whitelist_ips", "params": {"ips": ["1.1.1.1"]}})
            assert not fail_wl["ok"] and "rolled back" in fail_wl["error"].lower()
            state["fail_ipset_add"] = False

            ok_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "apply_whitelist_ips", "params": {"ips": ["1.1.1.1", "2606:4700:4700::1111"]}})
            assert ok_wl["ok"] and ok_wl["added_count"] == 2
            assert "1.1.1.1" in state["ipset"]["smartdns_clients"]
            assert "2606:4700:4700::1111" in state["ipset"]["smartdns_clients6"]

            srch_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "list_whitelist", "params": {"query": "1.1.1"}})
            assert len(srch_wl["ipv4"]) == 1 and len(srch_wl["ipv6"]) == 0
            rem_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "remove_whitelist_ip", "params": {"ip": "1.1.1.1"}})
            assert rem_wl["ok"] and "1.1.1.1" not in state["ipset"]["smartdns_clients"]
            exp_wl = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "export_whitelist", "params": {}})
            assert exp_wl["ok"] and "2606:4700:4700::1111" in exp_wl["content"]
            print("PASS [18.6 + W1-W2]: Whitelist IPv4/IPv6 add/batch/remove/search/export/rollback verified")

            # --- 18.7 Links & Secret Protection ---
            click(ADMIN_ID, "m:links")
            links_text = fake_api.edited[-1]["text"]
            assert "abc1234567.example.test" in links_text
            assert f"https://example.test/resolve/{SECRET_DOH_PATH}" in links_text
            assert f"https://example.test/auth/{SECRET_DOH_PATH}" in links_text
            assert SECRET_CF_TOKEN not in links_text and SECRET_AGH_PASS not in links_text and fake_tok not in links_text
            print("PASS [18.7]: DoT/DoH/Web-Auth links rendered accurately without leaking tokens/passwords")

            # --- 18.8 Status, S1-S2 Services/Logs/Diagnostics & B1 Admins/Modules ---
            state["services"]["xray"] = "failed"
            click(ADMIN_ID, "m:status")
            st_text = fake_api.edited[-1]["text"]
            assert "failed" in st_text and "oxidns" in st_text and "2027" in st_text
            state["services"]["xray"] = "active"

            # Disallowed service restart blocked; allowlisted allowed
            bad_svc = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "restart_service", "params": {"service": "sshd"}})
            assert not bad_svc["ok"] and "not in the allowed list" in bad_svc["error"]
            ok_svc = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "restart_service", "params": {"service": "xray"}})
            assert ok_svc["ok"] and "xray" in state["restarted"]

            # Log path traversal blocked & secrets scrubbed
            bad_log = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "get_logs", "params": {"log": "../../etc/shadow"}})
            assert not bad_log["ok"]
            ok_log = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "get_logs", "params": {"log": "dns.log"}})
            joined_log = "\n".join(ok_log["lines"])
            assert SECRET_CF_TOKEN not in joined_log and SECRET_DOH_PATH not in joined_log and fake_tok not in joined_log
            assert "[REDACTED]" in joined_log and "[REDACTED_TG_TOKEN]" in joined_log

            diag = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "run_diagnostics", "params": {}})
            assert diag["ok"] and all(c["ok"] for c in diag["checks"])

            # B1: Secondary admin add/remove, primary admin protected, non-primary cannot manage admins
            add_adm = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "update_bot_config", "params": {"op": "add_admin", "target_user_id": str(SECOND_ADMIN_ID)}})
            assert add_adm["ok"] and SECOND_ADMIN_ID in add_adm["config"]["allowed_user_ids"]
            # Secondary admin now authorized for regular actions, but blocked from removing primary admin
            assert ctl.dispatch_request({"user_id": SECOND_ADMIN_ID, "action": "get_status", "params": {}})["ok"] is True
            deny_adm = ctl.dispatch_request({"user_id": SECOND_ADMIN_ID, "action": "update_bot_config", "params": {"op": "remove_admin", "target_user_id": str(ADMIN_ID)}})
            assert not deny_adm["ok"]
            deny_self = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "update_bot_config", "params": {"op": "remove_admin", "target_user_id": str(ADMIN_ID)}})
            assert not deny_self["ok"]
            rem_adm = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "update_bot_config", "params": {"op": "remove_admin", "target_user_id": str(SECOND_ADMIN_ID)}})
            assert rem_adm["ok"] and SECOND_ADMIN_ID not in rem_adm["config"]["allowed_user_ids"]
            assert ctl.dispatch_request({"user_id": SECOND_ADMIN_ID, "action": "get_status", "params": {}})["ok"] is False

            # Module toggle disables access cleanly
            tog = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "update_bot_config", "params": {"op": "toggle_module", "module": "links"}})
            assert tog["ok"] and tog["config"]["enabled_modules"]["links"] is False
            tg._cfg_mtime = -1.0  # force immediate reload in same-second test
            click(ADMIN_ID, "m:links")
            assert "отключён" in fake_api.edited[-1]["text"]
            print("PASS [18.8 + S1-S2 + B1]: Status, service allowlist, log redaction, diagnostics, admins & modules verified")

            # --- 18.9 Security: injection, unknown action, lock contention, operation expiry, audit redaction ---
            assert not ctl.dispatch_request({"user_id": ADMIN_ID, "action": "exec_shell", "params": {"cmd": "id"}})["ok"]
            inj = ctl.dispatch_request({"user_id": ADMIN_ID, "action": "preview_domains", "params": {
                "domains": ["$(id).com", "`whoami`.org", "a.com;cat /etc/passwd", "a.com\nEvil", "../../etc/passwd"]
            }})
            assert inj["ok"] and inj["report"]["to_add_count"] == 0 and inj["report"]["invalid_count"] == 5

            with ctl.CtlLock():
                try:
                    with ctl.CtlLock():
                        raise AssertionError("Concurrent lock should have been rejected")
                except RuntimeError as exc:
                    assert "in progress" in str(exc).lower()

            # Expired operation rejected
            exp_op = tg.create_op(ADMIN_ID, "add_domains", {"report": {"to_add": ["expired.org"]}, "source": "t"})
            tg.pending_ops[exp_op]["expires_at"] = time.time() - 10
            click(ADMIN_ID, f"cf:yes:{exp_op}")
            assert "устарела" in fake_api.edited[-1]["text"].lower() or "expired" in fake_api.edited[-1]["text"].lower()

            # Audit log contains zero secrets
            audit_raw = ctl.BOT_AUDIT_LOG.read_text(encoding="utf-8")
            assert fake_tok not in audit_raw and SECRET_CF_TOKEN not in audit_raw and SECRET_DOH_PATH not in audit_raw
            print("PASS [18.9]: Injection rejection, lock contention, op expiry & zero-secret audit log verified")
        finally:
            for h in list(logger.handlers):
                try:
                    h.close()
                except Exception:
                    pass
            logger.handlers.clear()

    print("\nALL TELEGRAM BOT v4.0.0 FUNCTIONAL, SECURITY & IMMUTABILITY TESTS PASSED")


if __name__ == "__main__":
    main()
