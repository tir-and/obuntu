#!/usr/bin/env bash
# ==== Obuntu X Session Startup ====

# 1) Import simple key=value pairs from /etc/environment (no shell syntax there)
if [ -f /etc/environment ]; then
  while IFS= read -r line; do
    case "$line" in
      ''|\#*) ;;                     # skip blanks/comments
      *=*) export "$line" ;;
    esac
  done < /etc/environment
fi

# 2) User profile (PATH, aliases, xrdb) — harmless if absent
[ -f "$HOME/.profile" ] && . "$HOME/.profile"

# 3) Make sure Xresources are loaded (colors/fonts for XTerm etc.)
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"

# 4) Optional niceties
command -v xsetroot >/dev/null 2>&1 && xsetroot -cursor_name left_ptr
[ -f /usr/share/backgrounds/obuntu.png ] && feh --bg-scale /usr/share/backgrounds/obuntu.png &

# 5) Hand off to Openbox (this runs ~/.config/openbox/autostart)
exec openbox-session
