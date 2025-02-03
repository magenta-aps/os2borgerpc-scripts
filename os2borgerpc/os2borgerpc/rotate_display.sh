#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als
#
# SYNOPSIS
#    rotate_display.sh [normal/right/left]
#
# DESCRIPTION
#    This script looks for all displays connected and rotates the first one from the list.
#
#    It takes one mandatory parameter. The direction of the rotation.
#    Based on xrandr. From xrandr manual:
#    "Rotation can be one of 'normal', 'left', 'right' or 'inverted'. This causes the output contents to be
#    rotated in the specified direction. 'right' specifies a clockwise rotation of the picture and  'left'
#    specifies a counter-clockwise rotation."

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

set -ex

if [ "$1" != "normal" ] && [ "$1" != "right" ] && [ "$1" != "left" ]; then
    echo "Wrong rotation command given: $1"
    exit 1
fi

AUTOSTART_FOLDER=/home/.skjult/.config/autostart/

mkdir --parents $AUTOSTART_FOLDER

ROTATE_SCREEN_FILE=rotate_screen.sh
ROTATE_SCREEN_FILE_COMPLETE_PATH="$AUTOSTART_FOLDER$ROTATE_SCREEN_FILE"

cat <<EOT > "$ROTATE_SCREEN_FILE_COMPLETE_PATH"
#!/bin/bash

active_monitors=\$(xrandr --listactivemonitors | grep -oE ' (e?)DP-[0-9](-?[0-9]?)(-?[0-9]?)')

active_monitors_array=(\$active_monitors)

xrandr --output \${active_monitors_array[0]} --rotate $1
EOT

chmod +x $ROTATE_SCREEN_FILE_COMPLETE_PATH

echo "$ROTATE_SCREEN_FILE_COMPLETE_PATH created/updated with rotation $1"

DESKTOP_FILENAME=rotate_screen.desktop
DESKTOPFILE_COMPLETE_PATH="$AUTOSTART_FOLDER$DESKTOP_FILENAME"
if [ -f $DESKTOPFILE_COMPLETE_PATH ]; then
  exit 0
fi

cat <<EOT >> "$DESKTOPFILE_COMPLETE_PATH"
[Desktop Entry]
Type=Application
Exec=$ROTATE_SCREEN_FILE_COMPLETE_PATH
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name[en_US]=rotate screen
Name=rotate screen
Comment[en_US]=Rotates Primary monitor $1
Comment=Rotates Primary monitor $1
EOT

chmod +x $DESKTOPFILE_COMPLETE_PATH

echo "$DESKTOPFILE_COMPLETE_PATH created..."
exit 0
