#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<EOF
Usage:
  $(basename "$0") <hostname>

Examples:
  $(basename "$0") xbp-eu-de2
  $(basename "$0") xbp-eu-nl1
  $(basename "$0") xbp-fin1
EOF
    exit 1
}

[[ $# -eq 1 ]] || usage

NEW_HOSTNAME="$1"

if [[ $EUID -ne 0 ]]; then
    exec sudo "$0" "$@"
fi

if ! [[ "$NEW_HOSTNAME" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]; then
    echo "Invalid hostname: $NEW_HOSTNAME" >&2
    exit 1
fi

OLD_HOSTNAME="$(hostnamectl --static 2>/dev/null || hostname)"

if [[ "$OLD_HOSTNAME" == "$NEW_HOSTNAME" ]]; then
    echo "Hostname already set to '$NEW_HOSTNAME'"
    exit 0
fi

DATE="$(date +%Y%m%d-%H%M%S)"

echo "Renaming hostname"
echo "  Old: $OLD_HOSTNAME"
echo "  New: $NEW_HOSTNAME"

cp /etc/hostname "/etc/hostname.bak.$DATE"
cp /etc/hosts "/etc/hosts.bak.$DATE"

hostnamectl set-hostname "$NEW_HOSTNAME"

printf '%s\n' "$NEW_HOSTNAME" > /etc/hostname

if grep -qE '^[[:space:]]*127\.0\.1\.1[[:space:]]+' /etc/hosts; then
    sed -i -E "s/^(127\.0\.1\.1[[:space:]]+).*/\1$NEW_HOSTNAME/" /etc/hosts
else
    printf '\n127.0.1.1\t%s\n' "$NEW_HOSTNAME" >> /etc/hosts
fi

echo
echo "Hostname updated successfully"
echo "Current hostname: $(hostnamectl --static)"
echo
echo "Backups:"
echo "  /etc/hostname.bak.$DATE"
echo "  /etc/hosts.bak.$DATE"
echo
echo "A reboot is recommended."
