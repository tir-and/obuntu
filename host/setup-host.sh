#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

apt update
apt install -y --no-install-recommends \
  qemu-kvm libvirt-daemon-system virt-manager ovmf bridge-utils pciutils \
  xorg openbox obconf xterm xinit x11-xserver-utils \
  pipewire wireplumber pipewire-audio-client-libraries \
  alsa-utils bluez bluetui \
  arc-theme fonts-ubuntu fonts-hack \
  git curl wget unzip btop lm-sensors slock

usermod -aG libvirt,kvm "$SUDO_USER" || true
loginctl enable-linger "$SUDO_USER" || true

systemctl enable --now libvirtd virtlogd
virsh net-start default || true
virsh net-autostart default || true

echo "Setup complete. Reboot, login as user, then run host/deploy-host.sh"
