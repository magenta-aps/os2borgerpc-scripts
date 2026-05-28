#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE="$1"

FIREFOX_DESKTOP_SNAP="/var/lib/snapd/desktop/applications/firefox_firefox.desktop"
FIREFOX_DESKTOP_APT="/usr/share/applications/firefox.desktop"
LOCAL_COPY_DIR="/home/.skjult/.local/share/applications"
# Set to be a 16:9 resolution that's hopefully at or above the monitor resolution. GNOME should automatically resize it to fit.
LAUNCH_ARGS="-width 7680 -height 4320"

# Takes a parameter to add to the Exec lines of the desktop files passed as the subsequent arguments
# NOTE: The Firefox Snap desktop file is quite differently formatted compared to a its non-Snap Exec line. Example:
# Exec=env BAMF_DESKTOP_FILE_HINT=/var/lib/snapd/desktop/applications/firefox_firefox.desktop /snap/bin/firefox %u
add_to_desktop_files() {
  PARAMETER="$1"
  shift # Now remove the parameter so we can loop over what remains: The files
  for FILE in "$@"; do
    # Only continue if the particular file exists
    if [ -f "$FILE" ]; then
      # Don't add the parameter multiple times
      if ! grep --quiet -- "$PARAMETER" "$FILE"; then
        # Snap handling
        if ! grep --quiet 'Exec.*/snap/' "$FILE"; then
          sed --in-place "s,\(Exec=\S*\)\(.*\),\1 $PARAMETER\2," "$FILE"
        else
          sed --in-place "s,\(Exec=.*/snap/bin/\S*\)\(.*\),\1 $PARAMETER\2," "$FILE"
        fi
      fi
    fi
  done
}

set -x

if [ -d "/snap/firefox" ]; then
  ORIGINAL_FILE=$FIREFOX_DESKTOP_SNAP
  FIREFOX_DESKTOP_LOCAL_COPY="$LOCAL_COPY_DIR/firefox_firefox.desktop"
else
  ORIGINAL_FILE=$FIREFOX_DESKTOP_APT
  FIREFOX_DESKTOP_LOCAL_COPY="$LOCAL_COPY_DIR/firefox.desktop"
fi

# Ensure that the local copy exists
mkdir --parents "$LOCAL_COPY_DIR"
if [ ! -f "$FIREFOX_DESKTOP_LOCAL_COPY" ]; then
  cp "$ORIGINAL_FILE" "$FIREFOX_DESKTOP_LOCAL_COPY"
fi
# Ensure that the local copy points at the icon correctly
# to prevent the icon from possibly disappearing
# This should no longer be necessary once 24.04 is out of support
sed --in-place "s@Icon=.*@Icon=/snap/firefox/current/default256.png@" "$FIREFOX_DESKTOP_LOCAL_COPY"

if [ "$ACTIVATE" = "True" ]; then
  add_to_desktop_files "$LAUNCH_ARGS" $FIREFOX_DESKTOP_LOCAL_COPY
else
  sed --in-place "s/$LAUNCH_ARGS //" $FIREFOX_DESKTOP_LOCAL_COPY
fi

# This step doesn't seem necessary on 22.04, but it is on 20.04
dconf update
