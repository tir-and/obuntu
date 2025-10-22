#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/obuntu-desktop.log"
exec > >(tee -a "$LOG") 2>&1

echo "[*] Obuntu desktop setup starting..."

require_root() {
  if [[ $EUID -ne 0 ]]; then
    echo "Please run as root: sudo $0"; exit 1
  fi
}
require_root

# Detect the invoking user to copy configs into their $HOME as well
INVOKER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$INVOKER" || "$INVOKER" == "root" ]]; then
  echo "[!] Could not detect a non-root user. Skipping per-user copy."
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update

# Add zquestz PPA for plank-reloaded (and potentially celestial theme in future)
if [[ ! -f /etc/apt/sources.list.d/zquestz.list ]]; then
  echo "[*] Adding zquestz PPA..."
  install -d /usr/share/keyrings
  curl -fsSL https://zquestz.github.io/ppa/ubuntu/KEY.gpg \
    | gpg --dearmor -o /usr/share/keyrings/zquestz-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/ubuntu noble main" \
    > /etc/apt/sources.list.d/zquestz.list
  apt-get update
fi

# Desktop packages (no lxappearance, your exact stack)
apt-get install -y --no-install-recommends \
  xorg xinit lightdm lightdm-gtk-greeter \
  openbox obconf rofi picom dunst stalonetray \
  plank-reloaded \
  xterm tilda \
  pcmanfm xarchiver nnn \
  pipewire pipewire-audio pipewire-pulse wireplumber \
  network-manager network-manager-gnome \
  feh neofetch gnome-disk-utility \
  fonts-ubuntu fonts-hack-ttf \
  git xsettingsd \
  stalonetray rofi

# Ensure desktop services
systemctl enable lightdm
# Switch to NetworkManager (disable netplan/systemd-networkd if in use)
systemctl disable systemd-networkd 2>/dev/null || true
systemctl stop systemd-networkd 2>/dev/null || true
systemctl enable NetworkManager
systemctl start NetworkManager || true

# Make Openbox the default session for LightDM
mkdir -p /usr/share/xsessions
cat >/usr/share/xsessions/openbox.desktop <<'EOF'
[Desktop Entry]
Name=Openbox
Comment=Obuntu Openbox Session
Exec=openbox-session
TryExec=openbox-session
Type=Application
EOF

# --- THEME: Celestial GTK ---
THEME_DIR="/usr/share/themes"
if [[ ! -d "$THEME_DIR/Celestial" ]]; then
  echo "[*] Installing Celestial GTK theme..."
  tmpdir=$(mktemp -d)
  git clone https://github.com/zquestz/celestial-gtk-theme.git "$tmpdir/celestial"
  mkdir -p "$THEME_DIR"
  cp -a "$tmpdir/celestial"/Celestial* "$THEME_DIR"/
  rm -rf "$tmpdir"
fi

# --- FONTS ---
echo "[*] Installing fonts from Ubuntu repositories ..."
apt-get install -y --no-install-recommends \
  fonts-ubuntu \
  fonts-dejavu \
  fonts-hack-ttf \
  fonts-jetbrains-mono \
  fonts-noto-color-emoji \
  fonts-font-awesome

# Note: Full Nerd Fonts (for nnn's icon glyphs) are generally NOT in official Ubuntu repos.
# The above will still look great; for true Nerd Font glyph coverage you'd either:
#  a) add a Nerd Fonts PPA, or
#  b) vendor a single Nerd-patched font file (your previous approach).
# If you stay repo-only, Rofi/eww/plank icons will work via Font Awesome etc.,
# and nnn will still work (just fewer icon glyphs).
fc-cache -f -v || true

# --- CONFIGS into /etc/skel ---
copy_into_skel() {
  local src="$1"
  local dst="/etc/skel"
  [[ -d "$src" ]] || return 0
  echo "[*] Copying default configs into /etc/skel..."
  rsync -a --mkpath "$src"/ "$dst"/
}
copy_into_skel "configs/skel"

# --- CONFIGS into current user (if exists) ---
copy_into_user_home() {
  local user="$1"
  local src="$2"
  [[ -n "$user" && "$user" != "root" ]] || return 0
  [[ -d "$src" ]] || return 0
  local home
  home=$(getent passwd "$user" | cut -d: -f6)
  [[ -d "$home" ]] || return 0

  echo "[*] Copying configs into ~${user} (backups with .bak if needed)..."
  rsync -a --mkpath "$src"/ "$home"/
  chown -R "$user":"$user" "$home"/.profile "$home"/.config 2>/dev/null || true
}
copy_into_user_home "$INVOKER" "configs/skel"

# --- System config (LightDM, environment) ---
if [[ -f "configs/system/lightdm/lightdm.conf" ]]; then
  echo "[*] Installing LightDM config..."
  install -D -m 0644 "configs/system/lightdm/lightdm.conf" "/etc/lightdm/lightdm.conf"
fi

if [[ -f "configs/system/environment" ]]; then
  echo "[*] Setting /etc/environment..."
  install -D -m 0644 "configs/system/environment" "/etc/environment"
fi

# --- PipeWire default; remove pulseaudio if it slipped in ---
systemctl --global enable pipewire pipewire-pulse wireplumber || true
apt-get purge -y pulseaudio || true

# Optional: set wallpaper if provided
if [[ -f "extras/wallpapers/obuntu.png" ]]; then
  install -D -m 0644 "extras/wallpapers/obuntu.png" "/usr/share/backgrounds/obuntu.png"
fi

# Clean
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[*] Obuntu desktop setup complete. Reboot to log in via LightDM."
