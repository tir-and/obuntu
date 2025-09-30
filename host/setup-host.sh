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

# Install bluetui (prebuilt binary)
BLUETUI_URL="https://github.com/pythops/bluetui/releases/download/v0.6/bluetui-x86_64-linux-gnu"
TMPDIR=$(mktemp -d)
cd "$TMPDIR"
wget -qO bluetui.tar.gz "$BLUETUI_URL"
tar -xzf bluetui.tar.gz
install -m 755 bluetui /usr/local/bin/bluetui
cd - >/dev/null
rm -rf "$TMPDIR"

usermod -aG libvirt,kvm "$SUDO_USER" || true
loginctl enable-linger "$SUDO_USER" || true

systemctl enable --now libvirtd virtlogd
virsh net-start default || true
virsh net-autostart default || true

echo "Setup complete. Reboot, login as user, then run host/deploy-host.sh"
