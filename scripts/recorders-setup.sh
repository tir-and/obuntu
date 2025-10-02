#!/usr/bin/env bash\nset -euo pipefail\nREPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"\n\n#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run as root: sudo $0"
  exit 1
fi

apt update
apt install -y --no-install-recommends scrot simplescreenrecorder

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
install -Dm755 "$REPO_DIR/production/scripts/xrandr/res-1920x1080.sh" /usr/local/bin/res-1920x1080
install -Dm755 "$REPO_DIR/production/scripts/xrandr/res-3440x1440.sh" /usr/local/bin/res-3440x1440

echo "Production tools installed."
