#!/usr/bin/env bash
export XDG_CURRENT_DESKTOP=Openbox
export GTK_THEME=Arc-Dark
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
pulseaudio --check || pulseaudio --start &
xset s 600 dpms 600 600 600
dbus-launch --exit-with-session openbox-session
exec openbox-session
