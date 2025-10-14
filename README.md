ubuntu-qemu-host

Minimal, fast Ubuntu Server (Minimal) → KVM virtualization host.
Optionally adds a tiny Openbox + LightDM GUI for running virt-manager locally.

Features

- Lean base (purges snapd, cloud-init, unattended upgrades, etc.)
- Full KVM/libvirt stack (QEMU, OVMF/UEFI, virt-manager/virt-viewer)
- Optional tiny GUI (Openbox + LightDM) or headless
- Optional USB automount (udisks2 + gvfs)
- Optional minimal audio (PulseAudio)
- Convenience tools (btop, git, fonts, xclip, etc.)
- Optional deployment of repo configs/ (Openbox menu, Xresources, logind idle)

```
# (Recommended) Update APT and get tiny bootstrap tools
sudo apt update && sudo apt install -y --no-install-recommends ca-certificates git wget

# Run the installer with defaults (GUI ON, audio OFF)
sudo bash -c "$(wget -qO- https://raw.githubusercontent.com/tir-and/ubuntu-qemu-host/main/setup-ubuntu-qemu-host.sh)"
```

Available vars and defaults:

Var	Default	Meaning
GUI	1	1 = install Openbox + LightDM + virt-manager, 0 = headless

USB_AUTOMOUNT	1	Install udisks2 + gvfs for USB automount
AUDIO	0	1 = minimal host audio (PulseAudio + ALSA)
USE_TIMESYNCD	1	Replace chrony with systemd-timesyncd
INSTALL_CONVENIENCE	1	Tools/fonts/themes (btop, git, fonts, arc-theme, etc.)
INSTALL_ARC_OB_THEME	1	Fetch Arc Openbox theme to /usr/share/themes
ENSURE_DEFAULT_NET	1	Ensure/start libvirt default NAT network
DEPLOY_REPO_CONFIGS	1	Copy configs from this repo into the user’s home

What gets installed
Virtualization: qemu-system-x86, qemu-utils, qemu-system-modules-spice,
libvirt-daemon-system, libvirt-clients, bridge-utils, virtinst, virt-viewer,
ovmf, pciutils, gir1.2-spiceclientgtk-3.0.
GUI (if GUI=1): xorg, openbox, lightdm, lightdm-gtk-greeter, xterm, x11-xserver-utils,
virt-manager, policykit-1, dbus-x11, adwaita-icon-theme, fonts-dejavu, scrot, xinit.
USB automount (if USB_AUTOMOUNT=1): udisks2, gvfs.
Audio (if AUDIO=1): pulseaudio, alsa-utils.
Convenience (if INSTALL_CONVENIENCE=1): arc-theme, fonts-ubuntu, fonts-hack,
git, curl, wget, unzip, btop, lm-sensors, suckless-tools, nano, xclip.
All installs use --no-install-recommends to keep things lean.

What gets removed / blocked
Removed: cloud-init, unattended-upgrades, update-notifier-common, snapd,
rsyslog, apport, whoopsie, network-manager, avahi-daemon, cups*,
bluez, blueman, modemmanager (and chrony if USE_TIMESYNCD=1).
Held (blocked from re-install): snapd, apport, whoopsie, cloud-init, avahi-daemon.
