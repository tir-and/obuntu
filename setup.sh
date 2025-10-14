#!/usr/bin/env bash
set -euo pipefail

# =========================
# Simple KVM host installer
# =========================
# Toggles (override via env when calling)
GUI=${GUI:-1}                   # 1 = Openbox+LightDM+virt-manager; 0 = headless
USB_AUTOMOUNT=${USB_AUTOMOUNT:-1}
AUDIO=${AUDIO:-1}               # 1 = PulseAudio+ALSA; 0 = silent
USE_TIMESYNCD=${USE_TIMESYNCD:-1}
INSTALL_CONVENIENCE=${INSTALL_CONVENIENCE:-1}
INSTALL_ARC_OB_THEME=${INSTALL_ARC_OB_THEME:-1}
ENSURE_DEFAULT_NET=${ENSURE_DEFAULT_NET:-1}
DEPLOY_REPO_CONFIGS=${DEPLOY_REPO_CONFIGS:-1}
REPO_URL="${REPO_URL:-https://github.com/tir-and/ubuntu-qemu-host}"

if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0"; exit 1
fi

# --- Networking FIRST (networkd is the default on Server Minimal) --------------
echo "[*] Preparing networking (systemd-networkd + resolved)"

# If netplan configs exist, let netplan manage networkd; else provide a generic DHCP config
if ls /etc/netplan/*.yaml >/dev/null 2>&1; then
  echo "    - Netplan config detected; not writing /etc/systemd/network/*.network"
else
  echo "    - No netplan config found; creating generic DHCP for wired NICs (en*)"
  tee /etc/systemd/network/20-wired.network >/dev/null <<'EOF'
[Match]
Name=en*

[Network]
DHCP=yes
EOF
fi

systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf || true

# Try to bring common wired interfaces up so carrier/DHCP can happen immediately
for IF in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^en'); do
  ip link set "$IF" up || true
done

# (Optional niceties for troubleshooting; will succeed once network is alive)
apt-get update -y || true
apt-get install -y --no-install-recommends iputils-ping ethtool || true

# Quick sanity (won't fail the script)
ip route || true

# --- Now continue with the rest ------------------------------------------------
echo "[*] Purging unneeded packages (ignore errors if not installed)"
PURGE_PKGS=(
  cloud-init
  unattended-upgrades
  update-notifier-common
  snapd
  rsyslog
  apport whoopsie
  network-manager
  avahi-daemon
  cups* bluez blueman modemmanager
)
[[ "$USE_TIMESYNCD" -eq 1 ]] && PURGE_PKGS+=( chrony )
DEBIAN_FRONTEND=noninteractive apt-get purge -y "${PURGE_PKGS[@]}" || true
apt-get autoremove --purge -y || true

echo "[*] Holding some packages to block re-install"
apt-mark hold snapd apport whoopsie cloud-init avahi-daemon || true

echo "[*] Installing virtualization stack"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils qemu-system-modules-spice \
  libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-viewer \
  ovmf pciutils gir1.2-spiceclientgtk-3.0 || true

systemctl enable --now libvirtd || systemctl enable --now libvirt-daemon || true

if [[ "$GUI" -eq 1 ]]; then
  echo "[*] Installing minimal GUI (Openbox + LightDM + virt-manager)"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    xorg openbox lightdm lightdm-gtk-greeter xterm x11-xserver-utils \
    virt-manager virt-viewer polkitd policykit-1-gnome dbus-x11 \
    adwaita-icon-theme fonts-dejavu scrot xinit

  if [[ "$USB_AUTOMOUNT" -eq 1 ]]; then
    echo "[*] Enabling USB automount (udisks2 + gvfs)"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends udisks2 gvfs
  fi

  if [[ "$AUDIO" -eq 1 ]]; then
    echo "[*] Installing minimal audio (PulseAudio + ALSA)"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends pulseaudio alsa-utils
  fi

  systemctl enable lightdm
else
  echo "[*] Headless mode selected (no local GUI)"
fi

if [[ "$INSTALL_CONVENIENCE" -eq 1 ]]; then
  echo "[*] Installing convenience tools / fonts / themes"
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    arc-theme fonts-ubuntu fonts-hack \
    git curl wget unzip \
    btop lm-sensors suckless-tools \
    nano xclip
fi

if [[ "$INSTALL_ARC_OB_THEME" -eq 1 ]]; then
  echo "[*] Installing Arc Openbox theme to /usr/share/themes"
  TMPDIR="$(mktemp -d)"
  cd "$TMPDIR"
  wget -q https://github.com/dglava/arc-openbox/archive/refs/heads/master.zip -O arc-openbox.zip
  unzip -q arc-openbox.zip
  cd arc-openbox-master
  mkdir -p /usr/share/themes
  cp -r Arc* /usr/share/themes/
  cd /
  rm -rf "$TMPDIR"
fi

echo "[*] Ensuring systemd-networkd + resolved remain enabled"
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf || true
if [[ "$USE_TIMESYNCD" -eq 1 ]]; then
  systemctl enable --now systemd-timesyncd || true
fi

if [[ "$ENSURE_DEFAULT_NET" -eq 1 ]]; then
  echo "[*] Ensuring libvirt default NAT network exists"
  if ! virsh net-list --all | grep -q "^ default"; then
    virsh net-define /usr/share/libvirt/networks/default.xml || true
  fi
  virsh net-start default || true
  virsh net-autostart default || true
fi

CONSOLE_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ -n "${CONSOLE_USER:-}" ]]; then
  usermod -aG libvirt,kvm "$CONSOLE_USER" || true
  echo "[*] Added $CONSOLE_USER to groups: libvirt,kvm"
fi

if [[ "$DEPLOY_REPO_CONFIGS" -eq 1 && -n "${CONSOLE_USER:-}" ]]; then
  echo "[*] Deploying configs/ from repo"
  USER_HOME="$(getent passwd "$CONSOLE_USER" | cut -d: -f6)"
  WORKDIR="$USER_HOME/ubuntu-qemu-host"
  su - "$CONSOLE_USER" -c "test -d \"$WORKDIR\" || git clone --depth=1 \"$REPO_URL\" \"$WORKDIR\"" || true

  install -d -m 755 "$USER_HOME/.config/openbox"
  for f in rc.xml menu.xml; do
    [[ -f "$USER_HOME/.config/openbox/$f" ]] || \
      install -m 644 "$WORKDIR/configs/openbox/$f" "$USER_HOME/.config/openbox/$f" 2>/dev/null || true
  done

  [[ -f "$USER_HOME/.Xresources" ]] || \
    install -m 644 "$WORKDIR/configs/Xresources" "$USER_HOME/.Xresources" 2>/dev/null || true

  if [[ -f "$WORKDIR/configs/xinitrc" && ! -f "$USER_HOME/.xinitrc" ]]; then
    install -m 644 "$WORKDIR/configs/xinitrc" "$USER_HOME/.xinitrc" || true
    sed -i 's/^\(pipewire.*\|wireplumber.*\)$/# \0/' "$USER_HOME/.xinitrc"
    grep -q 'pulseaudio --start' "$USER_HOME/.xinitrc" || \
      printf 'pulseaudio --check || pulseaudio --start &\n' >> "$USER_HOME/.xinitrc"
  fi

  if [[ -f "$WORKDIR/configs/systemd-logind/idle.conf" ]]; then
    install -D -m 644 "$WORKDIR/configs/systemd-logind/idle.conf" /etc/systemd/logind.conf.d/idle.conf
    sed -i 's/^IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf.d/idle.conf
    systemctl restart systemd-logind || true
  fi

  if [[ -d "$WORKDIR/configs/scripts" ]]; then
    install -d -m 755 "$USER_HOME/.local/bin"
    install -m 755 "$WORKDIR/configs/scripts/"* "$USER_HOME/.local/bin/" 2>/dev/null || true
  fi

  chown -R "$CONSOLE_USER:$CONSOLE_USER" \
    "$USER_HOME/.config" "$USER_HOME/.xinitrc" "$USER_HOME/.Xresources" "$USER_HOME/.local" 2>/dev/null || true

  su - "$CONSOLE_USER" -c "openbox --reconfigure" 2>/dev/null || true
fi

echo "[✓] Done. Reboot recommended."
echo "Check: systemctl is-active libvirtd; systemctl is-active systemd-networkd systemd-resolved"
echo "If GUI enabled: log in via LightDM → Openbox → Virtual Machine Manager"
