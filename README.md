# Minimal KVM Host (Ubuntu Server LTS + Openbox)

Minimal Ubuntu Server LTS setup for virtualization with QEMU/KVM, libvirt, virt-manager, and Openbox.  
Includes PipeWire audio, Bluetooth (`bluetui`), Arc-Dark theme, Ubuntu UI font, Hack font for terminal, screenshots & recording (optional), and GPU passthrough ready.

## 🚀 Scripts

### scripts/setup-host.sh
Run as root. Don'd forget to make it executable with sudo chmod +x .
Installs:
- QEMU/KVM, libvirt, virt-manager, OVMF
- Openbox, Xorg, xterm, Arc-Dark theme, Ubuntu & Hack fonts
- PipeWire, WirePlumber, ALSA, Bluetooth (bluetui)
- btop, lm-sensors, slock

Configures:
- Adds user to `libvirt` and `kvm` groups
- Enables linger for user services
- Starts/enables `libvirtd` + `virtlogd`
- Starts and autostarts the default libvirt NAT network

### scripts/deploy-host.sh
Run as normal user. Deploys configs into `$HOME`:
- GTK theme + fonts
- Openbox configs (rc.xml, menu.xml)
- `.xinitrc` (loads `.Xresources`, starts PipeWire)
- `.Xresources` (xterm font/colors)
- monitor resolution switcher

Reloads Openbox if running.

### scripts/startx-autologin.sh
Auto-launch X on tty1 after login. Add to `~/.bash_profile` or `~/.profile`:
```bash
[[ -f ~/minimal-kvm-openbox-host/scripts/startx-autologin.sh ]] && exec ~/minimal-kvm-openbox-host/scripts/startx-autologin.sh
```

### scripts/setup-production.sh
Optional: installs screenshot & recording tools (`scrot`, `simplescreenrecorder`).

Verify PipeWire Audio:
```bash
pactl info | grep "Server Name"
```
Expected: `PulseAudio (on PipeWire 0.3.x)`

Bluetooth pairing use:
```bash
bluetui
```

## Lock & Power
- Lock: `slock` (menu entry)
- Screen off: 10 min (`xset` in `.xinitrc`)
- Suspend: 30 min idle (`configs/systemd-logind/idle.conf`)

## Screenshots
Menu entries: Full, Window, Area. Recording via SimpleScreenRecorder.

## Quick start

```bash
git clone https://github.com/tir-and/ubuntu-qemu-labs-host.git
cd ubuntu-qemu-labs-host
chmod +x scripts/*.sh
./host/base-setup.sh
./host/openbox-deploy.sh
./host/recorder-setup.sh
```
