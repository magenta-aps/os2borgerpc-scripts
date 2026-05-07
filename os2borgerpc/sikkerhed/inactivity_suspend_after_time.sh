#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen
#
# DESCRIPTION
#
#   This script will log out the user and suspend the PC after a given period of inactivity.
#   A configurable warning is shown before the user is logged out and the pc suspended.
#
#   The script will also suspend the PC after the same period of inactivity on the login screen.
#   This second part of the script requires "lightdm_greeter_setup_scripts" to be run and enabled to take effect
#
#   The script is designed to wake up the PC 1 minute before a potential scheduled shutdown (on/off-schedule)
#   so that it can be shut down as planned.
#   If no scheduled shutdown exists, it will suspend the PC until it is woken manually.
#
#   This script and "inactivity_logout_after_time.sh" are mutually exclusive, and each of them
#   are written to overwrite each other, so whichever was the last of them run takes effect.
#
# ARGUMENTS
#   1. Checkbox. Enables/disables the script.
#   2. Integer. How many minutes to wait before showing the warning dialog
#   3. Integer. How many minutes to wait before logging out and suspending
#   4. String. (optional) The text to be shown in the warning dialog. If no input is given, a default is used
#   5. String. (optional) The text to be shown on the dialog button. If no input is given, a default is used

set -x

ENABLE=$1
DIALOG_TIME_MINS=$2
LOGOUT_TIME_MINS=$3
DIALOG_TEXT=${4:-"Du er inaktiv og bliver logget ud om kort tid..."}
BUTTON_TEXT=${5:-"OK"}

OUR_USER="user"
SUSPEND_SCRIPT="/usr/share/os2borgerpc/bin/inactive_logout.sh"
SUSPEND_SCRIPT_LOG="/usr/share/os2borgerpc/bin/inactive_logout.log"
GDM_SUSPEND_SCRIPT="/etc/os2borgerpc/post-session-scripts/suspend_after_time.sh"
GDM_SUSPEND_SERVICE="/etc/systemd/system/suspend_after_time.service"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"
LIGHTDM_SUSPEND_SCRIPT="/etc/lightdm/greeter-setup-scripts/suspend_after_time.sh"
LIGHTDM_SUSPEND_SCRIPT_LOG="/etc/lightdm/scriptlogs/suspend_after_time.log"
LIGHTDM_GREETER_SETUP_SCRIPT="/etc/lightdm/greeter_setup_script.sh"
LIGHTDM_GREETER_SCRIPTS_DIR="/etc/lightdm/greeter-setup-scripts"
CRON_D_FILE="/etc/cron.d/os2borgerpc-inactive-logout"

error() {
  echo "$1"
  exit 1
}

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  error "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
fi

# Remove old unnecessary logs
rm --force $SUSPEND_SCRIPT_LOG $LIGHTDM_SUSPEND_SCRIPT_LOG

if grep --quiet gdm3 $DEFAULT_DM_FILE; then
  GREETER_SUSPEND_SCRIPT=$GDM_SUSPEND_SCRIPT
else
  GREETER_SUSPEND_SCRIPT=$LIGHTDM_SUSPEND_SCRIPT
fi

# CLean up after the previous version of this script
OLDCRON="/tmp/oldcron"
crontab -l > $OLDCRON
 if [ -f "$OLDCRON" ]; then
  sed --in-place "\@$SUSPEND_SCRIPT@d" $OLDCRON
  crontab $OLDCRON
  rm --force $OLDCRON
fi

# Handle deactivating inactivity suspend
if [ "$ENABLE" = "False" ]; then
  if [ -f "$GDM_SUSPEND_SERVICE" ]; then
    systemctl disable --now "$(basename $GDM_SUSPEND_SERVICE)"
    rm $GDM_SUSPEND_SERVICE
  fi
  rm --force $SUSPEND_SCRIPT $GREETER_SUSPEND_SCRIPT $CRON_D_FILE
  exit 0
