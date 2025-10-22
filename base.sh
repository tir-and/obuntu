#!/usr/bin/env bash
set -euo pipefail


LOG="/var/log/obuntu-base.log"
mkdir -p "$(dirname "$LOG")" && touch "$LOG"
exec > >(tee -a "$LOG") 2>&1

echo "[*] Obuntu base setup starting..."

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo $0"; exit 1
  fi
}
require_root

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates curl wget gnupg lsb-release vim-tiny net-tools \
  rsyslog openssh-client

# Enforce lean installs
mkdir -p /etc/apt/apt.conf.d
cat >/etc/apt/apt.conf.d/10no-recommends <<'EOF'
APT::Install-Recommends "0";
APT::Install-Suggests  "0";
EOF

# Purge snap & crash reporters & cloud-init (if present)
echo "[*] Removing snapd, apport, whoopsie, cloud-init..."
apt-get purge -y snapd apport whoopsie cloud-init || true
rm -rf /snap /var/snap /var/lib/snapd /var/cache/snapd

# Pin snapd to prevent reinstallation
mkdir -p /etc/apt/preferences.d
cat >/etc/apt/preferences.d/99-nosnap <<'EOF'
Package: snapd
Pin: release *
Pin-Priority: -10
EOF

# journald is part of systemd; keep it, but enable rsyslog (your preference)
systemctl enable rsyslog

# Optional: basic QoL
if ! command -v btop >/dev/null 2>&1; then
  apt-get install -y --no-install-recommends btop
fi

# Clean
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[*] Obuntu base setup complete."
