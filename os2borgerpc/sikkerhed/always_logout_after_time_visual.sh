#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Heini Leander Ovason, Andreas Poulsen
#
# We need to run this program only AFTER login, so not graphical.target or whatever, if that
# includes the login manager which also runs in X.
#
# This program needs to run as root or superuser so a user can't kill it,
# but at the same time the timer program must run as the regular user to be able to write things to
# screen.
# It's fine if they kill the visual timer as long as they're then logged out automatically or the timer
# continues in the background.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Argument handling
ACTIVATE=$1
MINUTES_TO_LOGOUT=$2 # This sets the default timeout time, which the Cicero script then overwrites
PRE_TIMER_TEXT="${3:-Tid tilbage: }"
HEADS_UP_SECONDS_LEFT=${4:-60}
HEADS_UP_MESSAGE="${5:-Tiden er udløbet om et minut. Husk at gemme dine ting}"


# Settings

# COMMON
export DEBIAN_FRONTEND=noninteractive
SHADOW=".skjult"
EXTENSION_NAME_OLD='logout-timer@os2borgerpc.magenta.dk'
EXTENSION_NAME_NEW='logout-timer-24-04@os2borgerpc.magenta.dk'
SESSION_CLEANUP_FILE="/usr/share/os2borgerpc/bin/user-cleanup.bash"
LOGOUT_TIMER_SESSION_CLEANUP_FILE="/usr/share/os2borgerpc/bin/user-cleanup-logout-timer.bash"
OUR_USER="user"

# LOGOUT_TIMER_ACTUAL:
LOGOUT_TIMER_ACTUAL="/usr/share/os2borgerpc/bin/logout_timer_actual.sh"
LOGOUT_TIMER_ACTUAL_LAUNCHER="/usr/share/os2borgerpc/bin/logout_timer_actual_launcher.sh"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"
# They might have automatic login enabled or not. We add it to all lightdm or gdm programs just in case.
LIGHTDM_PAM="/etc/pam.d/lightdm"
LIGHTDM_GREETER_PAM="/etc/pam.d/lightdm-greeter"
LIGHTDM_AUTOLOGIN_PAM="/etc/pam.d/lightdm-autologin"
LIGHTDM_FILES="$LIGHTDM_PAM $LIGHTDM_GREETER_PAM $LIGHTDM_AUTOLOGIN_PAM"
GDM_PASSWORD_PAM="/etc/pam.d/gdm-password"
GDM_AUTOLOGIN_PAM="/etc/pam.d/gdm-autologin"
GDM_FILES="$GDM_AUTOLOGIN_PAM $GDM_PASSWORD_PAM"
GRACE_PERIOD="30" # The root timer has this added to it, to be more certain that it doesn't run out before the gnome extension.

# EXTENSION ADDITIONAL SETTINGS:
REPO_NAME="os2borgerpc-gnome-extensions"
BRANCH=main
EXTENSION_GIT_URL=https://github.com/magenta-aps/$REPO_NAME/archive/refs/heads/${BRANCH}.zip

# TODO: Consider not handling this here, and instead running install.sh with False to remove an extension. But then the repo
# either needs to remain on disk or be downloaded anew just to delete an extension...?
# It seems better to handle it there once for all extensions, instead of re-implementing installation/removal in every
# single extensi1n script
EXTENSION_ACTIVATION_DESKTOP_FILE="/home/$SHADOW/.config/autostart/logout-timer-user.desktop"

# CLEANUP AFTER PREVIOUS RUNS OF THIS SCRIPT
rm --force /usr/share/os2borgerpc/logout_timer.conf /usr/share/os2borgerpc/bin/logout_timer_visual.sh /home/$SHADOW/.config/autostart/logout-timer_user.desktop
# - This next line is handled in LOGOUT_TIMER_SESSION_CLEANUP_FILE instead
sed --in-place "/pkill -f $(basename $LOGOUT_TIMER_ACTUAL)/d" $SESSION_CLEANUP_FILE
sed --in-place "/pkill -f logout_timer_visual.sh/d" $SESSION_CLEANUP_FILE

