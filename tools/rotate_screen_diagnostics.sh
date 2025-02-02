#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch
#
# This script is for diagnostics purposes only - change and add commads
# as needed.
# Currently it lists active monitors, information about them and it then attempts to rotate them

set -x

OUR_USER=chrome
export XAUTHORITY=/home/$OUR_USER/.Xauthority

su --login $OUR_USER --command "xrandr --listactivemonitors -display :0"

# Maybe we want wordsplitting below here, or maybe it doesn't matter.
# shellcheck disable=SC2207
active_monitors=$(su --login $OUR_USER --command "xrandr --listactivemonitors -display :0 | grep -v Monitors | awk '{ print $4; }'")

for monitor in "${active_monitors[@]}"; do
  echo "$monitor"
done

su --login $OUR_USER --command "xrandr --output HDMI1 --rotate right -display :0"
echo $?

su --login $OUR_USER --command "xrandr --query -display :0"
