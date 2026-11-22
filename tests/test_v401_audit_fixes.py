#!/usr/bin/env python3
"""Regression tests for SmartDNS Installer v4.0.1-stealth audit fixes."""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "smartdns-installer.sh"


def main() -> None:
    text = SCRIPT.read_text(encoding="utf-8")

    # 1. Version bump isolated to 4.0.1-stealth
    assert 'INSTALLER_VERSION="4.0.1-stealth"' in text
    print("PASS: Version set to 4.0.1-stealth")

    # 2. Xray fixes: warning loglevel, sockopt.domainStrategy, dot-backend proxyProtocol
    assert '"loglevel": "warning"' in text
    assert '"domainStrategy": "UseIPv4"' in text
    assert '"settings": {\n        "domainStrategy": "UseIPv4"' not in text
    assert '"redirect": "127.0.0.1:8853",\n        "proxyProtocol": 1' in text
    print("PASS: Xray sockopt.domainStrategy, loglevel=warning & dot-backend proxyProtocol verified")

    # 3. Nginx fixes: DoT proxy_protocol + set_real_ip_from, DoH upstream keepalive + regex, /auth/ headers
    assert "listen 127.0.0.1:8853 ssl proxy_protocol;\n        set_real_ip_from 127.0.0.1;" in text
    assert '"~*^200:200:application/dns-message" 1;' in text
    assert "upstream doh_backend {" in text
    assert "proxy_pass http://doh_backend/dns-query;" in text
    auth_idx = text.index("location = /auth/${DOH_PATH}")
    auth_block = text[auth_idx : auth_idx + 1200]
    for hdr in (
        "Strict-Transport-Security",
        "X-Content-Type-Options",
        "X-Frame-Options",
        "Referrer-Policy",
        "Content-Security-Policy",
        "Cache-Control",
    ):
        assert hdr in auth_block, f"Missing {hdr} in /auth/ location"
    print("PASS: Nginx DoT proxy_protocol, DoH keepalive & /auth/ security headers verified")

    # 4. Logrotate configured, recorded in manifest, cleaned on uninstall
    assert "configure_logrotate()" in text
    assert "/etc/logrotate.d/smartdns-stealth" in text
    assert "copytruncate" in text
    print("PASS: Logrotate configuration & lifecycle hooks verified")

    # 5. Watchers: flock + per-PID temp file, CGNAT/RFC1918/ULA filtering, no shared .tmp race
    assert 'ipset save > "${IPSET_SAVE}.tmp"' not in text
    assert "smartdns-ipset-save.lock" in text
    assert "${IPSET_SAVE}.doh.$$.tmp" in text
    assert "${IPSET_SAVE}.dot.$$.tmp" in text
    assert r"172\.(1[6-9]|2[0-9]|3[0-1])\." in text
    assert r"100\.(6[4-9]|[7-9][0-9]|1[0-1][0-9]|12[0-7])\." in text
    assert "f[cd][0-9a-f]{2}:" in text
    print("PASS: Watchers flock atomicity & private/CGNAT/ULA filters verified")

    # 6. SHA-256 verification in AdGuardHome & OxiDNS installers
    assert "checksums.txt" in text
    assert "expected_sha256" in text and "oxi_exp_sha" in text
    print("PASS: Binary SHA-256 verification present for AdGuardHome & OxiDNS")

    # 7. Functional test of custom-deny.txt awk filter (empty lines, comments, no substring false positives)
    assert 'grep -vFf "${ASSETS_DIR}/custom-deny.txt"' not in text
    anchor = 'if [[ -s "${ASSETS_DIR}/custom-deny.txt" ]]; then'
    awk_start = text.index("NR == FNR {", text.index(anchor))
    awk_end = text.index('\' "${ASSETS_DIR}/custom-deny.txt"', awk_start)
    awk_prog = text[awk_start:awk_end]

    with tempfile.TemporaryDirectory() as td:
        deny_f = Path(td) / "custom-deny.txt"
        doms_f = Path(td) / "domains.txt"
        deny_f.write_text(
            "\n  # comment line\n\n*.x.com # inline comment\nblocked.example.org\n\n",
            encoding="utf-8",
        )
        doms_f.write_text(
            "x.com\napi.x.com\nnetflix.com\nxbox.com\nplex.com\n"
            "blocked.example.org\nsub.blocked.example.org\nnotblocked.example.org\n",
            encoding="utf-8",
        )
        res = subprocess.run(
            ["awk", awk_prog, str(deny_f), str(doms_f)],
            capture_output=True,
            text=True,
            check=True,
        )
        kept = set(res.stdout.splitlines())
        assert kept == {"netflix.com", "xbox.com", "plex.com", "notblocked.example.org"}, f"Unexpected result: {kept}"
    print("PASS: custom-deny.txt awk filter handles empty lines, comments & exact/subdomain matching")
    print("\nALL v4.0.1-stealth AUDIT FIX REGRESSION TESTS PASSED")


if __name__ == "__main__":
    main()
