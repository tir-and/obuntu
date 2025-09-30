#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

apt update
apt install -y --no-install-recommends \
  qemu-system-x86 qemu-utils libvirt-daemon-system virt-manager ovmf bridge-utils pciutils \
  xorg openbox obconf xterm xinit x11-xserver-utils \
  pipewire wireplumber pipewire-audio-client-libraries \
  alsa-utils bluez \
  arc-theme fonts-ubuntu fonts-hack \
  git curl wget unzip btop lm-sensors suckless-tools

# Install bluetui (pythops release) — raw binary, no tar needed
BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/v0.6/bluetui-x86_64-linux-gnu"
TMPFILE="$(mktemp)"
curl -L -o "$TMPFILE" "$BLUETUI_URL"
install -m 755 "$TMPFILE" /usr/local/bin/bluetui
rm -f "$TMPFILE"


usermod -aG libvirt,kvm "$SUDO_USER" || true
loginctl enable-linger "$SUDO_USER" || true

systemctl enable --now libvirtd virtlogd
virsh net-start default || true
virsh net-autostart default || true

echo "Setup complete. Reboot, login as user, then run host/deploy-host.sh"