fi

[ -z "$DIALOG_TIME_MINS" ] && error 'Please insert the time the user has to be inactive before dialog is shown.'
[ -z "$LOGOUT_TIME_MINS" ] && error 'Please insert the time the user has to be inactive before being logged out.'
[ "$DIALOG_TIME_MINS" -gt "$LOGOUT_TIME_MINS" ] && error 'Dialog time is greater than logout time and dialog will therefore not be shown. Edit dialog time!'

# org.gnome.Mutter.IdleMonitor.GetIdletime uses milliseconds, so convert the user inputted minutes to that
LOGOUT_TIME_MS=$(( LOGOUT_TIME_MINS * 60 * 1000 ))
DIALOG_TIME_MS=$(( DIALOG_TIME_MINS * 60 * 1000 ))

mkdir --parents "$(dirname $GREETER_SUSPEND_SCRIPT)"

TIMEOUT_SECS=$((LOGOUT_TIME_MINS * 60))

cat << EOF > "$GREETER_SUSPEND_SCRIPT"
#!/usr/bin/env bash

while :
do
  sleep $TIMEOUT_SECS
  if [ -z \$(users) ]; then
    # If the pc has a time plan, don't use systemctl suspend, but instead rtcwake -m mem,
    # which is functionally the same and allows the machine to wake up in time to be shut down
    # by the time plan
    re="([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) .+"
    if [[ \$(crontab -l | grep scheduled_off) =~ \$re ]]; then
      MINUTES=\${BASH_REMATCH[1]}
      HOURS=\${BASH_REMATCH[2]}
      DAY=\${BASH_REMATCH[3]}
      MONTH=\${BASH_REMATCH[4]}
      YEAR=\$(date +%Y)
      # wake up 1 minute before shut down
      MINM1P60=\$(( \$(( MINUTES - 1)) + 60))
      # Rounding minutes
      MINS=\$(( MINM1P60 % 60))
      HRCORR=\$(( 1 - \$(( MINM1P60 / 60))))
      HRS=\$(( HOURS - HRCORR))
      HRS=\$(( \$(( HRS + 24)) % 24))
      rtcwake -m mem --date "\$YEAR-\$MONTH-\$DAY \$HRS:\$MINS"
    else
      systemctl suspend
    fi
  else # A user is logged in
    break
  fi
done

exit 0
EOF

chmod 700 $GREETER_SUSPEND_SCRIPT

if grep --quiet lightdm $DEFAULT_DM_FILE; then
# Older versions of this script used sh, but our lightdm suspend script uses
# bash specifics. Change it to run the script directly with whatever interpreter it has.
# This requires ensuring that lightdm has execute permissions on all those scripts.
  chmod --recursive 700 $LIGHTDM_GREETER_SCRIPTS_DIR
  cat << EOF > $LIGHTDM_GREETER_SETUP_SCRIPT
#!/bin/sh
greeter_setup_scripts=\$(find $LIGHTDM_GREETER_SCRIPTS_DIR -mindepth 1)
for file in \$greeter_setup_scripts
do
    ./"\$file" &
done
EOF

  chmod 700 $LIGHTDM_GREETER_SETUP_SCRIPT

else
  # This service is only needed to run the script just after boot
  cat << EOF > $GDM_SUSPEND_SERVICE
[Unit]
Description=OS2borgerPC suspend_after_time service

[Service]
Type=simple
ExecStart=$GDM_SUSPEND_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable "$(basename $GDM_SUSPEND_SERVICE)"
fi

# Create the cron.d file
cat << EOF > $CRON_D_FILE
* * * * * root $SUSPEND_SCRIPT
EOF

# New auto_logout file, running as root
cat <<- EOF > $SUSPEND_SCRIPT
#!/usr/bin/env bash

