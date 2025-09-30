#!/usr/bin/env bash
OUTPUT=$(xrandr --query | awk '/ connected/{print $1; exit}')
xrandr --output "$OUTPUT" --mode 3440x1440 --rate 60
