#!/usr/bin/env bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive

# ============
# User toggles
# ============
GUI=${GUI:-1}                           # 1 = Openbox desktop; 0 = headless (still sets KVM/NM/CUPS if requested)
AUDIO=${AUDIO:-1}                       # 1 = PipeWire stack, 0 = no audio packages
ENABLE_NESTED=${ENABLE_NESTED:-1}       # 1 = enable Intel nested virt
INSTALL_PLANK=${INSTALL_PLANK:-1}       # 1 = Plank Reloaded repo + install
INSTALL_CELESTIAL=${INSTALL_CELESTIAL:-1}
DEPLOY_REPO_CONFIGS=${DEPLOY_REPO_CONFIGS:-1}
REPO_URL="${REPO_URL:-https://github.com/tir-and/ubuntu-qemu-host}"  # reuse your repo structure

# Desktop bits
USB_AUTOMOUNT=${USB_AUTOMOUNT:-1}       # udisks2 + udiskie
INSTALL_CONVENIENCE=${INSTALL_CONVENIENCE:-1}  # fonts, tools, picom, etc.

# ============
# Pre-flight
# ============
if [[ $EUID -ne 0 ]]; then echo "Please run as root: sudo $0"; exit 1; fi
apt-get update -y

# Undo previous “holds” that block desktop features you now want
apt-mark unhold snapd apport whoopsie cloud-init avahi-daemon || true

# ============
# Core stacks
# ============
# KVM/libvirt (virt-manager used when GUI=1)
apt-get install -y --no-install-recommends \
  qemu-system-x86 qemu-utils libvirt-daemon-system libvirt-clients \
  bridge-utils virtinst virt-viewer ovmf pciutils \
  spice-client-gtk gir1.2-spiceclientgtk-3.0 virtiofsd

systemctl enable --now libvirtd 2>/dev/null || systemctl enable --now libvirt-daemon || true

# Bring back NetworkManager + tray (nm-applet)
apt-get install -y --no-install-recommends network-manager network-manager-gnome
systemctl enable --now NetworkManager || true

# Time sync (systemd-timesyncd is fine alongside NM)
apt-get install -y --no-install-recommends systemd-timesyncd || true
systemctl enable --now systemd-timesyncd || true

# ============
# Logging: prefer rsyslog; keep journald minimal/volatile + forward to rsyslog
# ============
apt-get install -y --no-install-recommends rsyslog
systemctl enable --now rsyslog
install -d -m 755 /etc/systemd/journald.conf.d
cat >/etc/systemd/journald.conf.d/rsyslog-only.conf <<'EOF'
[Journal]
Storage=volatile
RuntimeMaxUse=50M
SystemMaxUse=0
ForwardToSyslog=yes
EOF
systemctl restart systemd-journald || true

# ============
# Printing: CUPS + Brother-friendly drivers + Avahi for discovery
# ============
apt-get install -y --no-install-recommends \
  cups cups-daemon cups-client cups-filters cups-browsed \
  printer-driver-brlaser avahi-daemon avahi-utils
systemctl enable --now cups cups-browsed avahi-daemon

# ============
# GUI: Openbox + LightDM + tools
# ============
if [[ "$GUI" -eq 1 ]]; then
  apt-get install -y --no-install-recommends \
    xorg openbox lightdm lightdm-gtk-greeter xterm x11-xserver-utils \
    virt-manager policykit-1 policykit-1-gnome dbus-x11 \
    adwaita-icon-theme scrot xinit obconf

  # PipeWire (default) with PulseAudio shim
  if [[ "$AUDIO" -eq 1 ]]; then
    apt-get purge -y pulseaudio || true
    apt-get install -y --no-install-recommends \
      pipewire pipewire-audio pipewire-pulse wireplumber alsa-utils
    # Enable user services for PW/WP on first login
    CONSOLE_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
    if [[ -n "${CONSOLE_USER:-}" ]]; then
      su - "$CONSOLE_USER" -c 'systemctl --user enable --now pipewire pipewire-pulse wireplumber' || true
    fi
  fi

  # USB automount for Openbox sessions
  if [[ "$USB_AUTOMOUNT" -eq 1 ]]; then
    apt-get install -y --no-install-recommends udisks2 udiskie gvfs gvfs-backends
  fi

  # Convenience desktop bits (fonts, tools, compositor)
  if [[ "$INSTALL_CONVENIENCE" -eq 1 ]]; then
    apt-get install -y --no-install-recommends \
      fonts-ubuntu fonts-hack picom git curl wget unzip btop lm-sensors suckless-tools nano xclip
  fi

  systemctl enable lightdm || true
fi

