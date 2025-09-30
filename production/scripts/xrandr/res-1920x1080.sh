#!/usr/bin/env bash
OUTPUT=$(xrandr --query | awk '/ connected/{print $1; exit}')
xrandr --output "$OUTPUT" --mode 1920x1080 --rate 60
