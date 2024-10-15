#!/usr/bin/env sh

# Logout the user from the graphical user interface after N minutes.

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ $# -ne 2 ]; then
    echo "This script takes exactly two parameters."
    exit 1
fi

ACTIVATE=$1
LOGIN_SESSION_LENGTH_IN_MINS=$2

AUTO_LOGOUT_DESKTOP_FILE="/home/.skjult/.config/autostart/auto_logout.sh.desktop"
AUTO_LOGOUT_SCHEDULE_SCRIPT="/usr/share/os2borgerpc/bin/auto_logout.sh"
export DEBIAN_FRONTEND=noninteractive

if grep "LANG=" /etc/default/locale | grep --quiet "da"; then
  MESSAGE="Du vil blive logget ud om fem minutter"
elif grep "LANG=" /etc/default/locale | grep --quiet "sv"; then
  MESSAGE="Du kommer att loggas ut om fem minuter"
else
  MESSAGE="You will be logged out in five minutes"
fi

if [ "$ACTIVATE" = "False" ]; then
    # Clean up
    rm --force $AUTO_LOGOUT_SCHEDULE_SCRIPT $AUTO_LOGOUT_DESKTOP_FILE
    atq | cut --fields 1 | xargs --no-run-if-empty atrm
    exit 0
fi

# Install "at" if it isn't already
if ! dpkg -l at > /dev/null 2>&1; then
    apt-get update
    apt-get install --assume-yes at
fi

cat <<- EOF > $AUTO_LOGOUT_SCHEDULE_SCRIPT
	#!/usr/bin/env bash

	atq | cut --fields 1 | xargs --no-run-if-empty atrm

	LOGIN_SESSION_LENGTH_IN_MINS=$LOGIN_SESSION_LENGTH_IN_MINS

	if [ \$LOGIN_SESSION_LENGTH_IN_MINS -ge 5 ]; then
	    TM5=\$(expr \$LOGIN_SESSION_LENGTH_IN_MINS - 5)
	    echo 'DISPLAY=:0.0 XAUTHORITY=/home/user/.Xauthority /usr/bin/zenity --warning --text="$MESSAGE"' | at now + \$TM5 min
	fi

	echo "kill -9 -1" | at now + \$LOGIN_SESSION_LENGTH_IN_MINS min
EOF

mkdir --parents /home/.skjult/.config/autostart

cat <<- EOF > $AUTO_LOGOUT_DESKTOP_FILE
	[Desktop Entry]
	Type=Application
	Exec=$AUTO_LOGOUT_SCHEDULE_SCRIPT
	Hidden=false
	NoDisplay=false
	X-GNOME-Autostart-enabled=true
	Name=Autologud
EOF

chmod +x $AUTO_LOGOUT_DESKTOP_FILE $AUTO_LOGOUT_SCHEDULE_SCRIPT
