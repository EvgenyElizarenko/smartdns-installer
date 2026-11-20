from pathlib import Path
import os
import re
import subprocess
import sys
import tempfile

repo_root = Path(__file__).resolve().parents[1]
installer = Path(os.environ.get("SMARTDNS_INSTALLER", str(repo_root / "smartdns-installer-v3.0.1-stealth.sh")))
v30_baseline = repo_root / "smartdns-installer-v3.0-stealth.sh"
live = os.environ.get("SMARTDNS_LIVE_TESTS") == "1"

os.environ.setdefault("PROVIDER_HOSTNAME", "dns.example.net")
os.environ.setdefault("PUBLIC_IPV4", "192.0.2.25")

source = installer.read_text(encoding="utf-8").replace("\r\n", "\n")
assert source.count('main "$@"') == 1, "Expected single main \"$@\" entrypoint"

def extract_function(content: str, fn_name: str) -> str:
    lines = content.splitlines(keepends=True)
    for idx, ln in enumerate(lines):
        if ln.startswith(f"{fn_name}() {{"):
            body = [ln]
            heredoc = None
            j = idx + 1
            while j < len(lines):
                cur = lines[j]
                body.append(cur)
                if heredoc is not None:
                    if cur.rstrip("\r\n") == heredoc:
                        heredoc = None
                else:
                    m = re.search(r"(?<!<)<<(?!<)-?\s*['\"]?([A-Za-z_][A-Za-z0-9_]*)['\"]?(?:\s|$)", cur)
                    if m:
                        heredoc = m.group(1)
                    elif cur.strip() == "}":
                        break
                j += 1
            return "".join(body)
    raise AssertionError(f"Function not found: {fn_name}")

# 1. Regression check: Cloudflare renewal functions untouched vs v3.0 baseline
if v30_baseline.exists():
    v30_source = v30_baseline.read_text(encoding="utf-8").replace("\r\n", "\n")
    for fn in (
        "sync_cloudflare_dns_records",
        "install_tls_verification_helper",
        "configure_cert_auto_renewal",
        "issue_wildcard_certificate",
    ):
        assert extract_function(v30_source, fn) == extract_function(source, fn), f"Cloudflare function modified: {fn}"
    print("PASS: Cloudflare renewal functions are byte-for-byte identical to v3.0-stealth")

