#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch
#
# This script can remove/restore access to gnome-terminal.
# Background: /usr/bin/gnome-terminal is usually a shell script that points to /usr/bin/gnome-terminal.real.
# Denying access via statoverride to .real is the important one, the other one is done just to hide it from the program list.

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

set -ex

ACTIVATE=$1

PROGRAM_PATH="/usr/bin/gnome-terminal"
SHORTCUT_NAME="org.gnome.Terminal.desktop"
SKEL=".skjult"
SHORTCUT_LOCAL_PATH="/home/$SKEL/.local/share/applications/$SHORTCUT_NAME"

# Also remove the gnome extension that can start gnome terminal, don't stop execution if it fails
apt-get remove --assume-yes nautilus-extension-gnome-terminal || true


### BACKWARDS COMPATIBILITY - cleanup after the previous script versions ###

# There's gnome-terminal and gnome-terminal.real. Previous versions of this script moved that shell script to .real and denied access to that, and then put a custom shell script at gnome-terminal, effectively removing the terminal.
# Also it was possible to reach a state where gnome-terminal was the real one and .real didn't exist.
# This script has some cleanup for handling that.

# Making sure we're not removing the actual program
if grep --quiet "zenity" "$PROGRAM_PATH"; then
  dpkg-statoverride --remove "$PROGRAM_PATH.real" || true
  # Remove the shell script that prints the error message
  rm "$PROGRAM_PATH"
  # Remove location override and restore gnome-terminal.real back to gnome-terminal
  dpkg-divert --remove --rename "$PROGRAM_PATH"
fi

# Make sure the terminal is correctly installed
if [ ! -f "$PROGRAM_PATH" ] || [ ! -f "$PROGRAM_PATH.real" ]; then
  apt-get update
  apt-get install --reinstall --assume-yes gnome-terminal
fi

# Turns out this is unnecessary to hide the program from user's program list
rm --force $SHORTCUT_LOCAL_PATH

### END BACKWARDS COMPATIBILITY ###


if [ "$ACTIVATE" = "True" ]; then # Restore access
  # Remove the permissions override and manually reset permissions to defaults
  # Suppress error to prevent set -e exiting in case the override no longer exists
  # statoverride remove can't change permissions and ownership back by itself currently, unfortunately, so doing that manually
  dpkg-statoverride --remove "$PROGRAM_PATH.real" || true
  dpkg-statoverride --remove "$PROGRAM_PATH" || true
  chown root:root "$PROGRAM_PATH.real" "$PROGRAM_PATH"
  chmod 755 "$PROGRAM_PATH.real" "$PROGRAM_PATH"

else # Deny access
  dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH.real" || true
  dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH" || true
fi

# For manual verification that there are no related diversions, but possibly a statoverride:
dpkg-divert --list | grep $PROGRAM_PATH || true
dpkg-statoverride --list | grep $PROGRAM_PATH || true
