#!/usr/bin/env bash
set -e
TRAY_TITLE="stalonetray"

if ! pgrep -x stalonetray >/dev/null; then
  stalonetray & disown
  sleep 0.3
fi

WID=$(xdotool search --name "$TRAY_TITLE" 2>/dev/null | head -n1 || true)
if [[ -z "$WID" ]]; then
  exit 0
fi

STATE=$(xprop -id "$WID" _NET_WM_STATE 2>/dev/null | tr -d '\n')
if [[ "$STATE" == *"_NET_WM_STATE_HIDDEN"* ]]; then
  # show
  xdotool windowmap "$WID"
  xdo raise -N "$TRAY_TITLE" || true
else
  # hide
  xdotool windowunmap "$WID"
fi
