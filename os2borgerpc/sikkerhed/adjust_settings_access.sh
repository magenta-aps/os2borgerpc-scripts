#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch, Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

set -ex

ACTIVATE=$1

PROGRAM_PATH="/usr/bin/gnome-control-center"
SHORTCUT_NAME="gnome-control-center.desktop"
SKEL=".skjult"
SHORTCUT_LOCAL_PATH="/home/$SKEL/.local/share/applications/$SHORTCUT_NAME"

# Backwards compatibility - undo the effects of the previous script versions:
# Making sure we're not removing the actual program
if grep --quiet "zenity" "$PROGRAM_PATH"; then
  PROGRAM_HISTORICAL_PATH="$PROGRAM_PATH.real"

  dpkg-statoverride --remove "$PROGRAM_HISTORICAL_PATH" || true
  # Remove the shell script that prints the error message
  rm "$PROGRAM_PATH"
  # Remove location override and restore gnome-settings.real back to gnome-settings
  # TODO: Clean up and go back to dpkg-divert --rename once 20.04 is out of support
  dpkg-divert --remove --no-rename "$PROGRAM_PATH"
  # dpkg-divert can --rename it itself, but the problem with doing that is that in some images
  # dpkg-divert is not used, it was simply moved/copied, so that won't restore it, leaving you
  # with no gnome-control-center
  mv "$PROGRAM_HISTORICAL_PATH" "$PROGRAM_PATH"
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

else # Remove access
  dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true
fi

# For manual verification that there are no related diversions, but possibly a statoverride:
dpkg-divert --list | grep $PROGRAM_PATH || true
dpkg-statoverride --list | grep $PROGRAM_PATH || true
