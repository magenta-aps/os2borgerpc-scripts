#!/usr/bin/env sh

# SYNOPSIS
#    shutdown_and_wakeup.sh <activate> <hours> <minutes> <hours_to_wake_up> <rtcwake_mode>
#
# DESCRIPTION
#    This is a script to make a OS2BorgerPC machine shutdown at a certain time.
#
#    We'll suppose the user only wants to have regular shutdown once a day
#    as specified by the <hours> and <minutes> parameters. Thus, any line in
#    crontab already specifying a shutdown will be deleted before a new one is
#    inserted.
#    We'll also suppose the user wants the machine to wakeup after X numbers
#     of hours after shutdown everyday.
#
# IMPLEMENTATION
#    author          Danni Als
#    copyright       Copyright 2018, Magenta Aps"
#    license         GNU General Public License

set -x

ACTIVATE=$1
HOURS=$2
MINUTES=${3:-0}
HOURS_TO_WAKE_UP=$4
MODE=$5

WAKE_PLAN_FILE=/etc/os2borgerpc/plan.json
OUR_USER="user"
SCHEDULED_OFF_SCRIPT="/usr/local/lib/os2borgerpc/scheduled_off.sh"
USER_CLEANUP="/usr/share/os2borgerpc/bin/user-cleanup.bash"
ROOTCRON_TMP=/tmp/oldcron
USERCRON=/etc/os2borgerpc/usercron

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

mkdir --parents "$(dirname $SCHEDULED_OFF_SCRIPT)"

# Read and save current cron settings first
crontab -l > $ROOTCRON_TMP

# Ensure that the usercron-file exists and has the correct permissions
if id $OUR_USER > /dev/null 2>&1; then
  touch $USERCRON
  chmod 700 $USERCRON

  # Delete current crontab entries related to this script AND shutdown_at_time
  sed --in-place "/notify-send/d" $USERCRON
fi

# Delete current crontab entries related to this script AND shutdown_at_time
sed --in-place --expression "/rtcwake/d" --expression "/scheduled_off/d" --expression "/shutdown/d" $ROOTCRON_TMP

if [ "$ACTIVATE" = "False" ]; then
  rm --force $SCHEDULED_OFF_SCRIPT
else
  if [ $# -lt 5 ]; then
    echo "Usage: shutdown_and_wakeup.sh [activate] [hours] [minutes] [hours_to_wake_up] [mode]"
  else
    cat <<EOF > $SCHEDULED_OFF_SCRIPT
#!/usr/bin/env sh

MODE=\$1
DURATION=\$2

pkill -KILL -u user
pkill -KILL -u superuser
/usr/sbin/rtcwake --mode \$MODE --seconds \$DURATION
EOF

    chmod 700 $SCHEDULED_OFF_SCRIPT
    SECONDS_TO_WAKEUP=$(( 3600 * HOURS_TO_WAKE_UP))

    # Assume the parameters are already validated as integers.
    echo "$MINUTES $HOURS * * * $SCHEDULED_OFF_SCRIPT $MODE $SECONDS_TO_WAKEUP" >> $ROOTCRON_TMP

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
