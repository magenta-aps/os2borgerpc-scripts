#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL
#
# SPDX-FileContributor: Danni Als, Marcus Funch, Andreas Poulsen
#
# SYNOPSIS
#    shutdown_at_time.sh <activate> <hours> <minutes>
#
# DESCRIPTION
#    This is a script to make a OS2BorgerPC machine shutdown at a certain time.
#
#    We'll suppose the user only wants to have regular shutdown once a day
#    as specified by the <hours> and <minutes> parameters. Thus, any line in
#    crontab already specifying a shutdown will be deleted before a new one is
#    inserted.

set -x

ACTIVATE=$1
HOURS=$2
MINUTES=${3:-0}

WAKE_PLAN_FILE=/etc/os2borgerpc/plan.json
OUR_USER="user"
ROOTCRON_TMP=/tmp/oldcron
USERCRON=/etc/os2borgerpc/usercron
USER_CLEANUP=/usr/share/os2borgerpc/bin/user-cleanup.bash

if [ -f $WAKE_PLAN_FILE ]; then
  echo "Dette script kan ikke anvendes på en PC, der er tilknyttet en tænd/sluk tidsplan."
  exit 1
fi

if grep "LANG=" /etc/default/locale | grep "da"; then
  MESSAGE="Denne computer lukker ned om fem minutter"
elif grep "LANG=" /etc/default/locale | grep "sv"; then
  MESSAGE="Den här datorn stängs av om fem minuter"
else
  MESSAGE="This computer will shut down in five minutes"
fi

# Read and save current cron settings first
crontab -l > $ROOTCRON_TMP

# Ensure that the usercron-file exists and has the correct permissions
if id $OUR_USER > /dev/null 2>&1; then
  touch $USERCRON
  chmod 700 $USERCRON

  # Delete current crontab entries related to this script AND shutdown_and_wakeup.sh
  sed --in-place "/notify-send/d" $USERCRON
fi

# Delete current crontab entries related to this script AND shutdown_and_wakeup.sh
sed --in-place --expression "/shutdown/d" --expression "/rtcwake/d" --expression "/scheduled_off/d" $ROOTCRON_TMP

if [ "$ACTIVATE" = "True" ]; then

  if [ $# -lt 3 ]; then
    echo "Usage: shutdown_at_time.sh [activate] [hours] [minutes]"
  else
    # Assume the parameters are already validated as integers.
    echo "$MINUTES $HOURS * * * /sbin/shutdown --poweroff now" >> $ROOTCRON_TMP

    # BorgerPC-specific logic
    if id $OUR_USER > /dev/null 2>&1; then
      MINM5P60=$(( $(( MINUTES - 5)) + 60))
      # Rounding minutes
      MINS=$(( MINM5P60 % 60))
      HRCORR=$(( 1 - $(( MINM5P60 / 60))))
      HRS=$(( HOURS - HRCORR))
      HRS=$(( $(( HRS + 24)) % 24))
      # Now output to user's crontab as well
      echo "$MINS $HRS * * * XDG_RUNTIME_DIR=/run/user/\$(id -u) /usr/bin/notify-send \"$MESSAGE\"" >> $USERCRON
    fi
  fi
fi

# Update crontabs accordingly - either with an empty crontab or updated ones
crontab $ROOTCRON_TMP || exit 1
rm --force $ROOTCRON_TMP

if id $OUR_USER > /dev/null 2>&1; then
  crontab -u $OUR_USER $USERCRON || exit 1

  # Ensure that user-cleanup resets the user crontab
  if ! grep --quiet "crontab" "$USER_CLEANUP"; then
    echo "crontab -u $OUR_USER $USERCRON" >> "$USER_CLEANUP"
  fi
fi
