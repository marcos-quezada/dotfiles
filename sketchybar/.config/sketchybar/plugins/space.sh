#!/bin/bash

# $SELECTED is set by sketchybar for space components — true when this space is active
# https://felixkratz.github.io/SketchyBar/config/components#space----associate-mission-control-spaces-with-an-item

# shellcheck source=/dev/null  # path is dynamic; sourced at runtime by sketchybar
source "$CONFIG_DIR/colors.sh"

if [ "$SELECTED" = true ]; then
  sketchybar --set "$NAME" background.drawing=on \
                           background.color="$ACCENT_COLOR" \
                           label.color="$BAR_COLOR" \
                           icon.color="$BAR_COLOR"
else
  sketchybar --set "$NAME" background.drawing=off \
                           label.color="$ACCENT_COLOR" \
                           icon.color="$ACCENT_COLOR"
fi
