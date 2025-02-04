#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch with credits to Gladsaxe municipality

# Moves the Ubuntu dock system wide to an edge of your choosing, and possibly the app launcher to the start of the menu instead of the end (default)
# If it doesn't take effect immediately, try restarting.
#
# Arguments:
#   1: Where the dock/menu should be located. Valid options are: top, left, right, bottom.
#   2: Where the app launcher should be located in the menu. Valid options are: true (top), false (bottom - which is default)

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

lower() {
    echo "$@" | tr '[:upper:]' '[:lower:]'
}

# gsettings equivalent: gsettings set org.gnome.shell.extensions.dash-to-dock dock-position BOTTOM
POSITION="$1"
APPS_LAUNCHER_AT_TOP="$(lower "$2")" # Expects True/False, case insensitively

POLICY_FILE_NAME="03-menu-position"

cat <<- EOF > /etc/dconf/db/os2borgerpc.d/$POLICY_FILE_NAME
  [org/gnome/shell/extensions/dash-to-dock]
  dock-position='$POSITION'
  show-apps-at-top=$APPS_LAUNCHER_AT_TOP
EOF

cat <<- EOF > /etc/dconf/db/os2borgerpc.d/locks/$POLICY_FILE_NAME
  /org/gnome/shell/extensions/dash-to-dock/dock-position
  /org/gnome/shell/extensions/dash-to-dock/show-apps-at-top
EOF

dconf update
