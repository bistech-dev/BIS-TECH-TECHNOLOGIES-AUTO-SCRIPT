#!/usr/bin/env python3
"""
list_xray_clients.py
Lists accounts configured in an Xray config.json, optionally filtered
to a single protocol (vmess/vless/trojan/socks). Handles both the
"clients" array shape (vmess/vless/trojan) and the "accounts" array
shape (socks, which uses a "user" field instead of "id"/"email").

Usage: list_xray_clients.py <config_path> [protocol]
Prints one account per line: "<protocol> | <identifier> | <label>"
"""
import sys
import json


def main():
    if len(sys.argv) < 2:
        print("Usage: list_xray_clients.py <config_path> [protocol]", file=sys.stderr)
        sys.exit(1)

    config_path = sys.argv[1]
    protocol_filter = sys.argv[2] if len(sys.argv) > 2 else None

    try:
        with open(config_path, "r") as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Could not read/parse config: {e}", file=sys.stderr)
        sys.exit(1)

    inbounds = config.get("inbounds", [])
    found_any = False

    for inbound in inbounds:
        protocol = inbound.get("protocol", "unknown")
        if protocol_filter and protocol != protocol_filter:
            continue

        settings = inbound.get("settings", {})

        # vmess/vless/trojan shape
        for client in settings.get("clients", []) or []:
            identifier = client.get("id") or client.get("password") or "?"
            label = client.get("email", "(no label)")
            print(f"{protocol} | {identifier} | {label}")
            found_any = True

        # socks shape
        for account in settings.get("accounts", []) or []:
            identifier = account.get("pass", "?")
            label = account.get("user", "(no label)")
            print(f"{protocol} | {identifier} | {label}")
            found_any = True

    if not found_any:
        print("NONE_FOUND")


if __name__ == "__main__":
    main()
