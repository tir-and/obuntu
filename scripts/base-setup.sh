#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

apt update
yes | apt install  -y --no-install-recommends \
  qemu-system-x86 qemu-utils libvirt-daemon-system virt-manager ovmf bridge-utils pciutils libvirt-clients qemu-system-modules-spice dnsmasq-base\
  gir1.2-spiceclientgtk-3.0 \
  xorg openbox obconf xterm xinit x11-xserver-utils \
  pipewire wireplumber pipewire-audio-client-libraries \
  alsa-utils bluez \
  arc-theme fonts-ubuntu fonts-hack \
  git curl wget unzip btop lm-sensors suckless-tools \
  nano wget xclip udisks2 scrot

# Install bluetui (pythops release) — raw binary, no tar needed
curl -L -o bluetui https://github.com/pythops/bluetui/releases/download/v0.6/bluetui-x86_64-linux-gnu
chmod +x bluetui 
cp ./bluetui /usr/local/bin/bluetui
rm -f ./bluetui

echo "[*] Installing Arc Openbox theme system-wide..."
TMPDIR=$(mktemp -d)
cd "$TMPDIR"

# grab latest master
wget -q https://github.com/dglava/arc-openbox/archive/refs/heads/master.zip -O arc-openbox.zip
unzip -q arc-openbox.zip
cd arc-openbox-master

# copy theme folders into system themes dir
sudo mkdir -p /usr/share/themes
sudo cp -r Arc* /usr/share/themes/

cd /
rm -rf "$TMPDIR"

usermod -aG libvirt,kvm "$SUDO_USER" || true
loginctl enable-linger "$SUDO_USER" || true

systemctl enable --now libvirtd virtlogd
# Ensure the default network exists and is started
if ! virsh net-list --all | grep -q "default"; then
  echo "[*] Defining default network..."
  virsh net-define /usr/share/libvirt/networks/default.xml || true
fi
virsh net-start default || true
virsh net-autostart default || true

# Suspend
echo "Idle suspend config available (requires sudo):"
echo "sudo mkdir -p /etc/systemd/logind.conf.d"
echo "sudo cp -v $REPO_DIR/configs/systemd-logind/idle.conf /etc/systemd/logind.conf.d/idle.conf"
echo "sudo systemctl restart systemd-logind"

echo "Setup complete. Reboot, login as user, then run host/deploy-host.sh"
