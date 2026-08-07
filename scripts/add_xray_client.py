#!/usr/bin/env python3
"""
add_xray_client.py
Adds a client entry to an Xray config.json for a given username,
generating a fresh UUID. Handles both id-based protocols (VMess,
VLESS) and password-based protocols (Trojan). Prints the generated
credential (UUID or password) to stdout on success, or exits non-zero
with an error message on stderr.

Usage: add_xray_client.py <config_path> <username>
"""
import sys
import json
import uuid


def main():
    if len(sys.argv) != 3:
        print("Usage: add_xray_client.py <config_path> <username>", file=sys.stderr)
        sys.exit(1)

    config_path, username = sys.argv[1], sys.argv[2]

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

    new_id = str(uuid.uuid4())
    added = False

    for inbound in inbounds:
        settings = inbound.get("settings", {})
        clients = settings.get("clients")
        if clients is None:
            continue

        protocol = inbound.get("protocol", "")
        if protocol == "trojan":
            new_client = {"password": new_id, "email": username}
        else:
            # vmess, vless, and most others use an "id" field
            new_client = {"id": new_id, "email": username}

        # Avoid duplicate entries for the same username
        if any(c.get("email") == username for c in clients):
            print(f"A client with email '{username}' already exists in this inbound.", file=sys.stderr)
            sys.exit(1)

        clients.append(new_client)
        added = True
        # Only add to the first matching inbound, not every one
        break

    if not added:
        print("No inbound with a 'clients' array was found (unsupported config shape).", file=sys.stderr)
        sys.exit(1)

    try:
        with open(config_path, "w") as f:
            json.dump(config, f, indent=2)
    except OSError as e:
        print(f"Could not write config: {e}", file=sys.stderr)
        sys.exit(1)

    print(new_id)


if __name__ == "__main__":
    main()
