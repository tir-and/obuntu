#!/usr/bin/env bash
# Auto-detect the single connected output if $OUTPUT is not set.
if [ -z "$OUTPUT" ]; then
  OUTPUT=$(xrandr --query | awk '/ connected/{print $1; exit}')
fi
xrandr --output "$OUTPUT" --mode 3440x1440 --rate 60
