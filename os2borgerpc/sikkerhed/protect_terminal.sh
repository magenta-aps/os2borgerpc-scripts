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
SKEL=".skjult"
SHORTCUT_NAME="org.gnome.Terminal.desktop"
SHORTCUT_GLOBAL_PATH="/usr/share/applications/$SHORTCUT_NAME"
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

if [ "$ACTIVATE" = "True" ]; then # Restore access
  # Remove the permissions override and manually reset permissions to defaults
  # Suppress error to prevent set -e exiting in case the override no longer exists
  dpkg-statoverride --remove "$PROGRAM_PATH" || true
  # statoverride remove can't change permissions and ownership back by itself currently, unfortunately
  chown root:root "$PROGRAM_PATH"
  chmod 755 "$PROGRAM_PATH"

  rm --force $SHORTCUT_LOCAL_PATH
else # Deny access
  dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true
  # Additionally remove the program from Borgers program list for UX/cosmetic reasons (rather than security)
  mkdir --parents "$(dirname $SHORTCUT_LOCAL_PATH)"
  install --mode o-r $SHORTCUT_GLOBAL_PATH $SHORTCUT_LOCAL_PATH
fi

# For manual verification that there are no related diversions, but possibly a statoverride:
dpkg-divert --list | grep $PROGRAM_PATH || true
dpkg-statoverride --list | grep $PROGRAM_PATH || true
