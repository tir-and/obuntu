#!/usr/bin/env bash
set -euo pipefail

# Ensure deps
sudo apt-get update
sudo apt-get install -y live-build debootstrap cdebootstrap xorriso squashfs-tools \
    dosfstools mtools syslinux-common syslinux-utils

# Clean prior artifacts
sudo lb clean || true

# Configure (see config/auto/config for flags)
sudo lb config

# Build
sudo lb build
