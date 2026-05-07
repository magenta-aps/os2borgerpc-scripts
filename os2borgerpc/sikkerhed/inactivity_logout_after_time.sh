#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2017 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als
#
# This script and "inactivity_suspend_after_time.sh" are mutually exclusive, and each of them
# are written to overwrite each other, so whichever was the last of them run takes effect.
#
# Arguments
#   1. Checkbox. Enables/disables the script.
#   2. Integer. How many minutes to wait before showing the warning dialog
#   3. Integer. How many minutes to wait before logging out
#   4. String. (optional) The text to be shown in the warning dialog. If no input is given, a default is used
#   5. String. (optional) The text to be shown on the dialog button. If no input is given, a default is used

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ENABLE=$1
DIALOG_TIME_MINS=$2
LOGOUT_TIME_MINS=$3
DIALOG_TEXT=${4:-"Du er inaktiv og bliver logget ud om kort tid..."}
BUTTON_TEXT=${5:-"OK"}

OUR_USER="user"
INACTIVITY_SCRIPT="/usr/share/os2borgerpc/bin/inactive_logout.sh"
INACTIVITY_SCRIPT_LOG="/usr/share/os2borgerpc/bin/inactive_logout.log"
LIGHTDM_SCRIPT="/etc/lightdm/greeter-setup-scripts/suspend_after_time.sh"
GDM_SCRIPT="/etc/os2borgerpc/post-session-scripts/suspend_after_time.sh"
GDM_SUSPEND_SERVICE="/etc/systemd/system/suspend_after_time.service"
CRON_D_FILE="/etc/cron.d/os2borgerpc-inactive-logout"

error() {
  echo "$1"
  exit 1
}

# Remove old unnecessary log
rm --force $INACTIVITY_SCRIPT_LOG

# If this is run after inactivity_suspend_after_time, ensure the suspend script
# hasn't left files behind
systemctl disable --now "$(basename $GDM_SUSPEND_SERVICE)"
rm --force $GDM_SCRIPT $GDM_SUSPEND_SERVICE $LIGHTDM_SCRIPT

# Clean up after the previous version of this script
OLDCRON="/tmp/oldcron"
crontab -l > $OLDCRON
if [ -f "$OLDCRON" ]; then
  sed --in-place "\@$INACTIVITY_SCRIPT@d" $OLDCRON
  crontab $OLDCRON
  rm --force $OLDCRON
fi

# Handle deactivating inactivity logout
if [ "$ENABLE" = "False" ]; then
  rm --force $INACTIVITY_SCRIPT $CRON_D_FILE
  exit 0
fi

[ -z "$DIALOG_TIME_MINS" ] && error 'Please insert the time the user has to be inactive before dialog is shown.'
[ -z "$LOGOUT_TIME_MINS" ] && error 'Please insert the time the user has to be inactive before being logged out.'
[ "$DIALOG_TIME_MINS" -gt "$LOGOUT_TIME_MINS" ] && error 'Dialog time is greater than logout time and dialog will therefore not be shown. Edit dialog time!'

# org.gnome.Mutter.IdleMonitor.GetIdletime uses milliseconds, so convert the user inputted minutes to that
LOGOUT_TIME_MS=$(( LOGOUT_TIME_MINS * 60 * 1000 ))
DIALOG_TIME_MS=$(( DIALOG_TIME_MINS * 60 * 1000 ))

# Create the cron.d file
cat << EOF > $CRON_D_FILE
* * * * * root $INACTIVITY_SCRIPT
EOF

# New auto_logout file, running as root
cat <<- EOF > $INACTIVITY_SCRIPT
#!/usr/bin/env sh

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

if [ \$IDLE_TIME -ge $LOGOUT_TIME_MS ]; then
  pkill -KILL -u $OUR_USER
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

chmod 700 $INACTIVITY_SCRIPT
