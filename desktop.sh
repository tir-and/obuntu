#!/usr/bin/env bash
set -euo pipefail

LOG="/var/log/obuntu-desktop.log"
exec > >(tee -a "$LOG") 2>&1

echo "[*] Obuntu desktop setup starting..."

# --- Root check ---
if [[ $EUID -ne 0 ]]; then
  echo "Please run as root: sudo $0"
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

# --- Detect invoking (non-root) user for per-user config copy ---
INVOKER="${SUDO_USER:-$(logname 2>/dev/null || echo '')}"
if [[ -z "$INVOKER" || "$INVOKER" == "root" ]]; then
  echo "[!] Could not detect a non-root user. Per-user config copy will be skipped."
fi
USER_HOME="$(getent passwd "$INVOKER" | cut -d: -f6 || true)"

apt-get update

# --- Add zquestz PPA (plank-reloaded); auto-detect codename for future releases ---
if [[ ! -f /etc/apt/sources.list.d/zquestz.list ]]; then
  echo "[*] Adding zquestz PPA..."
  install -d /usr/share/keyrings
  curl -fsSL https://zquestz.github.io/ppa/ubuntu/KEY.gpg \
    | gpg --dearmor -o /usr/share/keyrings/zquestz-archive-keyring.gpg
  CODENAME="$(. /etc/os-release; echo "$VERSION_CODENAME")"
  echo "deb [signed-by=/usr/share/keyrings/zquestz-archive-keyring.gpg] https://zquestz.github.io/ppa/ubuntu $CODENAME main" \
    > /etc/apt/sources.list.d/zquestz.list
  apt-get update
fi

# --- Desktop packages (lean, with required tools for tray toggle & font unzip) ---
apt-get install -y --no-install-recommends \
  xorg xinit lightdm lightdm-gtk-greeter \
  xdotool x11-utils xdo xdg-utils unzip \
  openbox obconf rofi picom dunst stalonetray \
  plank-reloaded \
  xterm tilda \
  pcmanfm xarchiver nnn \
  gvfs gvfs-backends udisks2 policykit-1 \
  pipewire pipewire-audio pipewire-pulse wireplumber \
  network-manager network-manager-gnome \
  feh neofetch gnome-disk-utility \
  git xsettingsd \
  fonts-ubuntu fonts-noto-color-emoji \
  fonts-hack-ttf fonts-font-awesome curl

# --- Enable display manager and switch networking to NetworkManager ---
systemctl enable lightdm
systemctl disable systemd-networkd 2>/dev/null || true
systemctl stop systemd-networkd 2>/dev/null || true
systemctl enable NetworkManager
systemctl start NetworkManager || true

# --- Make Openbox the default session for LightDM ---
mkdir -p /usr/share/xsessions
cat >/usr/share/xsessions/openbox.desktop <<'EOF'
[Desktop Entry]
Name=Openbox
Comment=Obuntu Openbox Session
Exec=openbox-session
TryExec=openbox-session
Type=Application
EOF

# --- THEME: Celestial GTK (clone and install to /usr/share/themes) ---
THEME_DIR="/usr/share/themes"
if [[ ! -d "$THEME_DIR/Celestial" ]]; then
  echo "[*] Installing Celestial GTK theme..."
  tmpdir="$(mktemp -d)"
  git clone https://github.com/zquestz/celestial-gtk-theme.git "$tmpdir/celestial"
  mkdir -p "$THEME_DIR"
  cp -a "$tmpdir/celestial"/Celestial* "$THEME_DIR"/
  rm -rf "$tmpdir"
fi


# Install Hack Nerd Font for Nerd glyphs (eww/rofi/nnn icons)
HACK_NERD_URL="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/Hack.zip"
FONTS_DIR="/usr/local/share/fonts/HackNerd"
if [[ ! -d "$FONTS_DIR" ]]; then
  echo "[*] Installing Hack Nerd Font ..."
  tmpf="$(mktemp -d)"
  curl -L "$HACK_NERD_URL" -o "$tmpf/HackNerd.zip"
  mkdir -p "$FONTS_DIR"
  unzip -q "$tmpf/HackNerd.zip" -d "$FONTS_DIR"
  rm -rf "$tmpf"
  fc-cache -f -v || true
else
  echo "[*] Hack Nerd Font already present, skipping."
fi

# --- System configs into /etc ---
if [[ -f "configs/system/environment" ]]; then
  install -D -m 0644 "configs/system/environment" "/etc/environment"
fi
if [[ -f "configs/system/lightdm/lightdm.conf" ]]; then
  install -D -m 0644 "configs/system/lightdm/lightdm.conf" "/etc/lightdm/lightdm.conf"
fi

# --- Copy user configs from repo's configs/ into the invoking user's home ---
if [[ -n "$USER_HOME" && -d "$USER_HOME" && -d "configs" ]]; then
  echo "[*] Copying user configs into ~${INVOKER} ..."
  install -d -m 0755 "$USER_HOME/.config"
  install -d -m 0755 "$USER_HOME/.local/bin"

  # Top-level dotfiles (e.g., .profile) — don't clobber if user already has one
  if [[ -f "configs/.profile" && ! -f "$USER_HOME/.profile" ]]; then
    install -m 0644 "configs/.profile" "$USER_HOME/.profile"
  fi

  # Copy .Xresources (XTerm/URxvt theme)
  if [[ -f "configs/.Xresources" ]]; then
    echo "[*] Installing .Xresources for ${INVOKER} ..."
    install -m 0644 "configs/.Xresources" "$USER_HOME/.Xresources"
  fi

  # Symlink .Xdefaults (and host-specific variant) to .Xresources to avoid drift
if [[ -n "$USER_HOME" && -f "$USER_HOME/.Xresources" ]]; then
  ln -sf ".Xresources" "$USER_HOME/.Xdefaults"
  ln -sf ".Xresources" "$USER_HOME/.Xdefaults-$(hostname -s)"
  chown "$INVOKER:$INVOKER" "$USER_HOME/.Xdefaults" "$USER_HOME/.Xdefaults-$(hostname -s)" 2>/dev/null || true
fi

  # Merge .config directory
  rsync -a "configs/.config/" "$USER_HOME/.config/"

  # stalonetray config (you ship configs/stalonetrayrc)
  if [[ -f "configs/stalonetrayrc" ]]; then
    install -D -m 0644 "configs/stalonetrayrc" "$USER_HOME/.config/stalonetrayrc"
  fi

  # Ensure helper scripts are executable
  [[ -f "$USER_HOME/.local/bin/system_tray.sh" ]] && chmod +x "$USER_HOME/.local/bin/system_tray.sh"
  [[ -f "$USER_HOME/.config/eww/obuntu/start.sh" ]] && chmod +x "$USER_HOME/.config/eww/obuntu/start.sh"

  chown -R "$INVOKER:$INVOKER" \
    "$USER_HOME/.config" "$USER_HOME/.profile" "$USER_HOME/.local/bin" 2>/dev/null || true
fi

# --- PipeWire default; remove pulseaudio if it slipped in ---
systemctl --global enable pipewire pipewire-pulse wireplumber || true
apt-get purge -y pulseaudio || true

# --- Optional: set wallpaper if provided ---
if [[ -f "extras/wallpapers/obuntu.png" ]]; then
  install -D -m 0644 "extras/wallpapers/obuntu.png" "/usr/share/backgrounds/obuntu.png"
fi

# --- Clean ---
apt-get autoremove -y
apt-get clean
rm -rf /var/lib/apt/lists/*

echo "[*] Obuntu desktop setup complete. Reboot to log in via LightDM."
