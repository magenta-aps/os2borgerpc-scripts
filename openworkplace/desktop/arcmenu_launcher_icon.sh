#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

# Removes the argument number that we currently add in front of file names
restore_original_filename() {
  basename "$1" | sed "s/[^_]*_//"
}

IMAGE_FILENAME="$1"
SIZE="${2:-30}"

set -x

ORIGINAL_IMAGE_FILE_NAME=$(restore_original_filename "$IMAGE_FILENAME")
ORIGINAL_IMAGE_FILE_PATH=/usr/share/os2borgerpc/images/$ORIGINAL_IMAGE_FILE_NAME

mkdir --parents "$(dirname "$ORIGINAL_IMAGE_FILE_PATH")"
mv "$IMAGE_FILENAME" "$ORIGINAL_IMAGE_FILE_PATH"

if [ -f /etc/dconf/db/os2borgerpc.d/50-arcmenu ]; then
  sed --in-place --expression "s@^\(menu-button-icon=\).*@\1'$ORIGINAL_IMAGE_FILE_PATH'@" \
      --expression "s@^\(menu-button-icon-size=\).*@\1$SIZE@" \
      /etc/dconf/db/os2borgerpc.d/50-arcmenu
  dconf update
else
  echo "ArcMenu policy wasn't found. Is the ArcMenu extension installed?"
  exit 1
fi
