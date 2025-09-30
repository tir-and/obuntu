#!/usr/bin/env bash
export XDG_CURRENT_DESKTOP=Openbox
export GTK_THEME=Arc-Dark
[ -f ~/.config/xresources/.Xresources ] && xrdb -merge ~/.config/xresources/.Xresources
systemctl --user start pipewire pipewire-pulse wireplumber
xset s 600 dpms 600 600 600
exec openbox-session