[ $# -lt 2 ] && printf "%s\n" "This script takes at least 2 arguments. Exiting." && exit 1

if cat $DEFAULT_DM_FILE | grep --quiet gdm3; then
  PAM_FILES=$GDM_FILES
  CHECK_FILE=$GDM_PASSWORD_PAM
else
  PAM_FILES=$LIGHTDM_FILES
  CHECK_FILE=$LIGHTDM_GREETER_PAM
fi

if [ "$(lsb_release --release --short | cut --delimiter '.' --fields 1)" -lt 24 ]; then
  EXTENSION_NAME=$EXTENSION_NAME_OLD
else
  EXTENSION_NAME=$EXTENSION_NAME_NEW
fi
LOGOUT_TIMER_CONF="/usr/share/gnome-shell/extensions/$EXTENSION_NAME/config.json"

if [ "$ACTIVATE" = "True" ]; then
	apt-get install --assume-yes jq

	# Fetch and install gnome extension
	wget $EXTENSION_GIT_URL
	unzip $BRANCH.zip
	$REPO_NAME-$BRANCH/install.sh whatever $EXTENSION_NAME true true true
	rm --recursive $BRANCH.zip $REPO_NAME-$BRANCH

	# Now overwrite the testing config with what the user inputted/defaults in this script
	cat <<- EOF > "$LOGOUT_TIMER_CONF"
	{
	  "timeMinutes": $MINUTES_TO_LOGOUT,
	  "preTimerText": "$PRE_TIMER_TEXT",
	  "headsUpSecondsLeft": $HEADS_UP_SECONDS_LEFT,
	  "headsUpMessage": "$HEADS_UP_MESSAGE"
	}
	EOF

	# A backup timer used to logout if the user-run gnome extension is disabled/killed, running as root
	cat <<- EOF > $LOGOUT_TIMER_ACTUAL
		#!/usr/bin/env bash

		TIME_MINUTES=\$(jq < $LOGOUT_TIMER_CONF '.timeMinutes')

		# Adding a little to this so they're warned a bit before they're actually logged out
		# This is even more important since currently the timers might get out of sync
		COUNT=\$(bc <<< "\$TIME_MINUTES * 60 + $GRACE_PERIOD")
		# Ensure that COUNT is an integer
		COUNT=\$(echo \$COUNT | cut --delimiter '.' --fields 1)

		until [ "\$COUNT" -eq "0" ]; do                                # Countdown loop.
		    COUNT=\$((COUNT-1))                                        # Decrement seconds.
		    sleep 1
		done

		pkill -KILL -u user
	EOF

	# Simply a small script that launches the timer in the background and immediately exits
	# so the PAM stack continues instead of it waiting for the timer to run out
	# Using bash as disown is undefined in sh
	cat <<- EOF > $LOGOUT_TIMER_ACTUAL_LAUNCHER
		#!/usr/bin/env bash

		$LOGOUT_TIMER_ACTUAL &
		disown
	EOF

	# Make PAM run LOGOUT_TIMER_ACTUAL_LAUNCHER for user, so it's run as root
	# Idempotency: Don't add it multiple times if this script is run more than once
  if ! grep -q "# OS2borgerPC Timer" $CHECK_FILE; then
  	for f in $PAM_FILES; do
  		sed --in-place "/@include common-session/i# OS2borgerPC Timer\nsession [success=1 default=ignore] pam_succeed_if.so user != user\nsession optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER" "$f"
  	done
  fi

	# Modify the cleanup run at logout to also kill remaining timers so they don't persist, affecting
	# the next login
		# Create a new script to handle cleanup after the logout timer
	cat <<- EOF > $LOGOUT_TIMER_SESSION_CLEANUP_FILE
		#!/usr/bin/env sh

		pkill -f "$(basename $LOGOUT_TIMER_ACTUAL)"
		runuser --login $OUR_USER --command "XDG_RUNTIME_DIR=/run/user/$(id -u $OUR_USER) gnome-extensions disable $EXTENSION_NAME"
	EOF

	# Finally append this new cleaner script to the end of user-cleanup
	if ! grep -q "$LOGOUT_TIMER_SESSION_CLEANUP_FILE" $SESSION_CLEANUP_FILE; then
		echo "$LOGOUT_TIMER_SESSION_CLEANUP_FILE" >> $SESSION_CLEANUP_FILE
	fi

	chmod u+x $LOGOUT_TIMER_ACTUAL $LOGOUT_TIMER_ACTUAL_LAUNCHER $LOGOUT_TIMER_SESSION_CLEANUP_FILE

else # Stop the timers and delete everything related to them
	pkill -f "$(basename $LOGOUT_TIMER_ACTUAL)"
	gnome-extensions disable $EXTENSION_NAME  # Note: Don't do this if we make "disable" run "gnome-session-quit --logout" as well!

	sed --in-place "\@$LOGOUT_TIMER_SESSION_CLEANUP_FILE@d" $SESSION_CLEANUP_FILE
	rm --recursive $LOGOUT_TIMER_ACTUAL $LOGOUT_TIMER_ACTUAL_LAUNCHER $EXTENSION_ACTIVATION_DESKTOP_FILE "$(dirname "$LOGOUT_TIMER_CONF")" $LOGOUT_TIMER_SESSION_CLEANUP_FILE

	#	Alternate solution: Kill all processes started by user in user-cleanup.sh? Maybe that's a better idea anyway,
	#	which we should do for everyone in the future?

	for f in $PAM_FILES; do
		sed --in-place "/# OS2borgerPC Timer/d" "$f"
		sed --in-place "/session \[success=1 default=ignore\] pam_succeed_if.so user != user/d" "$f"
		sed --in-place "\@session optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER@d" "$f"
	done
fi
