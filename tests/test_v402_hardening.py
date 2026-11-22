#!/usr/bin/env python3
"""Regression tests for SmartDNS Installer v4.0.2-stealth hardening & CI fixes."""

from __future__ import annotations

import re
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "smartdns-installer.sh"


def main() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    # 1. Version metadata strictly synchronized across header, constant & embedded bot
    m_ver = re.search(r'^INSTALLER_VERSION="([^"]+)"$', text, flags=re.M)
    assert m_ver, "INSTALLER_VERSION not found"
    ver = m_ver.group(1)
    assert ver == "4.0.2-stealth", f"Unexpected version: {ver}"
    assert f"# Version: {ver}" in text, "Header # Version mismatch"
    assert f"SmartDNS Telegram Bot (v{ver})." in text, "ctl.py docstring version mismatch"
    assert f"daemon for SmartDNS (v{ver})." in text, "bot.py docstring version mismatch"
    print(f"PASS: Version metadata synchronized ({ver})")

    # 2. No global chmod on system root directories in setup_users_and_dirs or perform_rollback
    assert "chmod 0755 / /etc /var" not in text
    print("PASS: Global system-directory chmod removed from setup_users_and_dirs & perform_rollback")

    # 3. TRANSACTION_ACTIVE=1 set before setup_users_and_dirs in run_install
    ri_idx = text.index("run_install() {")
    ri_block = text[ri_idx : ri_idx + 2200]
    assert ri_block.index("TRANSACTION_ACTIVE=1") < ri_block.index("setup_users_and_dirs")
    print("PASS: TRANSACTION_ACTIVE=1 activated before setup_users_and_dirs")

    # 4. perform_rollback verifies checksums.sha256, restores managed paths, and tracks firewall restore errors
    rb_idx = text.index("perform_rollback() {")
    rb_end = text.index("\n}\n", rb_idx)
    rb_block = text[rb_idx:rb_end]
    assert "sha256sum -c checksums.sha256" in rb_block
    assert 'cp -a "${target_backup}/fs/." /' not in rb_block
    assert 'iptables-restore < "${target_backup}/iptables.v4" || true' not in rb_block
    assert "restore_errors" in rb_block
    print("PASS: perform_rollback verifies checksums, avoids global overwrite & logs restore errors")

    # 5. Pinned acme.sh release tag + SHA-256 and mandatory OxiDNS SHA-256 verification
    assert "refs/heads/master.tar.gz" not in text
    assert re.search(r'^readonly ACME_SH_SHA256="[0-9a-f]{64}"$', text, flags=re.M)
    assert re.search(r'^readonly OXIDNS_DEFAULT_SHA256="[0-9a-f]{64}"$', text, flags=re.M)
    assert '"${acme_act_sha}" != "${ACME_SH_SHA256}"' in text
    assert '"${expected_sha256}" != "${oxi_act_sha}"' in text
    print("PASS: acme.sh & OxiDNS pinned with mandatory SHA-256 verification")

    # 6. No predictable /tmp/bad-routing.json in run_test_suite
    assert 'local tmp_bad="/tmp/bad-routing.json"' not in text
    assert "mktemp -d /run/smartdns-test.XXXXXX" in text
    assert 'rm -rf -- "${test_tmp_dir}"' in text
    print("PASS: run_test_suite uses secure 0700 mktemp directory")

    # 7. READMEs use releases/latest + SHA256SUMS.txt (no stale hardcoded main hash)
    for rname in ("README.md", "README_EN.md"):
        rt = (REPO_ROOT / rname).read_text(encoding="utf-8")
        assert "releases/latest/download/SHA256SUMS.txt" in rt
        assert "sha256sum -c SHA256SUMS.txt" in rt
        assert "9f9e36f45584bfcbd52db76885a59100095001c5a4d6e5b06b0b5b6829862d6a" not in rt
    print("PASS: README.md & README_EN.md verify Latest Release via SHA256SUMS.txt")

    # 8. CI workflows execute all 5 Python test suites
    for wf in (".github/workflows/shellcheck.yml", ".github/workflows/release.yml"):
        wt = (REPO_ROOT / wf).read_text(encoding="utf-8")
        for tname in (
            "test_v401_audit_fixes.py",
            "test_v402_hardening.py",
            "test_telegram_bot.py",
            "test_hostname_profile.py",
            "test_nspawn_second_ip.py",
        ):
            assert tname in wt, f"{tname} missing in {wf}"
    print("PASS: GitHub Actions (shellcheck.yml & release.yml) run all 5 Python test suites")
    print("\nALL v4.0.2-stealth HARDENING & CI TESTS PASSED")


if __name__ == "__main__":
    main()
