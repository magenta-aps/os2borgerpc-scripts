#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen
#
# The admin site currently only accepts up to 2 MiB per request,
# so we ensure that the logs are not larger than this, though it is rarely the case.

REQUESTED_LOG="$1"
APT_LOG="/var/log/apt/history.log"
TMP_LOG="tmp.log"
ADMIN_SITE_MAX_UPLOAD_KIB="2024" # 2 MiB

get_file_size_kilobytes() {
  FILES="$*"
  # shellcheck disable=SC2086  # We want word-splitting to handle multiple apps
  SIZE_IN_KB=$(du -c $FILES | tail --lines 1 | cut --delimiter "	" --fields 1 | grep '[0-9]*')
  [ -z "$SIZE_IN_KB" ] && SIZE_IN_KB=0
  echo "$SIZE_IN_KB"
}

ensure_logs_are_below_supported_size() {
  if [ "$(get_file_size_kilobytes $TMP_LOG)" -le $ADMIN_SITE_MAX_UPLOAD_KIB ]; then
    cat $TMP_LOG
    rm $TMP_LOG
  else
    echo "Size of the base64 encoded log files in MiB:"
    du -h $TMP_LOG
    rm $TMP_LOG
    echo "The requested log files are too large to send to the admin site. Exiting."
    exit 1
  fi
}

print_log() {
  LOG=$1

  # shellcheck disable=SC2129  # Inclined to think this is more readable
  echo "Current log: $LOG" >> $TMP_LOG

  # shellcheck disable=SC2129  # Inclined to think this is more readable
  echo "Size of the log:" >> $TMP_LOG
  du -h "$LOG" >> $TMP_LOG
  echo "Log itself:" >> $TMP_LOG
  echo "" >> $TMP_LOG
  cat "$LOG" >> $TMP_LOG
  echo "" >> $TMP_LOG
}


if [ "$REQUESTED_LOG" = "newest" ]; then
  print_log $APT_LOG
elif [ "$REQUESTED_LOG" = "all" ]; then
  print_log $APT_LOG
  for i in {1..12}; do
    file="$APT_LOG.$i"
    if [ -f "$file.gz" ]; then
      gzip -d "$file.gz"
    fi
    if [ -f "$file" ]; then
      print_log "$file"
      gzip "$file"
    fi
  done
else
  case "$REQUESTED_LOG" in
    1|2|3|4|5|6|7|8|9|10|11|12)
      file="$APT_LOG.$REQUESTED_LOG"
      if [ -f "$file.gz" ]; then
        gzip -d "$file.gz"
      fi
      if [ -f "$file" ]; then
        print_log "$file"
        gzip "$file"
      else
        echo "The specified log does not exist. Exiting."
        exit 1
      fi
      ;;
    *)
      echo "Please specify either: newest, all or a number between 1 and 12. Exiting."
      exit 1
  esac
fi

ensure_logs_are_below_supported_size
