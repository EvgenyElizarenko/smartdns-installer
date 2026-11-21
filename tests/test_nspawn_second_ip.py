from pathlib import Path
import os
import re
import subprocess
import tempfile

repo_root = Path(__file__).resolve().parents[1]
installer = Path(os.environ.get("SMARTDNS_INSTALLER", str(repo_root / "smartdns-installer-v3.1.0-stealth.sh")))
v30_baseline = (repo_root / "smartdns-installer-v3.0-stealth.sh" if (repo_root / "smartdns-installer-v3.0-stealth.sh").exists() else repo_root / "old" / "smartdns-installer-v3.0-stealth.sh")

source = installer.read_text(encoding="utf-8").replace("\r\n", "\n")
assert source.count('main "$@"') == 1, "Expected single main \"$@\" entrypoint"
assert 'INSTALLER_VERSION="3.1.0-stealth"' in source, "Version must be 3.1.0-stealth"
assert 'readonly SCRIPT_NAME="smartdns-installer-v3.1.0-stealth.sh"' in source, "SCRIPT_NAME must match v3.1.0"

# 1. Verify Mode [2] & Mode [3] menu structure and zero overlapping item numbers (0..18)
menu_start = source.index("run_main_launcher_menu() {")
menu_end = source.index("\n}\n", menu_start) + 3
menu_src = source[menu_start:menu_end]
assert "[ 2] Установка SmartDNS + SNI Proxy на выделенный сервер" in menu_src
assert "[ 3] Установка SmartDNS + SNI Proxy на сервер с 2мя IP" in menu_src
assert "(--install-on-second-IP)" in menu_src
assert "(--preflight-second-IP)" in menu_src
for num in range(1, 19):
    assert re.search(rf"^\s*{num}\)", menu_src, flags=re.M), f"Missing menu handler for option {num}"
print("PASS: Menu structure [0-18] has dedicated Mode [2], dual-IP Mode [3], and complete 1-to-1 handlers")

