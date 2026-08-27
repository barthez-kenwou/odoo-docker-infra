#!/usr/bin/env python3
"""
Black-box integration/smoke test suite. Run against any environment's public
URL — never talks to the internal Docker networks — so it validates exactly
what an end user or an attacker's first request would see.

Usage:
    python3 tests/integration/test_health.py --base-url https://staging-odoo.example.com
"""
import argparse
import sys
import urllib.request
import urllib.error
import ssl
from urllib.parse import urlparse


def check(name, condition, detail=""):
    status = "PASS" if condition else "FAIL"
    print(f"[{status}] {name}" + (f" — {detail}" if detail and not condition else ""))
    return condition


def fetch(url, insecure=False, method="GET"):
    ctx = ssl.create_default_context()
    if insecure:
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
    req = urllib.request.Request(url, method=method)
    with urllib.request.urlopen(req, context=ctx, timeout=10) as resp:
        return resp.status, dict(resp.headers), resp.read()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--insecure", action="store_true", help="skip TLS verification (dev self-signed certs)")
    args = parser.parse_args()

    base = args.base_url.rstrip("/")
    insecure = args.insecure or "localhost" in base or urlparse(base).hostname in ("127.0.0.1",)

    failures = 0

    # --- 1. Health endpoint answered by Nginx directly ---
    try:
        status, headers, body = fetch(f"{base}/healthz", insecure=insecure)
        failures += not check("healthz returns 200", status == 200, f"got {status}")
    except Exception as exc:  # noqa: BLE001
        failures += not check("healthz reachable", False, str(exc))

    # --- 2. Login page reachable and returns 200 ---
    try:
        status, headers, body = fetch(f"{base}/web/login", insecure=insecure)
        failures += not check("/web/login returns 200", status == 200, f"got {status}")
    except Exception as exc:  # noqa: BLE001
        failures += not check("/web/login reachable", False, str(exc))
        headers = {}

    # --- 3. Security headers present ---
    for header in ["Strict-Transport-Security", "X-Content-Type-Options", "X-Frame-Options", "Content-Security-Policy"]:
        failures += not check(f"header present: {header}", header in headers)

    # --- 4. Server does not leak its version ---
    server_header = headers.get("Server", "")
    failures += not check("Server header doesn't leak Nginx version", "nginx/" not in server_header.lower() or server_header.lower() == "nginx", server_header)

    # --- 5. Database manager / selector endpoints are blocked ---
    try:
        status, _, _ = fetch(f"{base}/web/database/manager", insecure=insecure)
        failures += not check("/web/database/manager is blocked (403)", status == 403, f"got {status}")
    except urllib.error.HTTPError as exc:  # noqa: BLE001
        failures += not check("/web/database/manager is blocked (403)", exc.code == 403, f"got {exc.code}")
    except Exception as exc:  # noqa: BLE001
        failures += not check("/web/database/manager check ran", False, str(exc))

    # --- 6. HTTP redirects to HTTPS (skip for plain-http dev) ---
    if base.startswith("https://"):
        http_base = "http://" + base[len("https://"):]
        try:
            req = urllib.request.Request(http_base + "/web/login")
            try:
                urllib.request.urlopen(req, timeout=10)
                failures += not check("HTTP redirects to HTTPS", False, "no redirect raised")
            except urllib.error.HTTPError as exc:
                failures += not check("HTTP redirects to HTTPS", exc.code in (301, 302), f"got {exc.code}")
        except Exception as exc:  # noqa: BLE001
            print(f"[SKIP] HTTP redirect check — {exc}")

    print()
    if failures:
        print(f"{failures} check(s) FAILED")
        sys.exit(1)
    print("all checks passed")


if __name__ == "__main__":
    main()
