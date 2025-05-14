#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -x

ADD="$1"
DIRECTORY_NAME="${2-dir}"  # Mostly to avoid making files on the desktop itself writable, if run with this argument empty.
READ_ONLY_ACCESS="$3"
FILE_1="$4"
FILE_2="$5"
FILE_3="$6"
FILE_4="$7"
FILE_5="$8"
FILE_6="$9"
FILE_7="${10}"
FILE_8="${11}"
FILE_9="${12}"
FILE_10="${13}"

FILES="$FILE_1 $FILE_2 $FILE_3 $FILE_4 $FILE_5 $FILE_6 $FILE_7 $FILE_8 $FILE_9 $FILE_10"
SKEL=".skjult"

# Removes the argument number that we currently add in front of file names
restore_original_filename() {
  basename "$1" | sed "s/[^_]*_//"
}

FILES_RENAMED=""
for file in $FILES; do
  NEW_NAME="$(restore_original_filename "$file")"
  FILES_RENAMED="$FILES_RENAMED $NEW_NAME"
  mv "$file" "$NEW_NAME"
done

export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")

DESTINATION_DIR=/home/$SKEL/"$DESKTOP"/"$DIRECTORY_NAME"

if [ "$ADD" = "True" ]; then

  mkdir --parents "$DESTINATION_DIR"

  echo "Copying the file arguments to the specified directory:"
  echo "Leaving any files there may already be there be."
  # shellcheck disable=SC2086  # We want word-splitting
  cp $FILES_RENAMED "$DESTINATION_DIR/"

  if [ "$READ_ONLY_ACCESS" = "False" ]; then
    chmod g+w --recursive "$DESTINATION_DIR"
  fi

  echo "Note: You need to logout before the script takes effect!"
else
  echo "Deleting the specified directory:"
  rm --recursive "$DESTINATION_DIR"
fi
