#!/usr/bin/env bash
set -euo pipefail
sudo lb clean --purge || true
sudo rm -rf cache chroot binary* iso* .stage config/templates
