#!/usr/bin/env bash
set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Deploying GTK configs..."
mkdir -p ~/.config/gtk-3.0
cp -v "$REPO_DIR/host/configs/gtk/settings.ini" ~/.config/gtk-3.0/settings.ini
cp -v "$REPO_DIR/host/configs/gtk/gtkrc-2.0" ~/.gtkrc-2.0

echo "Deploying Openbox configs..."
mkdir -p ~/.config/openbox
cp -v "$REPO_DIR/host/configs/openbox/rc.xml" ~/.config/openbox/rc.xml
cp -v "$REPO_DIR/host/configs/openbox/menu.xml" ~/.config/openbox/menu.xml

echo "Deploying X session..."
cp -v "$REPO_DIR/host/configs/x11/.xinitrc" ~/.xinitrc

echo "Deploying Xresources..."
xrdb -merge "$REPO_DIR/host/configs/xresources/.Xresources" || true
mkdir -p ~/.config/xresources
cp -v "$REPO_DIR/host/configs/xresources/.Xresources" ~/.config/xresources/.Xresources

echo "Idle suspend config available (requires sudo):"
echo "sudo mkdir -p /etc/systemd/logind.conf.d"
echo "sudo cp -v $REPO_DIR/host/configs/systemd-logind/idle.conf /etc/systemd/logind.conf.d/idle.conf"
echo "sudo systemctl restart systemd-logind"

if pgrep -x openbox >/dev/null 2>&1; then
  echo "Reloading Openbox..."
  openbox --reconfigure || true
fi
