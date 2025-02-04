#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen
#
# Feel very free to expand with other useful info to gather to debug security events!

help() {
  printf '%s\n' "This script helps debug security events." \
                "Available options:" \
                "  No arguments: Runs everything below" \
                "  authlog: Prints the chosen number of lines from auth.log" \
                "  syslog: Prints the chosen number of lines from syslog" \
                "  sudo: Prints the chosen number of sudo entries from auth.log" \
                "  usermod: Prints the chosen number of usermod entries from auth.log"
  exit
}

COMMAND=$1
NUM_ENTRIES=$2

SECURITY_DIR="/etc/os2borgerpc/security"
SECURITY_SCRIPTS_LOG_FILE="$SECURITY_DIR/security_log.txt"
SECURITY_EVENTS="$SECURITY_DIR/securityevent.csv"
LAST_CHECK="$SECURITY_DIR/lastcheck.txt"
NUM_SECURITY_LOG_ENTRIES=100

[ -z "$COMMAND" ] && COMMAND="all"
[ -z "$NUM_ENTRIES" ] && NUM_ENTRIES=400

print_authlog() {
    printf "\n\n%s\n\n" "PRINTING THE $NUM_ENTRIES LAST LINES OF AUTH.LOG"
    tail --lines="$NUM_ENTRIES" /var/log/auth.log
}

print_syslog() {
    printf "\n\n%s\n\n" "PRINTING THE $NUM_ENTRIES LAST LINES OF SYSLOG"
    tail --lines="$NUM_ENTRIES" /var/log/syslog
}

print_usb_event_log() {
    if [ -f "/var/log/usb-events.log" ]; then
      printf "\n\n%s\n\n" "PRINTING THE $NUM_ENTRIES LAST LINES OF USB-EVENTS.LOG"
      tail --lines="$NUM_ENTRIES" /var/log/usb-events.log
    else
      printf "\n\n%s\n\n" "USB-EVENTS.LOG DOES NOT EXIST"
    fi
}

# Older log files are gzipped automatically. Unzip them first.
uncompress_old_logs() {
    LOG="$1"
    # Note: There may be even older log files, so add more if needed
    gunzip --force "/var/log/$LOG.1.gz" "/var/log/$LOG.2.gz" "/var/log/$LOG.3.gz" 2>/dev/null
}

# Grep log files for a keyword (e.g. sudo, usermod etc.)
print_log_lines() {
  KEYWORD="$1"
  LOG_FILE="$2"

  # Loop through both current logfiles and backups of older ones
  for f in "/var/log/$LOG_FILE"*; do
    echo "Checking the following log file: $f"
    grep "$KEYWORD" "$f" | tail --lines="$NUM_ENTRIES"
  done
}

# Sudo security script related
print_sudo_entries() {
    printf "\n\n%s\n\n" "PRINTING THE $NUM_ENTRIES LAST SUDO ENTRIES IN AUTH.LOG FILES"
    uncompress_old_logs auth.log
    print_log_lines sudo auth.log
}

# Detect locked user script related (and it also prints when the expiration is reversed)
print_usermod_entries() {
    printf "\n\n%s\n\n" "PRINTING THE $NUM_ENTRIES LAST USERMOD ENTRIES IN AUTH.LOG FILES"
    uncompress_old_logs auth.log
    print_log_lines usermod auth.log
}

# TODO: Add similar filtering functions for keyboard events + USB events

# Runs everything
run_all() {
    print_authlog
    print_syslog
    print_usb_event_log
    print_sudo_entries
    print_usermod_entries
}

echo "Print OS2borgerPC client version, as older clients do not always support new security scripts"
grep "client" /etc/os2borgerpc/os2borgerpc.conf

# TODO: Improve the client's logging for security scripts, as this is pretty unhelpful. Fx. add timestamps, and print
# the relevant info when a security event was found.
echo "Print a list of files in /etc/os2borgerpc/security"
ls -l $SECURITY_DIR

echo "Print the contents of lastcheck"
cat $LAST_CHECK

echo "Print the last $NUM_SECURITY_LOG_ENTRIES entries of security_log.txt"
tail --lines=$NUM_SECURITY_LOG_ENTRIES $SECURITY_SCRIPTS_LOG_FILE

echo "Print the contents of securityevent.csv"
cat $SECURITY_EVENTS

if [ "$COMMAND" = "all" ]; then
  run_all
elif [ "$COMMAND" = "authlog" ]; then
  print_authlog
elif [ "$COMMAND" = "syslog" ]; then
  print_syslog
elif [ "$COMMAND" = "usb-events" ]; then
  print_usb_event_log
elif [ "$COMMAND" = "sudo" ]; then
  print_sudo_entries
elif [ "$COMMAND" = "usermod" ]; then
  print_usermod_entries
else
  help
fi
