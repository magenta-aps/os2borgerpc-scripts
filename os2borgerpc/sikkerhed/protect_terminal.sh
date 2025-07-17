#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch

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

# Backwards compatibility - undo the effects of the previous script versions:
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

# Cleanup after previous script versions: Turns out this is unnecessary to hide the program from users program list
rm --force $SHORTCUT_LOCAL_PATH

if [ "$ACTIVATE" = "True" ]; then # Restore access
  # Remove the permissions override and manually reset permissions to defaults
  # Suppress error to prevent set -e exiting in case the override no longer exists
  dpkg-statoverride --remove "$PROGRAM_PATH" || true
  # statoverride remove can't change permissions and ownership back by itself currently, unfortunately
  chown root:root "$PROGRAM_PATH"
  chmod 755 "$PROGRAM_PATH"
  # Do the same for the .real-file
  dpkg-statoverride --remove "$PROGRAM_PATH.real" || true
  chown root:root "$PROGRAM_PATH.real"
  chmod 755 "$PROGRAM_PATH.real"
else # Deny access
  dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true
  dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH.real" || true
fi

# For manual verification that there are no related diversions, but possibly a statoverride:
dpkg-divert --list | grep $PROGRAM_PATH || true
dpkg-statoverride --list | grep $PROGRAM_PATH || true