with tempfile.TemporaryDirectory(prefix="smartdns-hostname-test-") as folder:
    temp = Path(folder)
    library = temp / "library.sh"
    lib_src = source.replace('main "$@"', "")
    lib_src = lib_src.replace(
        'readonly SETTINGS_FILE="${STATE_DIR}/settings"',
        f'readonly SETTINGS_FILE="{temp.as_posix()}/settings"',
    ).replace(
        'readonly SECRETS_FILE="${STATE_DIR}/secrets.env"',
        f'readonly SECRETS_FILE="{temp.as_posix()}/secrets.env"',
    )
    library.write_text(lib_src, encoding="utf-8", newline="\n")
    prefix = f'source "{library.as_posix()}"\ntrap - ERR\nACTION_MODE=preflight\n'

    def check(label, script, succeeds=True, inputs=None, initialize=True):
        env = dict(os.environ, SCRIPT_LANG="en")
        if inputs is not None:
            for key in [
                "INSTALL_PROFILE",
                "PROVIDER_HOSTNAME",
                "PUBLIC_IPV4",
                "PUBLIC_IPV6",
                "HOSTNAME_CERT_LINEAGE",
                "HOSTNAME_ACME_WEBROOT",
                "HOSTNAME_RENEWAL_CONF",
            ]:
                env.pop(key, None)
            env.update(inputs)
        setup = "initialize_hostname_profile\n" if initialize else ""
        result = subprocess.run(
            ["bash", "-c", prefix + setup + script],
            stdin=subprocess.DEVNULL,
            env=env,
            capture_output=True,
            text=True,
            timeout=25,
        )
        assert (result.returncode == 0) == succeeds, (label, result.returncode, result.stdout, result.stderr)
        print("PASS:", label)
        return result

    generic = {"PROVIDER_HOSTNAME": "dns.example.net", "PUBLIC_IPV4": "192.0.2.25"}

    # Input derivation, IPv6, custom paths
    check(
        "generic environment inputs derive all hostname paths",
        '''
[[ "$INSTALL_PROFILE" == hostname && "$TLS_MODE" == existing-certbot && "$DNS_PROVIDER" == external ]]
[[ "$ROOT_DOMAIN" == dns.example.net && "$DOT_HOST" == dns.example.net && "$SERVER_IPV4" == 192.0.2.25 ]]
[[ "$HOSTNAME_CERT_LINEAGE" == /etc/letsencrypt/live/dns.example.net ]]
[[ "$HOSTNAME_ACME_WEBROOT" == /var/www/dns.example.net ]]
[[ "$HOSTNAME_RENEWAL_CONF" == /etc/letsencrypt/renewal/dns.example.net.conf ]]
''',
        inputs=generic,
    )
    check(
        "custom certificate paths and IPv6 accepted",
        '''
[[ "$HOSTNAME_CERT_LINEAGE" == /etc/letsencrypt/live/custom-name ]]
[[ "$HOSTNAME_RENEWAL_CONF" == /etc/letsencrypt/renewal/custom-name.conf ]]
[[ "$SERVER_IPV6" == 2001:db8::25 && "$HAS_IPV6" == 1 ]]
''',
        inputs=dict(
            generic,
            HOSTNAME_CERT_LINEAGE="/etc/letsencrypt/live/custom-name",
            HOSTNAME_ACME_WEBROOT="/srv/acme",
            PUBLIC_IPV6="2001:db8::25",
        ),
    )

    # Validation & injection/path-traversal protection
    check("missing noninteractive inputs rejected", "", False, inputs={})
    check("invalid hostname (command injection) rejected", "", False, inputs=dict(generic, PROVIDER_HOSTNAME="bad;hostname"))
    check("invalid IPv4 rejected", "", False, inputs=dict(generic, PUBLIC_IPV4="999.0.0.1"))
    check("CIDR IPv4 rejected", "", False, inputs=dict(generic, PUBLIC_IPV4="192.0.2.25/24"))
    check("invalid IPv6 rejected", "", False, inputs=dict(generic, PUBLIC_IPV6="::::"))
    check("unsafe shell expansion in path rejected", "", False, inputs=dict(generic, HOSTNAME_CERT_LINEAGE="/tmp/$(touch bad)"))
    check("path traversal (..) in cert lineage rejected", "", False, inputs=dict(generic, HOSTNAME_CERT_LINEAGE="/etc/letsencrypt/../shadow"))
    check("path traversal (..) in webroot rejected", "", False, inputs=dict(generic, HOSTNAME_ACME_WEBROOT="/var/www/../../etc"))
    check("relative path rejected", "", False, inputs=dict(generic, HOSTNAME_RENEWAL_CONF="etc/letsencrypt/renewal/x.conf"))
    check("root system directory path rejected", "", False, inputs=dict(generic, HOSTNAME_ACME_WEBROOT="/etc"))

    # Lifecycle reload & saved settings override rules
    check(
        "selected inputs survive lifecycle settings reload",
        '''
SERVER_IPV4=198.51.100.1
HOSTNAME_CERT_LINEAGE=/tmp/previous
restore_hostname_profile
[[ "$SERVER_IPV4" == 192.0.2.25 && "$HOSTNAME_CERT_LINEAGE" == /etc/letsencrypt/live/dns.example.net ]]
''',
        inputs=generic,
    )

    settings = temp / "settings"
    settings.write_text(
        'INSTALL_PROFILE="hostname"\nDNS_PROVIDER="external"\nTLS_MODE="existing-certbot"\n'
        'ROOT_DOMAIN="dns.example.net"\nSERVER_IPV4="192.0.2.10"\n'
        'PROVIDER_HOSTNAME="dns.example.net"\nPUBLIC_IPV4="192.0.2.10"\n',
        encoding="utf-8",
    )
    check(
        "saved profile usable without repeated environment variables",
        '[[ "$PROVIDER_HOSTNAME" == dns.example.net && "$PUBLIC_IPV4" == 192.0.2.10 ]]\n',
        inputs={},
    )
    check(
        "explicit IP overrides saved IP",
        '[[ "$PUBLIC_IPV4" == 192.0.2.25 && "$SERVER_IPV4" == 192.0.2.25 ]]\n',
        inputs=generic,
    )
    with settings.open("a", encoding="utf-8") as f:
        f.write('HOSTNAME_CERT_LINEAGE="/etc/letsencrypt/live/custom-saved"\n')
    check(
        "repeating hostname retains saved custom certificate path",
        '[[ "$HOSTNAME_CERT_LINEAGE" == /etc/letsencrypt/live/custom-saved ]]\n',
        inputs=generic,
    )
    check(
        "existing hostname change requires migration",
        "",
        False,
        inputs=dict(generic, PROVIDER_HOSTNAME="other.example.net"),
    )
    settings.write_text('BROKEN_SYNTAX="unclosed\n', encoding="utf-8")
    check("corrupted settings file cleanly rejected", "", False, inputs=generic)
    settings.unlink()

    # Interactive PTY prompt test (POSIX only; skipped cleanly on Windows Git Bash without pty)
    try:
        import pty
        master, slave = pty.openpty()
        env = {
            k: v for k, v in os.environ.items()
            if k not in ["PROVIDER_HOSTNAME", "PUBLIC_IPV4", "PUBLIC_IPV6", "INSTALL_PROFILE"]
        }
        env["SCRIPT_LANG"] = "en"
        proc = subprocess.Popen(
            ["bash", "-c", prefix + 'initialize_hostname_profile\n[[ "$PROVIDER_HOSTNAME" == dns.example.net && "$PUBLIC_IPV4" == 192.0.2.25 ]]\n'],
            stdin=slave,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            env=env,
            text=True,
        )
        os.close(slave)
        os.write(master, b"dns.example.net\n192.0.2.25\n\n")
        try:
            _, stderr = proc.communicate(timeout=5)
            assert proc.returncode == 0, stderr
        finally:
            if proc.poll() is None:
                proc.kill()
            os.close(master)
        print("PASS: interactive hostname and IPv4 prompts (PTY)")
    except (ImportError, OSError):
        print("SKIP: PTY interactive test (POSIX pty unavailable on Windows host; will run on Linux VM)")

    # Wizard behavior in hostname profile (no Cloudflare token requested)
    check(
        "wizard uses one hostname, shared DoT whitelist, and no Cloudflare input",
        '''
CPU_ARCH=x86_64
IPTABLES_BACKEND=nft
DOCKER_PRESENT=0
prompt_domain_groups_selection() { SELECTED_DOMAIN_GROUPS="ALL"; EXCLUDE_GOOGLE_SYS="N"; INCLUDE_XBOX_IPIFY="N"; return 0; }
prompt_custom_domains_import() { PENDING_CUSTOM_DOMAINS_COUNT=0; return 0; }
cleanup_domain_index_tmp() { return 0; }
read_tr() {
    case "$1" in
        M_0040) printf -v "$2" 2 ;;
        M_0049|M_0081) printf -v "$2" Y ;;
        *) echo "Unexpected prompt: $1" >&2; return 1 ;;
    esac
}
run_interactive_wizard </dev/null
[[ "$ROOT_DOMAIN" == "$PROVIDER_HOSTNAME" && "$DOT_HOST" == "$ROOT_DOMAIN" ]]
[[ "$DOT_WHITELIST_ENABLED" == true && "$DOT_WHITELIST_MODE" == shared ]]
[[ -z "${CF_API_TOKEN:-}" && ${#DOH_PATH} -ge 48 ]]
''',
        inputs=generic,
    )

    # Non-interactive hostname wizard defaults
    check(
        "noninteractive hostname wizard derives safe defaults without prompts",
        '''
CPU_ARCH=x86_64
run_noninteractive_hostname_wizard
[[ "$DNS_ENGINE" == oxidns && "$DOT_WHITELIST_ENABLED" == true && "$DOT_WHITELIST_MODE" == shared ]]
[[ -z "${CF_API_TOKEN:-}" && ${#DOH_PATH} -ge 48 ]]
''',
        inputs=generic,
    )

    # External DNS validation (no Cloudflare API)
    profile = 'ROOT_DOMAIN="$PROVIDER_HOSTNAME"\nDOT_HOST="$ROOT_DOMAIN"\n'
    dig_ok = 'dig() { if [[ "${*: -2:1}" == A ]]; then echo "$PUBLIC_IPV4"; fi; }\n'
    dig_v6_ok = 'dig() { if [[ "${*: -2:1}" == A ]]; then echo "$PUBLIC_IPV4"; else echo "$PUBLIC_IPV6"; fi; }\n'
    check("provider DNS validation accepts correct A / no AAAA", profile + dig_ok + 'verify_provider_hostname_dns "$PUBLIC_IPV4"\n', inputs=generic)
    check("provider DNS validation accepts matching A and AAAA", profile + dig_v6_ok + 'verify_provider_hostname_dns "$PUBLIC_IPV4" "$PUBLIC_IPV6"\n', inputs=dict(generic, PUBLIC_IPV6="2001:db8::25"))
    check("provider DNS validation rejects wrong A", profile + 'dig() { echo 192.0.2.1; }\nverify_provider_hostname_dns "$PUBLIC_IPV4"\n', False, inputs=generic)
    check("provider DNS validation rejects unexpected AAAA", profile + 'dig() { if [[ "${*: -2:1}" == A ]]; then echo "$PUBLIC_IPV4"; else echo 2001:db8::1; fi; }\nverify_provider_hostname_dns "$PUBLIC_IPV4"\n', False, inputs=generic)
    check("provider DNS validation rejects child DoT name", profile + 'DOT_HOST=dot.$ROOT_DOMAIN\nvalidate_hostname_profile\n', False, inputs=generic)

    # Change-domain blocked in hostname profile
    settings.write_text(
        'INSTALL_PROFILE="hostname"\nDNS_PROVIDER="external"\nTLS_MODE="existing-certbot"\n'
        'ROOT_DOMAIN="dns.example.net"\nDOT_HOST="dns.example.net"\n',
        encoding="utf-8",
    )
    (temp / "secrets.env").write_text('DOH_PATH="' + "a" * 52 + '"\n', encoding="utf-8")
    res_cd = check(
        "provider domain change is blocked in hostname profile",
        'detect_environment() { :; }\nrun_change_domain example.com\n',
        False,
        inputs=generic,
    )
    assert "separate migration" in res_cd.stderr, res_cd.stderr
    settings.unlink()

    # Existing occupied VPS blocks fresh install
    check("occupied port blocks fresh hostname install", 'ss() { echo "LISTEN 0 128 0.0.0.0:443"; }\nassert_fresh_install_target\n', False, inputs=generic)
    check("active conflicting service blocks fresh hostname install", 'ss() { :; }\nsystemctl() { [[ "$1" == is-active && "$3" == nginx ]]; }\nassert_fresh_install_target\n', False, inputs=generic)

    # Renewal deploy hook syntax & strict lineage/profile isolation
    hook_marker = "#!/usr/bin/env bash\nset -Eeuo pipefail\numask 027\n\n[[ -f /var/lib/oxidns-installer/settings ]] || exit 0"
    start = source.index(hook_marker)
    end = source.index("\nHOOK", start)
    hook = temp / "renew-hook.sh"
    hook.write_text(source[start:end], encoding="utf-8", newline="\n")
    subprocess.run(["bash", "-n", str(hook)], check=True)
    print("PASS: hostname renewal deploy hook syntax")

    # Test hook ignores Cloudflare settings and other Certbot lineages
    hook_isolated = temp / "renew-hook-isolated.sh"
    hook_isolated.write_text(
        hook.read_text(encoding="utf-8").replace("/var/lib/oxidns-installer/settings", settings.as_posix()),
        encoding="utf-8",
        newline="\n",
    )
    settings.write_text('TLS_MODE="acme-cloudflare"\nROOT_DOMAIN="cf.example.com"\n', encoding="utf-8")
    subprocess.run(["bash", str(hook_isolated)], env=dict(os.environ, RENEWED_LINEAGE="/etc/letsencrypt/live/cf.example.com"), check=True)
    print("PASS: hostname renewal hook ignores Cloudflare/acme-cloudflare installations")

    settings.write_text(
        'TLS_MODE="existing-certbot"\nPROVIDER_HOSTNAME="dns.example.net"\n'
        'HOSTNAME_CERT_LINEAGE="/etc/letsencrypt/live/dns.example.net"\n',
        encoding="utf-8",
    )
    subprocess.run(["bash", str(hook_isolated)], env=dict(os.environ, RENEWED_LINEAGE="/etc/letsencrypt/live/other.example.net"), check=True)
    print("PASS: hostname renewal hook ignores other Certbot certificate lineages")
    settings.unlink()

    # Noninteractive --help must not hang on open stdin pipe
    process = subprocess.Popen(
        ["bash", str(installer), "--help"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        env=dict(os.environ, SCRIPT_LANG="en"),
        text=True,
    )
    try:
        process.wait(timeout=5)
        out = process.stdout.read()
        assert process.returncode == 0 and "--hostname-check" in out and "No Cloudflare account" in out, out
    finally:
        if process.poll() is None:
            process.kill()
        process.stdin.close()
    print("PASS: noninteractive --help exits cleanly without hanging")

    # Structural assertions: both profiles coexist cleanly
    assert "location ^~ /.well-known/acme-challenge/" in source
    assert "verify-hostname-tls-keys.sh" in source
    assert "smartdns-hostname-cert-deploy.sh" in source
    assert "--dns dns_cf" in source and "smartdns-cert-renew.timer" in source
    assert "213.21.253.61" not in source
    print("PASS: both Cloudflare and Provider Hostname profiles present; no hardcoded VPS literals")

    if live:
        check("existing source certificate validates (live)", "verify_hostname_source_certificate\n")

print("ALL HOSTNAME PROFILE & CLOUDFLARE IMMUTABILITY TESTS PASSED")
