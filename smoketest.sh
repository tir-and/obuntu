#!/usr/bin/env bash
set -u

# Colors
RED=$'\e[31m'; GRN=$'\e[32m'; YLW=$'\e[33m'; BLU=$'\e[34m'; RST=$'\e[0m'

PASS=0; FAIL=0; WARN=0
ok(){   printf "${GRN}[OK]${RST} %s\n"   "$1"; ((PASS++)); }
bad(){  printf "${RED}[FAIL]${RST} %s\n" "$1"; ((FAIL++)); }
warn(){ printf "${YLW}[WARN]${RST} %s\n" "$1"; ((WARN++)); }

as_user() {
  # Run a command as the invoking desktop user if possible, else current user
  local U="${SUDO_USER:-$USER}"
  if [[ "$U" != "$USER" && -n "$U" ]]; then
    sudo -u "$U" -- "$@"
  else
    "$@"
  fi
}

header() { printf "\n${BLU}== %s ==${RST}\n" "$1"; }

header "Obuntu Smoke Test"

# 0) Context
echo "User        : ${SUDO_USER:-$USER}"
echo "Hostname    : $(hostname)"
echo "OS          : $(. /etc/os-release; echo "$PRETTY_NAME")"
echo "Kernel      : $(uname -r)"
echo "Time        : $(date)"
echo "DISPLAY     : ${DISPLAY:-<none>}"
echo

# 1) LightDM
header "Display Manager (LightDM)"
if systemctl is-enabled lightdm >/dev/null 2>&1; then
  ok "LightDM is enabled"
else
  bad "LightDM is NOT enabled (systemctl enable lightdm)"
fi
if systemctl is-active lightdm >/dev/null 2>&1; then
  ok "LightDM is active"
else
  bad "LightDM is NOT active (systemctl start lightdm)"
fi

# 2) NetworkManager
header "NetworkManager"
if systemctl is-enabled NetworkManager >/dev/null 2>&1; then
  ok "NetworkManager is enabled"
else
  bad "NetworkManager is NOT enabled"
fi
if systemctl is-active NetworkManager >/dev/null 2>&1; then
  ok "NetworkManager is active"
else
  bad "NetworkManager is NOT active"
fi
if command -v nmcli >/dev/null 2>&1; then
  if nmcli general status >/dev/null 2>&1; then
    ok "nmcli can talk to NetworkManager"
  else
    bad "nmcli cannot talk to NetworkManager"
  fi
else
  bad "nmcli not found (install network-manager-gnome)"
fi

# 3) Audio: PipeWire vs PulseAudio
header "Audio (PipeWire)"
if pgrep -x pipewire >/dev/null 2>&1; then
  ok "pipewire process is running"
else
  bad "pipewire process NOT running"
fi
if pgrep -x wireplumber >/dev/null 2>&1; then
  ok "wireplumber process is running"
else
  bad "wireplumber process NOT running"
fi
if pgrep -x pulseaudio >/dev/null 2>&1; then
  bad "Unexpected pulseaudio process is running (should be removed)"
else
  ok "No pulseaudio process found (good)"
fi

# 4) Openbox session autostarts (just process presence)
header "Openbox session processes"
for p in openbox picom dunst plank nm-applet stalonetray; do
  if pgrep -x "$p" >/dev/null 2>&1; then
    ok "Process running: $p"
  else
    warn "Process not found (maybe fine outside session): $p"
  fi
done

# 5) Tray toggle script + (optional) GUI toggle smoke
header "System tray toggle"
TRAY_SCRIPT="${HOME}/.local/bin/system_tray.sh"
# If running via sudo, check invoking user's home too
if [[ ! -x "$TRAY_SCRIPT" ]]; then
  IU="${SUDO_USER:-}"
  if [[ -n "$IU" ]]; then
    TRAY_SCRIPT="$(getent passwd "$IU" | cut -d: -f6)/.local/bin/system_tray.sh"
  fi
fi
if [[ -x "$TRAY_SCRIPT" ]]; then
  ok "Tray toggle script present: $TRAY_SCRIPT"
else
  bad "Tray toggle script missing or not executable"
fi

if [[ -n "${DISPLAY:-}" ]]; then
  if command -v xdotool >/dev/null 2>&1; then
    # Try to toggle once (non-fatal if no Openbox GUI)
    if as_user "$TRAY_SCRIPT"; then
      ok "Tray toggle invoked (GUI)"
    else
      warn "Tray toggle returned non-zero (possibly no GUI session)"
    fi
  else
    warn "xdotool not available; skipping GUI tray toggle"
  fi
else
  warn "No DISPLAY set; skipping GUI tray toggle"
fi

# 6) Eww presence
header "eww bar"
if command -v eww >/dev/null 2;&1; then
  ok "eww binary found"
else
  warn "eww not found (optional; bar won't start)"
fi
if pgrep -x eww >/dev/null 2>&1; then
  ok "eww process is running"
else
  warn "eww process not running (ensure autostart or start manually)"
fi

# 7) Fonts quick check (Hack Nerd)
header "Fonts"
if fc-list | grep -qi "Hack Nerd"; then
  ok "Hack Nerd Font is installed"
else
  warn "Hack Nerd Font not detected (icons may show as tofu)"
fi

# 8) Files sanity
header "Key files"
want_file() {
  [[ -f "$1" ]] && ok "Found: $1" || bad "Missing: $1"
}
IU="${SUDO_USER:-$USER}"
IH="$(getent passwd "$IU" | cut -d: -f6 2>/dev/null || echo "$HOME")"
want_file "/usr/share/xsessions/openbox.desktop"
want_file "$IH/.config/openbox/autostart"
want_file "$IH/.config/openbox/rc.xml"
want_file "$IH/.config/stalonetrayrc"
want_file "$IH/.config/eww/obuntu/start.sh"
want_file "/etc/lightdm/lightdm.conf"

# Summary
header "Summary"
echo "Passed : $PASS"
echo "Failed : $FAIL"
echo "Warnings: $WARN"
echo

if (( FAIL > 0 )); then
  echo "${RED}Some checks FAILED. Review the messages above.${RST}"
  exit 1
else
  echo "${GRN}All critical checks passed.${RST}"
  exit 0
fi
