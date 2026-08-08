#!/usr/bin/env python3
"""
build_share_link.py
Given the KEY=VALUE fields printed by xray_provision.py (piped in via
stdin) plus a username, prints a proper shareable connection link for
the protocol - the format each client app (v2rayNG, NekoBox, Shadowrocket,
etc.) expects.

Usage: echo "$fields" | build_share_link.py <username>
"""
import sys
import json
import base64


def parse_fields(text):
    fields = {}
    for line in text.strip().splitlines():
        if "=" in line:
            key, _, value = line.partition("=")
            fields[key.strip()] = value.strip()
    return fields


def main():
    if len(sys.argv) != 2:
        print("Usage: build_share_link.py <username>", file=sys.stderr)
        sys.exit(1)

    username = sys.argv[1]
    fields = parse_fields(sys.stdin.read())

    required = ["PROTOCOL", "ADDRESS", "PORT", "NETWORK", "SECURITY", "CREDENTIAL"]
    missing = [k for k in required if k not in fields]
    if missing:
        print(f"Missing fields: {', '.join(missing)}", file=sys.stderr)
        sys.exit(1)

    protocol = fields["PROTOCOL"]
    address = fields["ADDRESS"]
    port = fields["PORT"]
    network = fields["NETWORK"]
    security = fields["SECURITY"]
    credential = fields["CREDENTIAL"]

    if protocol == "vmess":
        vmess_obj = {
            "v": "2",
            "ps": username,
            "add": address,
            "port": str(port),
            "id": credential,
            "aid": "0",
            "net": network,
            "type": "none",
            "host": "",
            "path": "",
            "tls": security if security == "tls" else "",
        }
        encoded = base64.b64encode(json.dumps(vmess_obj).encode()).decode()
        print(f"vmess://{encoded}")

    elif protocol == "vless":
        print(f"vless://{credential}@{address}:{port}?encryption=none&security={security}&type={network}#{username}")

    elif protocol == "trojan":
        print(f"trojan://{credential}@{address}:{port}?security={security}&type={network}#{username}")

    elif protocol == "socks":
        socks_user = fields.get("USERNAME", username)
        print(f"SOCKS5 {address}:{port}  user={socks_user}  pass={credential}")

    else:
        print(f"Unsupported protocol for link building: {protocol}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
