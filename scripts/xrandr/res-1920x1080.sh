#!/usr/bin/env bash
# Auto-detect the single connected output if $OUTPUT is not set.
if [ -z "$OUTPUT" ]; then
  OUTPUT=$(xrandr --query | awk '/ connected/{print $1; exit}')
fi
xrandr --output "$OUTPUT" --mode 1920x1080 --rate 60