# ============
# Intel nested virtualization (toggle)
# ============
if [[ "$ENABLE_NESTED" -eq 1 ]]; then
  if lsmod | grep -q kvm_intel; then modprobe -r kvm_intel || true; fi
  install -D -m 644 /dev/stdin /etc/modprobe.d/kvm-intel.conf <<<'options kvm-intel nested=Y'
  modprobe kvm_intel || true
  echo "[*] Intel nested virt: $(cat /sys/module/kvm_intel/parameters/nested 2>/dev/null || echo '?')"
fi

# ============
# Plank Reloaded (apt repo) + autostart
# ============
if [[ "$INSTALL_PLANK" -eq 1 && "$GUI" -eq 1 ]]; then
  # Use upstream apt repo documented by the project
  install -D -m 644 /dev/stdin /usr/share/keyrings/zquestz-archive-keyring.gpg < <(
    curl -fsSL https://zquestz.github.io/ppa/debian/KEY.gpg
  )
  echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/debian ./" \
    > /etc/apt/sources.list.d/zquestz.list
  apt-get update -y
  apt-get install -y --no-install-recommends plank-reloaded
fi

# ============
# Celestial GTK Theme (build & install to ~/.themes for the console user)
# ============
if [[ "$INSTALL_CELESTIAL" -eq 1 && -n "${SUDO_USER:-}" ]]; then
  CU="$SUDO_USER"; CUHOME="$(getent passwd "$CU" | cut -d: -f6)"
  apt-get install -y --no-install-recommends git sassc gtk2-engines-murrine
  su - "$CU" -c "git clone --depth=1 https://github.com/zquestz/celestial-gtk-theme \"$CUHOME/celestial-gtk-theme\" || true"
  su - "$CU" -c "cd \"$CUHOME/celestial-gtk-theme\" && ./install.sh"  # installs to ~/.themes by default
fi

# ============
# Deploy your repo configs and wire Openbox autostart
# ============
CONSOLE_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ "$DEPLOY_REPO_CONFIGS" -eq 1 && -n "${CONSOLE_USER:-}" ]]; then
  USER_HOME="$(getent passwd "$CONSOLE_USER" | cut -d: -f6)"
  WORKDIR="$USER_HOME/ubuntu-qemu-host"
  su - "$CONSOLE_USER" -c "test -d \"$WORKDIR\" || git clone --depth=1 \"$REPO_URL\" \"$WORKDIR\"" || true

  install -d -m 755 "$USER_HOME/.config/openbox"
  for f in rc.xml menu.xml; do
    [[ -f "$USER_HOME/.config/openbox/$f" ]] || \
      install -m 644 "$WORKDIR/configs/openbox/$f" "$USER_HOME/.config/openbox/$f" 2>/dev/null || true
  done

  # Xresources optional
  [[ -f "$WORKDIR/configs/Xresources" ]] && install -m 644 "$WORKDIR/configs/Xresources" "$USER_HOME/.Xresources" || true

  # Openbox autostart: add nm-applet, udiskie, picom, plank (if present)
  AUTOSTART="$USER_HOME/.config/openbox/autostart"
  touch "$AUTOSTART"
  grep -q 'nm-applet' "$AUTOSTART" || echo 'nm-applet &' >> "$AUTOSTART"
  if [[ "$USB_AUTOMOUNT" -eq 1 ]]; then
    grep -q 'udiskie' "$AUTOSTART" || echo 'udiskie &' >> "$AUTOSTART"
  fi
  if command -v picom >/dev/null 2>&1; then
    grep -q 'picom' "$AUTOSTART" || echo 'picom --experimental-backends &' >> "$AUTOSTART"
  fi
  if command -v plank >/dev/null 2>&1; then
    grep -q '^plank' "$AUTOSTART" || echo 'plank &' >> "$AUTOSTART"
  fi

  chown -R "$CONSOLE_USER:$CONSOLE_USER" "$USER_HOME/.config" "$USER_HOME/.Xresources" 2>/dev/null || true
  su - "$CONSOLE_USER" -c "openbox --reconfigure" 2>/dev/null || true
fi

# ============
# Libvirt default network (safety)
# ============
if ! virsh net-list --all | awk '{print $1}' | grep -qx "default"; then
  virsh net-define /usr/share/libvirt/networks/default.xml || true
fi
virsh net-start default || true
virsh net-autostart default || true

echo "[✓] Done. Reboot recommended."
echo "Test nested virt: cat /sys/module/kvm_intel/parameters/nested"
echo "Set theme: lxappearance → Celestial (then set Plank -> Gtk+ theme)"
echo "Add printer: system-config-printer or http://localhost:631"
