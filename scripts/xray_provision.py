#!/usr/bin/env python3
"""
xray_provision.py
Adds a client to an Xray config.json for a specific protocol
(vmess, vless, trojan, or socks), then prints the details needed to
build a shareable connection link, as simple KEY=VALUE lines (easy
for bash to parse without needing jq).

Usage: xray_provision.py <config_path> <protocol> <username> <server_address>

Output on success (stdout), one KEY=VALUE per line:
  PROTOCOL=vless
  ADDRESS=example.com
  PORT=443
  NETWORK=tcp
  SECURITY=tls
  CREDENTIAL=<uuid-or-password>
  (SOCKS only) USERNAME=<socks-user>

Exits non-zero with a human-readable message on stderr on failure -
never partially writes the config file.
"""
import sys
import json
import uuid
import secrets
import string


def random_password(length=12):
    alphabet = string.ascii_letters + string.digits
    return "".join(secrets.choice(alphabet) for _ in range(length))


def main():
    if len(sys.argv) != 5:
        print("Usage: xray_provision.py <config_path> <protocol> <username> <server_address>", file=sys.stderr)
        sys.exit(1)

    config_path, protocol, username, address = sys.argv[1:5]
    protocol = protocol.lower()

    try:
        with open(config_path, "r") as f:
            config = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"Could not read/parse config: {e}", file=sys.stderr)
        sys.exit(1)

    inbounds = config.get("inbounds", [])
    if not inbounds:
        print("No inbounds found in config.", file=sys.stderr)
        sys.exit(1)

    # Find an inbound matching the requested protocol
    target = None
    for inbound in inbounds:
        if inbound.get("protocol", "").lower() == protocol:
            target = inbound
            break

    if target is None:
        print(f"No '{protocol}' inbound found in the Xray config. Add one first, then try again.", file=sys.stderr)
        sys.exit(1)

    settings = target.setdefault("settings", {})
    stream = target.get("streamSettings", {})
    port = target.get("port", "N/A")
    network = stream.get("network", "tcp")
    security = stream.get("security", "none")

    credential = None
    socks_username = None

    if protocol == "socks":
        accounts = settings.setdefault("accounts", [])
        if any(a.get("user") == username for a in accounts):
            print(f"A SOCKS account for '{username}' already exists.", file=sys.stderr)
            sys.exit(1)
        password = random_password()
        accounts.append({"user": username, "pass": password})
        credential = password
        socks_username = username

    else:
        clients = settings.setdefault("clients", [])
        if any(c.get("email") == username for c in clients):
            print(f"A client with email '{username}' already exists in this inbound.", file=sys.stderr)
            sys.exit(1)

        new_id = str(uuid.uuid4())
        if protocol == "trojan":
            clients.append({"password": new_id, "email": username})
        else:
            # vmess, vless
            clients.append({"id": new_id, "email": username})
        credential = new_id

    try:
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
    except OSError as e:
        print(f"Could not write config: {e}", file=sys.stderr)
        sys.exit(1)

    print(f"PROTOCOL={protocol}")
    print(f"ADDRESS={address}")
    print(f"PORT={port}")
    print(f"NETWORK={network}")
    print(f"SECURITY={security}")
    print(f"CREDENTIAL={credential}")
    if socks_username:
        print(f"USERNAME={socks_username}")


if __name__ == "__main__":
    main()
