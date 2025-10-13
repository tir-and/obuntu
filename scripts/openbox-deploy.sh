set -euo pipefail
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Deploying GTK configs..."
mkdir -p ~/.config/gtk-3.0
cp -v "$REPO_DIR/configs/gtk/settings.ini" ~/.config/gtk-3.0/settings.ini
cp -v "$REPO_DIR/configs/gtk/gtkrc-2.0" ~/.gtkrc-2.0

echo "Deploying Openbox configs..."
mkdir -p ~/.config/openbox
cp -v "$REPO_DIR/configs/openbox/rc.xml" ~/.config/openbox/rc.xml
cp -v "$REPO_DIR/configs/openbox/menu.xml" ~/.config/openbox/menu.xml

echo "Deploying X session..."
cp -v "$REPO_DIR/configs/x11/.xinitrc" ~/.xinitrc

echo "Deploying Xresources..."
cp -v "$REPO_DIR/configs/xresources/.Xresources" ~/.Xresources
xrdb -merge "$REPO_DIR/configs/xresources/.Xresources" || true

if pgrep -x openbox >/dev/null 2>&1; then
  echo "Reloading Openbox..."
  openbox --reconfigure || true
fi\n\necho "Installing resolution switcher from GitHub (user-level) ..."
mkdir -p "$HOME/.local/bin"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "https://raw.githubusercontent.com/tir-and/bash-resolution-switcher/main/res-xrandr.sh" -o "$HOME/.local/bin/res-xrandr"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$HOME/.local/bin/res-xrandr" "https://raw.githubusercontent.com/tir-and/bash-resolution-switcher/main/res-xrandr.sh"
else
  echo "Warning: neither curl nor wget found. Skipping resolution switcher download."
fi
if [[ -f "$HOME/.local/bin/res-xrandr" ]]; then
  chmod +x "$HOME/.local/bin/res-xrandr"
  echo "Installed: $HOME/.local/bin/res-xrandr"
fi

openbox --reconfigure
