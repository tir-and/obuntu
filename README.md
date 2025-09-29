# Minimal KVM Host (Ubuntu Server LTS + Openbox)

A lean host setup for running multiple Windows & Linux VMs with QEMU/KVM/libvirt/virt-manager, Openbox as a minimal X11 window manager, PipeWire audio, and **no icon theme**. Includes manual GTK theming (Arc-Dark), Ubuntu UI font (size 10), and Hack for terminals. GPU passthrough is documented but **not enabled by default**.

## Features
- Ubuntu Server LTS minimal base
- QEMU/KVM + libvirt + virt-manager + OVMF (UEFI)
- Openbox + Arc-Dark borders (no icon theme)
- Manual GTK config (GTK2 + GTK3) with Ubuntu Regular 10 UI font
- PipeWire + WirePlumber + ALSA, Bluetooth with `bluetui`
- Resolution switch helpers (3440×1440 ↔ 1920×1080)
- Templates for systemd-networkd bridge networking (no NAT/DHCP unless you add dnsmasq)
- **Lock screen via `slock` (lightweight)**
- **Idle power management**: screen off after 10 min (xset), suspend after 30 min (systemd-logind snippet)
- Optional tools: `virt-viewer`, `cockpit-machines` (not installed by default)
- **No** fwupd, **No** Timeshift/Snapper, **No** Docker (can add later)

---

## 1) Install packages (one-liner)

```bash
sudo apt update
sudo apt install --no-install-recommends qemu-kvm libvirt-daemon-system virt-manager ovmf bridge-utils pciutils xorg openbox obconf scrot simplescreenrecorder xrandr arandr pipewire wireplumber alsa-utils bluez bluetui arc-theme fonts-ubuntu fonts-hack git curl wget unzip ssh btop lm-sensors slock
```

Add your user to libvirt/kvm groups:
```bash
sudo usermod -aG libvirt,kvm $USER
newgrp libvirt
```

(Optional) If you plan to run `startx` from TTY:
```bash
sudo apt install --no-install-recommends xinit
```

---

## 2) Deploy configs

Copy the contents of `configs/` into your home directory or run `./deploy.sh`:

```bash
# GTK (GTK3 and GTK2)
mkdir -p ~/.config/gtk-3.0
cp -v configs/gtk/settings.ini ~/.config/gtk-3.0/settings.ini
cp -v configs/gtk/gtkrc-2.0 ~/.gtkrc-2.0

# Openbox
mkdir -p ~/.config/openbox
cp -v configs/openbox/rc.xml ~/.config/openbox/rc.xml
cp -v configs/openbox/menu.xml ~/.config/openbox/menu.xml

# X session (startx)
cp -v configs/x11/.xinitrc ~/.xinitrc

# xrandr helpers
mkdir -p ~/.local/bin
cp -v scripts/xrandr/res-1920x1080.sh ~/.local/bin/
cp -v scripts/xrandr/res-3440x1440.sh ~/.local/bin/
chmod +x ~/.local/bin/res-*.sh
```

Reload Openbox if already running:
```bash
openbox --reconfigure
```

---

## 3) Enable PipeWire services

```bash
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```
If you see an error about lingering, allow user services:
```bash
sudo loginctl enable-linger "$USER"
systemctl --user enable --now pipewire pipewire-pulse wireplumber
```

---

## 4) Networking (systemd-networkd, bridge)

Templates are under `configs/systemd-networkd/`. Adjust interface names to your hardware (e.g., `enp3s0`), then:

```bash
sudo mkdir -p /etc/systemd/network
sudo cp -v configs/systemd-networkd/*.netdev /etc/systemd/network/
sudo cp -v configs/systemd-networkd/*.network /etc/systemd/network/
sudo systemctl enable --now systemd-networkd
sudo systemctl restart systemd-networkd
```

This creates a `br0` bridge and puts your wired NIC into it. libvirt can attach VMs to `br0` for full LAN access. No `dnsmasq`/NAT unless you explicitly add it.

---

## 5) GPU Passthrough (Reference Only)

See `docs/gpu-passthrough.md` for a safe, step-by-step **reference**. It includes: enabling IOMMU, checking groups, binding devices to `vfio-pci`, OVMF setup, hugepages (optional), and Windows virtio driver install. **Not enabled by default.**

---

## 6) Screen capture, lock & resolution

- Screenshots: `scrot` (menu has Full/Window/Area)
- Screen recording: `simplescreenrecorder`
- Lock screen: `slock` (menu entry included)
- Resolution switchers:  
  - `~/.local/bin/res-3440x1440.sh`
  - `~/.local/bin/res-1920x1080.sh`
  (Auto-detects the connected output if `$OUTPUT` is unset.)

---

## 7) Idle power management

- **Screen off after 10 minutes:** handled via `xset` in `.xinitrc`
- **Suspend after 30 minutes idle:** copy `configs/systemd-logind/idle.conf` to `/etc/systemd/logind.conf.d/` then restart `systemd-logind`

---

## 8) Updating from GitHub on the Host

**Option A: Copy-based (simple)**
```bash
git clone https://github.com/<you>/minimal-kvm-host.git
cd minimal-kvm-host
chmod +x deploy.sh
./deploy.sh
# Later updates:
git pull
./deploy.sh
```

**Option B: Symlink-based (advanced)**
Keeps files in-place and links them to your home:
```bash
# Example for GTK3
mkdir -p ~/.config/gtk-3.0
ln -sf $(pwd)/configs/gtk/settings.ini ~/.config/gtk-3.0/settings.ini
# Repeat for other files...
```
Then `git pull` updates take effect immediately (no copy). Consider `stow` for cleaner dotfile management.

---

## License
MIT
