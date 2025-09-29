#!/usr/bin/env bash
# Minimal X session for Openbox
export XDG_CURRENT_DESKTOP=Openbox
export GTK_THEME=Arc-Dark

# Screen blank + DPMS after 10 minutes
xset s 600 dpms 600 600 600

exec openbox-session
