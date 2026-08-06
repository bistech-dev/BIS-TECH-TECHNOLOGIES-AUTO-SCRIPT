#!/bin/bash
#
# generate_license.sh
# SELLER-ONLY TOOL - do not ship this to customers.
#
# Generates a license key for a given customer email, using the same
# LICENSE_SECRET configured in config.conf. Run this on your own
# machine (not the customer's VPS) after a purchase, then send the
# resulting key to the customer along with instructions to use
# menu option [20] Activate License (or run 'menu' after trial expiry).
#
# Usage:
#   ./generate_license.sh customer@example.com
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
source "$SCRIPT_DIR/config.conf"

if [ "$LICENSE_SECRET" = "CHANGE_ME_BEFORE_SELLING" ]; then
    echo "WARNING: LICENSE_SECRET in config.conf is still the default placeholder."
    echo "Change it to your own private secret before issuing real license keys,"
    echo "otherwise anyone who reads this repo's history could generate valid keys."
    echo
fi

if [ -z "$1" ]; then
    echo "Usage: $0 customer@example.com"
    exit 1
fi

EMAIL="$1"
KEY=$(echo -n "${LICENSE_SECRET}:${EMAIL}" | sha256sum | cut -c1-16 | tr '[:lower:]' '[:upper:]')

echo "Customer email : $EMAIL"
echo "License key    : $KEY"
echo
echo "Send the customer both values. They'll enter them via menu option"
echo "[20] Activate License, or when prompted after their trial ends."
