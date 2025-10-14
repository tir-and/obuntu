#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Ubuntu Server (Minimal) → Lean KVM Host (headless or minimal GUI)
# Repo: https://github.com/tir-and/ubuntu-qemu-host
# ==============================================================================

# ── Toggles (edit before running, or export VAR=... in the shell) ──────────────
GUI=${GUI:-1}                   # 1 = Openbox+LightDM+virt-manager locally; 0 = headless
USB_AUTOMOUNT=${USB_AUTOMOUNT:-1}   # 1 = udisks2+gvfs
AUDIO=${AUDIO:-0}               # 1 = PulseAudio+ALSA; 0 = silent host
USE_TIMESYNCD=${USE_TIMESYNCD:-1}   # 1 = purge chrony, enable systemd-timesyncd
INSTALL_CONVENIENCE=${INSTALL_CONVENIENCE:-1}    # git,curl,wget,unzip,btop,fonts,arc-theme,...
INSTALL_ARC_OB_THEME=${INSTALL_ARC_OB_THEME:-1}  # Arc Openbox theme from GitHub
ENSURE_DEFAULT_NET=${ENSURE_DEFAULT_NET:-1}      # libvirt 'default' NAT network present
DEPLOY_REPO_CONFIGS=${DEPLOY_REPO_CONFIGS:-1}    # copy configs/ from this repo

REPO_URL="${REPO_URL:-https://github.com/tir-and/ubuntu-qemu-host}"

say() { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
ok() {  printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
warn() {printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
need_root() { [[ $EUID -eq 0 ]] || { echo "Run as root: sudo $0"; exit 1; }; }

need_root
say "Updating APT…"
apt-get update -y

# ── Purge unwanted bits (ignore if absent) ─────────────────────────────────────
TO_PURGE=(
  cloud-init
  unattended-upgrades
  update-notifier-common
  snapd
  rsyslog
  apport whoopsie
  network-manager
  avahi-daemon
  "cups*"
  bluez blueman
  modemmanager
)
[[ "$USE_TIMESYNCD" -eq 1 ]] && TO_PURGE+=( chrony )

say "Purging unneeded packages (some may not be installed)…"
DEBIAN_FRONTEND=noninteractive apt-get purge -y "${TO_PURGE[@]}" || true
apt-get autoremove --purge -y || true

say "Holding packages to prevent re-install…"
apt-mark hold snapd apport whoopsie cloud-init avahi-daemon || true

# ── Core virtualization (Ubuntu names) ─────────────────────────────────────────
VIRT_CORE=(
  qemu-system-x86 qemu-utils qemu-system-modules-spice
  libvirt-daemon-system libvirt-clients bridge-utils virtinst virt-viewer
  ovmf pciutils
  gir1.2-spiceclientgtk-3.0
)

say "Installing virtualization stack…"
DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${VIRT_CORE[@]}" || true
systemctl enable --now libvirtd || systemctl enable --now libvirt-daemon || true

# ── GUI path (Openbox + LightDM + virt-manager) ────────────────────────────────
if [[ "$GUI" -eq 1 ]]; then
  say "Installing minimal GUI (Openbox + LightDM + virt-manager)…"
  GUI_PKGS=(
    xorg openbox lightdm lightdm-gtk-greeter xterm x11-xserver-utils
    virt-manager virt-viewer
    policykit-1 dbus-x11
    adwaita-icon-theme fonts-dejavu
    scrot xinit
  )
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${GUI_PKGS[@]}"

  if [[ "$USB_AUTOMOUNT" -eq 1 ]]; then
    say "Adding USB automount (udisks2 + gvfs)…"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends udisks2 gvfs
  fi

  if [[ "$AUDIO" -eq 1 ]]; then
    say "Installing minimal audio (PulseAudio + ALSA utils)…"
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends pulseaudio alsa-utils
  fi

  systemctl enable lightdm
else
  say "Headless host selected — no GUI components will be installed."
fi

# ── Convenience tools / fonts / themes ─────────────────────────────────────────
if [[ "$INSTALL_CONVENIENCE" -eq 1 ]]; then
  say "Installing convenience tools, fonts, themes…"
  CONVENIENCE_PKGS=(
    arc-theme fonts-ubuntu fonts-hack
    git curl wget unzip
    btop lm-sensors suckless-tools
    nano xclip
  )
  DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends "${CONVENIENCE_PKGS[@]}" || true
fi

# ── Optional: Arc Openbox theme (from GitHub) ──────────────────────────────────
if [[ "$INSTALL_ARC_OB_THEME" -eq 1 ]]; then
  say "Installing Arc Openbox theme (GitHub → /usr/share/themes)…"
  TMPDIR="$(mktemp -d)"
  (
    cd "$TMPDIR"
    wget -q https://github.com/dglava/arc-openbox/archive/refs/heads/master.zip -O arc-openbox.zip
    unzip -q arc-openbox.zip
    cd arc-openbox-master
    mkdir -p /usr/share/themes
    cp -r Arc* /usr/share/themes/
  )
  rm -rf "$TMPDIR"
  ok "Arc Openbox theme installed."
fi

# ── Networking & time sync ─────────────────────────────────────────────────────
say "Enabling systemd-networkd + resolved…"
systemctl enable --now systemd-networkd
systemctl enable --now systemd-resolved
ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf

if [[ "$USE_TIMESYNCD" -eq 1 ]]; then
  say "Using systemd-timesyncd (chrony removed)…"
  systemctl enable --now systemd-timesyncd || true
fi

# ── Ensure libvirt 'default' NAT network ───────────────────────────────────────
if [[ "$ENSURE_DEFAULT_NET" -eq 1 ]]; then
  if ! virsh net-list --all | grep -q "^ default"; then
    say "Defining libvirt 'default' network…"
    virsh net-define /usr/share/libvirt/networks/default.xml || true
  fi
  say "Starting & enabling libvirt 'default' network…"
  virsh net-start default || true
  virsh net-autostart default || true
fi

# ── Add user to libvirt/kvm groups ─────────────────────────────────────────────
CONSOLE_USER="${SUDO_USER:-$(logname 2>/dev/null || true)}"
if [[ -n "${CONSOLE_USER:-}" ]]; then
  usermod -aG libvirt,kvm "$CONSOLE_USER" || true
  ok "Added $CONSOLE_USER to groups: libvirt,kvm (log out/in to apply)."
else
  warn "No console user detected to add to libvirt/kvm groups."
fi

# ── Deploy configs/ from this repo ─────────────────────────────────────────────
if [[ "$DEPLOY_REPO_CONFIGS" -eq 1 && -n "${CONSOLE_USER:-}" ]]; then
  USER_HOME="$(getent passwd "$CONSOLE_USER" | cut -d: -f6)"
  WORKDIR="$USER_HOME/ubuntu-qemu-host"

  say "Fetching repo to deploy configs…"
  # If script came from raw URL, repo may not exist locally yet—clone it.
  su - "$CONSOLE_USER" -c "test -d \"$WORKDIR\" || git clone --depth=1 \"$REPO_URL\" \"$WORKDIR\"" || true

  # Openbox configs
  install -d -m 755 "$USER_HOME/.config/openbox"
  for f in rc.xml menu.xml; do
    [[ -f "$USER_HOME/.config/openbox/$f" ]] || \
      install -m 644 "$WORKDIR/configs/openbox/$f" "$USER_HOME/.config/openbox/$f" 2>/dev/null || true
  done

  # Xresources
  [[ -f "$USER_HOME/.Xresources" ]] || \
    install -m 644 "$WORKDIR/configs/Xresources" "$USER_HOME/.Xresources" 2>/dev/null || true

  # xinitrc (PulseAudio-only tweak; comment PipeWire/WirePlumber if present)
  if [[ -f "$WORKDIR/configs/xinitrc" && ! -f "$USER_HOME/.xinitrc" ]]; then
    install -m 644 "$WORKDIR/configs/xinitrc" "$USER_HOME/.xinitrc" || true
    sed -i 's/^\(pipewire.*\|wireplumber.*\)$/# \0/' "$USER_HOME/.xinitrc"
    grep -q 'pulseaudio --start' "$USER_HOME/.xinitrc" || \
      printf 'pulseaudio --check || pulseaudio --start &\n' >> "$USER_HOME/.xinitrc"
  fi

  # systemd-logind idle policy → disable suspend on a VM host
  if [[ -f "$WORKDIR/configs/systemd-logind/idle.conf" ]]; then
    install -D -m 644 "$WORKDIR/configs/systemd-logind/idle.conf" /etc/systemd/logind.conf.d/idle.conf
    sed -i 's/^IdleAction=.*/IdleAction=ignore/' /etc/systemd/logind.conf.d/idle.conf
    systemctl restart systemd-logind || true
  fi

  # helper scripts (if any)
  if [[ -d "$WORKDIR/configs/scripts" ]]; then
    install -d -m 755 "$USER_HOME/.local/bin"
    install -m 755 "$WORKDIR/configs/scripts/"* "$USER_HOME/.local/bin/" 2>/dev/null || true
  fi

  chown -R "$CONSOLE_USER:$CONSOLE_USER" \
    "$USER_HOME/.config" "$USER_HOME/.xinitrc" "$USER_HOME/.Xresources" "$USER_HOME/.local" 2>/dev/null || true

  # Reload Openbox if running
  su - "$CONSOLE_USER" -c "openbox --reconfigure" 2>/dev/null || true
  ok "Configs deployed from repo."
fi

# ── Final summary ──────────────────────────────────────────────────────────────
ok "Setup complete."
echo -e "
Next:
  - Reboot: \033[1mreboot\033[0m
  - Verify: systemctl is-active libvirtd; systemctl is-active systemd-networkd systemd-resolved
  - If GUI: login with LightDM → Openbox → 'Virtual Machine Manager'
  - Optional: \033[1msudo sensors-detect\033[0m
"