# If the user is inactive for too long, a dialog will appear, warning the user that the session will end.
# If the user do not touch the mouse or press any keyboard key the session will end.
# Only have one dialog at a time, so remove preexisting ones.
# Create a new message every time, in case someone didn't close it but
# just put e.g. a browser in front, to ensure they or someone else gets a
# new warning when/if inactivity is reached again

# There doesn't seem to be a way to determine the DISPLAY that works
# for both Wayland and Xorg so we try one method and then the other
# if the first returns nothing. Xorg first
USER_DISPLAY=\$(who | grep -w '$OUR_USER' | sed -rn 's/.*\((:[0-9]*)\).*/\1/p')
if [ -z "\$USER_DISPLAY" ]; then
  USER_DISPLAY=\$(find /tmp/.X11-unix/ -user $OUR_USER -type s -printf "%f\n" | sort -g | head -n 1 | tr X :)
fi
export DISPLAY=\$USER_DISPLAY

# If we are using Wayland, it is also necessary to export its XAUTHORITY, which
# changes every login
WAYLAND_XAUTHORITY=\$(find /var/run/user/\$(id -u $OUR_USER)/ -maxdepth 1 -iname ".mutter-Xwaylandauth.*" -print -quit)
# Only export Waylands XAUTHORITY if it exists (i.e. we are using Wayland) to prevent problems
# when using Xorg
if [ ! -z "\$WAYLAND_XAUTHORITY" ]; then
  export XAUTHORITY=\$WAYLAND_XAUTHORITY
fi

IDLE_TIME=\$(DBUS_SESSION_BUS_ADDRESS="unix:path=/var/run/user/\$(id -u $OUR_USER)/bus" runuser -u $OUR_USER -- dbus-send --print-reply --dest=org.gnome.Mutter.IdleMonitor /org/gnome/Mutter/IdleMonitor/Core org.gnome.Mutter.IdleMonitor.GetIdletime | grep "uint64" | cut --delimiter " " --fields 5)

# If the pc has a time plan, don't use systemctl suspend, but instead rtcwake -m mem,
# which is functionally the same and allows the machine to wake up in time to be shut down
# by the time plan

if [ \$IDLE_TIME -ge $LOGOUT_TIME_MS ]; then
  pkill -KILL -u $OUR_USER
  # If the pc has a time plan, don't use systemctl suspend, but instead rtcwake -m mem,
  # which is functionally the same and allows the machine to wake up in time to be shut down
  # by the time plan
  re="([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) .+"
  if [[ \$(crontab -l | grep scheduled_off) =~ \$re ]]; then
    MINUTES=\${BASH_REMATCH[1]}
    HOURS=\${BASH_REMATCH[2]}
    DAY=\${BASH_REMATCH[3]}
    MONTH=\${BASH_REMATCH[4]}
    YEAR=\$(date +%Y)
    # wake up 1 minute before shut down
    MINM1P60=\$(( \$(( MINUTES - 1)) + 60))
    # Rounding minutes
    MINS=\$(( MINM1P60 % 60))
    HRCORR=\$(( 1 - \$(( MINM1P60 / 60))))
    HRS=\$(( HOURS - HRCORR))
    HRS=\$(( \$(( HRS + 24)) % 24))
    # When run from the crontab, rtcwake needs the full path for some reason or it won't work
    /usr/sbin/rtcwake -m mem --date "\$YEAR-\$MONTH-\$DAY \$HRS:\$MINS"
  else
    systemctl suspend
  fi
  exit 0
fi
# if idle time is past the dialog time: show the dialog
if [ \$IDLE_TIME -ge $DIALOG_TIME_MS ]; then
  # Do spare the poor lives of potential other zenity windows.
  PID_ZENITY="\$(pgrep --full 'Inaktivitet')"
  if [ -n "\$PID_ZENITY" ]; then
    kill \$PID_ZENITY
  fi
  # We use the --title to match against above
  runuser -u $OUR_USER -- zenity --warning --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT" --no-wrap --title "Inaktivitet"
fi
EOF

chmod 700 $SUSPEND_SCRIPT
