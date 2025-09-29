#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "[1/5] Deploy GTK configs"
mkdir -p ~/.config/gtk-3.0
cp -v "$REPO_DIR/configs/gtk/settings.ini" ~/.config/gtk-3.0/settings.ini
cp -v "$REPO_DIR/configs/gtk/gtkrc-2.0" ~/.gtkrc-2.0

echo "[2/5] Deploy Openbox configs"
mkdir -p ~/.config/openbox
cp -v "$REPO_DIR/configs/openbox/rc.xml" ~/.config/openbox/rc.xml
cp -v "$REPO_DIR/configs/openbox/menu.xml" ~/.config/openbox/menu.xml

echo "[3/5] Deploy X session"
cp -v "$REPO_DIR/configs/x11/.xinitrc" ~/.xinitrc

echo "[4/5] Deploy resolution scripts"
mkdir -p ~/.local/bin
cp -v "$REPO_DIR/scripts/xrandr/"res-*.sh ~/.local/bin/
chmod +x ~/.local/bin/res-*.sh

echo "[5/5] (Optional) Install systemd-logind idle suspend config (requires sudo)"
echo "    sudo mkdir -p /etc/systemd/logind.conf.d"
echo "    sudo cp -v "$REPO_DIR/configs/systemd-logind/idle.conf" /etc/systemd/logind.conf.d/idle.conf"
echo "    sudo systemctl restart systemd-logind"

# Try to reconfigure Openbox if it's running
if pgrep -x openbox >/dev/null 2>&1; then
  echo "Reloading Openbox..."
  openbox --reconfigure || true
fi

echo "Done. Tip: set your terminal to use the Hack font."