# 2. Verify host networking script syntax (both iptables/UFW and nftables branches)
net_start = source.index("#!/usr/bin/env bash\nset -Eeuo pipefail\n\nACTION=\"${1:-status}\"")
net_end = source.index("\nEOF_HOST_NET", net_start)
net_script = source[net_start:net_end]
assert "SMARTDNS_NSPAWN_PRE" in net_script and "SMARTDNS_NSPAWN_POST" in net_script
assert "SMARTDNS_NSPAWN_FWD" in net_script and "SMARTDNS_NSPAWN_IN" in net_script
assert "table ip smartdns_nspawn_nat" in net_script and "table inet smartdns_nspawn_filter" in net_script
assert "iptables -F" not in net_script and "ufw reset" not in net_script and "nft flush ruleset" not in net_script
with tempfile.TemporaryDirectory(prefix="smartdns-v310-test-") as folder:
    temp = Path(folder)
    host_net = temp / "host-net.sh"
    host_net.write_text(net_script, encoding="utf-8", newline="\n")
    subprocess.run(["bash", "-n", str(host_net)], check=True)
    print("PASS: Host network/firewall script syntax OK (iptables + nftables, no global flush)")

    library = temp / "library.sh"
    lib_src = source.replace('main "$@"', "")
    lib_src = lib_src.replace(
        'readonly SETTINGS_FILE="${STATE_DIR}/settings"',
        f'readonly SETTINGS_FILE="{temp.as_posix()}/host-settings"',
    ).replace(
        'readonly NSPAWN_MACHINE_DIR="/var/lib/machines/${NSPAWN_CONTAINER_NAME}"',
        f'readonly NSPAWN_MACHINE_DIR="{temp.as_posix()}/machines/smartdns-v3.1.0"',
    ).replace(
        'readonly NSPAWN_CONF_FILE="/etc/systemd/nspawn/${NSPAWN_CONTAINER_NAME}.nspawn"',
        f'readonly NSPAWN_CONF_FILE="{temp.as_posix()}/nspawn.conf"',
    ).replace(
        'readonly NSPAWN_ENV_FILE="${NSPAWN_STATE_DIR}/${NSPAWN_CONTAINER_NAME}.env"',
        f'readonly NSPAWN_ENV_FILE="{temp.as_posix()}/nspawn.env"',
    )
    library.write_text(lib_src, encoding="utf-8", newline="\n")

    # Mock helper block for deterministic read-only audit conflict tests (all 25 scenarios)
    base_mocks = f'''
source "{library.as_posix()}"
trap - ERR
ACTION_MODE="preflight"
detect_environment() {{
    OS_ID="debian"; OS_VERSION_ID="13"; OS_CODENAME="trixie"; OS_PRETTY="Debian GNU/Linux 13"
    CPU_ARCH="x86_64"; KERNEL_VER="6.12.0"; MEM_TOTAL_MB=2048; DISK_FREE_MB=10000
    PRIMARY_IFACE="eth0"; SERVER_IPV4="203.0.113.10"; SERVER_IPV6=""; HAS_IPV6=0
    IPTABLES_BACKEND="iptables-nft"; DOCKER_PRESENT=0
}}
command() {{
    if [[ "$1" == "-v" ]]; then
        case "$2" in
            systemd-nspawn|machinectl|debootstrap) [[ "${{MOCK_NO_NSPAWN:-0}}" == "1" ]] && return 1 || return 0 ;;
            unshare) [[ "${{MOCK_UNSHARE_FAIL:-0}}" == "1" ]] && return 0 || return 0 ;;
            ufw) [[ "${{MOCK_FW:-ufw}}" == "ufw" ]] && return 0 || return 1 ;;
            nft) [[ "${{MOCK_FW:-ufw}}" == "nftables" ]] && return 0 || return 1 ;;
            iptables) [[ "${{MOCK_FW:-ufw}}" == "nftables" ]] && return 1 || return 0 ;;
        esac
    fi
    builtin command "$@"
}}
unshare() {{ [[ "${{MOCK_UNSHARE_FAIL:-0}}" == "1" ]] && return 1 || return 0; }}
ufw() {{ echo "Status: active"; }}
nft() {{ echo "table inet custom_host"; }}
iptables() {{
    if [[ "$*" == *"-S SMARTDNS_PREROUTING"* ]]; then
        [[ "${{MOCK_HOST_SMARTDNS_NAT:-0}}" == "1" ]] && return 0 || return 1
    fi
    if [[ "$*" == *"--version"* ]]; then echo "iptables v1.8.10 (nf_tables)"; return 0; fi
    return 0
}}
machinectl() {{
    if [[ "$1" == "show" ]]; then
        [[ "${{MOCK_FOREIGN_CONTAINER:-0}}" == "1" ]] && return 0 || return 1
    fi
    if [[ "$1" == "list" ]]; then
        [[ -n "${{MOCK_OTHER_CONTAINERS:-}}" ]] && echo "${{MOCK_OTHER_CONTAINERS}}"
        return 0
    fi
    return 0
}}
systemctl() {{
    if [[ "$1" == "is-active" ]]; then
        local svc="${{3:-}}"
        [[ ",${{MOCK_ACTIVE_SVCS:-}}," == *",${{svc}},"* ]] && return 0 || return 1
    fi
    return 0
}}
ip() {{
    if [[ "$*" == "-4 route show default" ]]; then
        echo "default via 203.0.113.1 dev eth0 src 203.0.113.10"
        return 0
    fi
    if [[ "$*" == "-4 -o addr show scope global" ]]; then
        if [[ "${{MOCK_SINGLE_IP:-0}}" == "1" ]]; then
            echo "2: eth0    inet 203.0.113.10/24 brd 203.0.113.255 scope global eth0"
        else
            echo "2: eth0    inet 203.0.113.10/24 brd 203.0.113.255 scope global eth0"
            echo "2: eth0    inet 203.0.113.11/24 brd 203.0.113.255 scope global secondary eth0"
        fi
        return 0
    fi
    if [[ "$*" == "-6 -o addr show scope global" ]]; then
        echo "2: eth0    inet6 2001:db8::11/64 scope global eth0"
        return 0
    fi
    return 0
}}
ss() {{
    if [[ "$*" == *"-lntup"* ]]; then
        printf '%s\n' "${{MOCK_SS_TCP:-}}"
    fi
    return 0
}}
'''

    def run_audit(label, extra_env, expect_state, expect_grep=""):
        env = dict(os.environ, SCRIPT_LANG="en")
        env.update(extra_env)
        # Override Linux-only /run/systemd/system & /sys/fs/cgroup checks when running unit tests on Windows
        script = base_mocks + '''
if [[ ! -d /run/systemd/system ]]; then
    # Running mock unit test on non-systemd host (e.g. Windows Git Bash): simulate systemd/cgroup/ns flags
    eval "$(declare -f run_preflight_second_ip | sed 's|\\[\\[ -d /run/systemd/system \\]\\]|true|g; s|\\[\\[ -d /sys/fs/cgroup \\]\\]|true|g; s|\\[\\[ -e /proc/self/ns/net && -e /proc/self/ns/pid && -e /proc/self/ns/mnt \\]\\]|true|g')"
fi
rc=0
run_preflight_second_ip 0 || rc=$?
echo "FINAL_STATE=${NSPAWN_AUDIT_STATE} RC=${rc} FW=${NSPAWN_HOST_FW_BACKEND}"
'''
        res = subprocess.run(["bash", "-c", script], stdin=subprocess.DEVNULL, env=env, capture_output=True, text=True, timeout=20)
        out = res.stdout + res.stderr
        assert f"FINAL_STATE={expect_state}" in out, (label, expect_state, out)
        if expect_grep:
            assert expect_grep in out, (label, expect_grep, out)
        print("PASS:", label)
        return out

    # Scenarios 1-19 (Section 19.3 conflict matrix)
    run_audit("1.  Port 443 free on both IPs -> READY", {}, "READY")
    run_audit("2.  Port 443 occupied on IP #1 only -> READY",
              {"MOCK_SS_TCP": 'tcp LISTEN 0 511 203.0.113.10:443 0.0.0.0:* users:(("nginx",pid=100,fd=6))'},
              "READY", "Free on IP #2")
    run_audit("3.  Port 443 wildcard 0.0.0.0 -> WARNINGS (user confirmation required)",
              {"MOCK_SS_TCP": 'tcp LISTEN 0 511 0.0.0.0:443 0.0.0.0:* users:(("nginx",pid=100,fd=6))'},
              "WARNINGS", "Wildcard listener")
    run_audit("4.  Port 443 IPv6 wildcard [::] -> WARNINGS",
              {"MOCK_SS_TCP": 'tcp LISTEN 0 511 [::]:443 [::]:* users:(("nginx",pid=100,fd=6))'},
              "WARNINGS", "Wildcard listener")
    run_audit("5.  Port 853 occupied on IP #1 only -> READY",
              {"MOCK_SS_TCP": 'tcp LISTEN 0 511 203.0.113.10:853 0.0.0.0:* users:(("xray",pid=200,fd=7))'},
              "READY", "Free on IP #2")
    run_audit("6.  Port 853 occupied directly on IP #2 -> BLOCKED",
              {"MOCK_SS_TCP": 'tcp LISTEN 0 511 203.0.113.11:853 0.0.0.0:* users:(("xray",pid=200,fd=7))'},
              "BLOCKED", "OCCUPIED directly on IP #2")
    run_audit("7.  Second IP missing (single IP server) -> BLOCKED",
              {"MOCK_SINGLE_IP": "1"}, "BLOCKED", "Fewer than 2 global IPv4")
    run_audit("8.  Second IP invalid syntax -> BLOCKED",
              {"SECOND_IP_ARG": "999.0.0.1"}, "BLOCKED", "invalid syntax")
    run_audit("9.  Second IP does not belong to server -> BLOCKED",
              {"SECOND_IP_ARG": "198.51.100.77"}, "BLOCKED", "not assigned to any non-virtual interface")
    run_audit("10. systemd-nspawn missing -> WARNINGS (lists systemd-container, no auto-install)",
              {"MOCK_NO_NSPAWN": "1"}, "WARNINGS", "systemd-container")
    run_audit("11. namespaces unavailable (cannot launch container) -> BLOCKED",
              {"MOCK_UNSHARE_FAIL": "1"}, "BLOCKED", "Linux namespaces")
    run_audit("12. Foreign container with target name exists -> BLOCKED",
              {"MOCK_FOREIGN_CONTAINER": "1"}, "BLOCKED", "NOT managed by SmartDNS Installer")
    run_audit("13. Host firewall UFW detected cleanly",
              {"MOCK_FW": "ufw"}, "READY", "FW=ufw")
    run_audit("14. Host firewall nftables detected cleanly",
              {"MOCK_FW": "nftables"}, "READY", "FW=nftables")
    run_audit("15-17. Active host Nginx + Xray + AdGuardHome on IP #1 -> READY (untouched)",
              {"MOCK_ACTIVE_SVCS": "nginx,xray,adguardhome",
               "MOCK_SS_TCP": 'tcp LISTEN 0 511 203.0.113.10:443 0.0.0.0:* users:(("nginx",pid=100,fd=6))'},
              "READY", "nginx: Active")
    run_audit("18. Existing host SmartDNS active SMARTDNS_PREROUTING -> BLOCKED",
              {"MOCK_HOST_SMARTDNS_NAT": "1"}, "BLOCKED", "SMARTDNS_PREROUTING")
    run_audit("19. Other systemd-nspawn containers present -> READY (coexistence)",
              {"MOCK_OTHER_CONTAINERS": "other-app container systemd-nspawn debian 13"},
              "READY", "other-app")

    # 20. Non-interactive CLI help check
    proc = subprocess.Popen(
        ["bash", str(installer), "--help"],
        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
        env=dict(os.environ, SCRIPT_LANG="en"), text=True,
    )
    try:
        proc.wait(timeout=5)
        out_help = proc.stdout.read()
        assert proc.returncode == 0
        assert "--install-on-second-IP" in out_help and "--preflight-second-IP" in out_help and "--target" in out_help
    finally:
        if proc.poll() is None:
            proc.kill()
        proc.stdin.close()
    print("PASS: CLI --help documents --install-on-second-IP, --preflight-second-IP, and --target")

    # 21. Unknown CLI option cleanly rejected
    res_bad = subprocess.run(
        ["bash", str(installer), "--nonexistent-flag-v310"],
        stdin=subprocess.DEVNULL, env=dict(os.environ, SCRIPT_LANG="en"),
        capture_output=True, text=True, timeout=5,
    )
    assert res_bad.returncode != 0
    print("PASS: Unknown CLI flag rejected cleanly")

    # 22. Invalid --target rejected
    res_tgt = subprocess.run(
        ["bash", str(installer), "--target", "docker", "--status"],
        stdin=subprocess.DEVNULL, env=dict(os.environ, SCRIPT_LANG="en"),
        capture_output=True, text=True, timeout=5,
    )
    assert res_tgt.returncode != 0
    print("PASS: Invalid --target rejected cleanly")

    # 23. Web-Auth /auth/ page matches procedurally generated cover site (brand, initials, city, CSS; no Studio Nord)
    auth_check_script = r'''
source "${TEST_LIB}"
trap - ERR
ROOT_DOMAIN="cover-check.example.net"
SERVER_IPV4="203.0.113.11"
WEB_AUTH_SNIPPET_FILE="${TEST_SNIPPET}"
log_info_tr() { :; }
log_warn_tr() { :; }
log_error_tr() { :; }
if [[ "$(id -u)" -ne 0 ]]; then
    chown() { :; }
    install() {
        local -a args=()
        while [[ $# -gt 0 ]]; do
            case "$1" in
                -o|-g) shift 2 ;;
                *) args+=("$1"); shift ;;
            esac
        done
        command install "${args[@]}"
    }
fi
generate_procedural_cover_site "${TEST_COVER}" "1"
[[ -s "${WEB_AUTH_SNIPPET_FILE}" ]]
[[ ! -e "${TEST_COVER}/.web-auth-snippet.tmp" ]]
brand="$(sed -nE 's#.*<span class="brand-badge">[^<]+</span><span>([^<]+)</span>.*#\1#p' "${TEST_COVER}/404.html" | head -n1)"
initials="$(sed -nE 's#.*<span class="brand-badge">([^<]+)</span>.*#\1#p' "${TEST_COVER}/404.html" | head -n1)"
city="$(sed -nE 's#.*<div class="wrap footer-inner"><span>[^<]+</span><span>([^<]+)</span>.*#\1#p' "${TEST_COVER}/404.html" | head -n1)"
[[ -n "${brand}" && -n "${initials}" && -n "${city}" ]]
grep -Fq "${brand}" "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq "<span class=\"brand-badge\">${initials}</span>" "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq "${city}" "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq 'href="/assets/style.css"' "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq '$remote_addr' "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq 'Session Synchronized' "${WEB_AUTH_SNIPPET_FILE}"
! grep -Fqi 'Studio Nord' "${WEB_AUTH_SNIPPET_FILE}"

# Fallback reconstruction from existing 404.html (e.g. --update migration)
rm -f "${WEB_AUTH_SNIPPET_FILE}"
ensure_web_auth_nginx_snippet "${TEST_COVER}" "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq "${brand}" "${WEB_AUTH_SNIPPET_FILE}"
grep -Fq "${city}" "${WEB_AUTH_SNIPPET_FILE}"
'''
    auth_env = dict(
        os.environ,
        SCRIPT_LANG="en",
        TEST_LIB=library.as_posix(),
        TEST_SNIPPET=(temp / "nginx-web-auth.conf").as_posix(),
        TEST_COVER=(temp / "cover-site").as_posix(),
    )
    res_auth = subprocess.run(
        ["bash", "-c", auth_check_script],
        stdin=subprocess.DEVNULL, env=auth_env,
        capture_output=True, text=True, timeout=20,
    )
    assert res_auth.returncode == 0, (res_auth.stdout, res_auth.stderr)
    regen_start = source.index("run_regenerate_cover() {")
    regen_end = source.index("\n}\n", regen_start) + 3
    assert 'source "${SECRETS_FILE}"' in source[regen_start:regen_end], "run_regenerate_cover must load SECRETS_FILE"
    print("PASS: Web-Auth /auth/ page dynamically matches generated cover site branding & CSS")

    # 24. Empty --second-ip "" rejected & amn0 excluded as virtual interface
    res_empty_ip = subprocess.run(
        ["bash", str(installer), "--preflight-second-IP", "--second-ip", ""],
        stdin=subprocess.DEVNULL, env=dict(os.environ, SCRIPT_LANG="en"),
        capture_output=True, text=True, timeout=5,
    )
    assert res_empty_ip.returncode != 0, "Empty --second-ip must be rejected"
    res_amn = subprocess.run(
        ["bash", "-c", f'source "{library.as_posix()}"; trap - ERR; nspawn_is_virtual_iface amn0'],
        stdin=subprocess.DEVNULL, env=dict(os.environ, SCRIPT_LANG="en"),
        capture_output=True, text=True, timeout=5,
    )
    assert res_amn.returncode == 0, "amn0 must be recognized as virtual interface"
    print("PASS: Empty --second-ip rejected and amn0 excluded from candidate host IPs")

print("ALL DUAL-IP SYSTEMD-NSPAWN UNIT & CONFLICT TESTS PASSED")
