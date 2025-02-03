#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

# Lists programs available, programs on the desktop or in the launcher
#
# Arguments
#   1: Default is to print programs available/installed. Write 'skrivebord' to list
#      programs already on the desktop, or "menu" to list programs in the launcher.

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

lower() {
    echo "$@" | tr '[:upper:]' '[:lower:]'
}

find_desktop_files_path() {
  PTH_LOCAL=$1
  # - shellcheck says find handles non-alphanumeric file names better than ls
  find "$PTH_LOCAL" -maxdepth 1 | grep --fixed-strings .desktop | xargs basename --suffix .desktop
}

LOCATION="$(lower "$1")"

# Determine the name of the user desktop directory. This is done via xdg-user-dir,
# which checks the /home/user/.config/user-dirs.dirs file. To ensure this file exists,
# we run xdg-user-dirs-update, which generates it based on the environment variable
# LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")
SHADOW_DESKTOP=/home/.skjult/$DESKTOP
SNAP_DESKTOP_FILE_PATH="/var/lib/snapd/desktop/applications"
APT_DESKTOP_FILE_PATH="/usr/share/applications"

if [ "$LOCATION" = "menu" ]; then
  # Print only the last line only and format it a bit more nicely
  tail -n 1 /etc/dconf/db/os2borgerpc.d/02-launcher-favorites | sed "s/favorite-apps=\[\|'\|\]\ \|.desktop//g" | tr ',' '\n'
  exit
elif [ "$LOCATION" = "skrivebord" ] || [ "$LOCATION" = "$DESKTOP" ]; then
  PTH="$SHADOW_DESKTOP/"
else
  PTH=$APT_DESKTOP_FILE_PATH/
  find_desktop_files_path $SNAP_DESKTOP_FILE_PATH
fi

find_desktop_files_path "$PTH"
