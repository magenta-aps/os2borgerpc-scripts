#!/usr/bin/env sh

# Consider merging this with "debug_security_events". The advantage of this script is that it can handle larger logs,
# and logs that may contain special characters.
# It could potentially be adjusted slightly to also allow it to optionally send .1 files, and the already gzipped .n files
#
# The admin site currently only accepts up to 2 MiB per request,
# and these logs are often larger than that, hence the compression.
#
# Base64 encoding is used as xmlrpc might not handle all the special characters correctly, or the adminsite may not
# display them correctly

REQUESTED_LOG="$1"

AUTHLOG=/var/log/auth.log
SYSLOG=/var/log/syslog
KERNLOG=/var/log/kern.log
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
  echo "Log itself, base64 encoded to reduce the transfer size and remove special characters:" >> $TMP_LOG
  echo "" >> $TMP_LOG
  gzip -c "$LOG" | base64 >> $TMP_LOG
  echo "" >> $TMP_LOG
}

if [ "$REQUESTED_LOG" = "all" ]; then
  print_log $AUTHLOG
  print_log $SYSLOG
  print_log $KERNLOG
elif [ "$REQUESTED_LOG" = "auth" ]; then
  print_log $AUTHLOG
elif [ "$REQUESTED_LOG" = "sys" ]; then
  print_log $SYSLOG
elif [ "$REQUESTED_LOG" = "kern" ]; then
  print_log $KERNLOG
else
  echo "Please specify either: sys, auth, kern or all. Exiting."
  exit 1
fi

ensure_logs_are_below_supported_size
