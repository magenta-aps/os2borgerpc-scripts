#!/usr/bin/env bash

# Logout the user from the graphical user interface after N minutes.
# Takes exactly one parameter.

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ $# -ne 1 ]; then
    echo "This job takes exactly one parameter."
    exit 1
fi

AUTO_LOGOUT_DESKTOP_FILE="/home/.skjult/.config/autostart/auto_logout.sh.desktop"
AUTO_LOGOUT_SCHEDULE_SCRIPT="/usr/share/os2borgerpc/bin/auto_logout.sh"

if grep "LANG=" /etc/default/locale | grep "da"; then
  MESSAGE="Du vil blive logget ud om fem minutter"
elif grep "LANG=" /etc/default/locale | grep "sv"; then
  MESSAGE="Du kommer att loggas ut om fem minuter"
else
  MESSAGE="You will be logged out in five minutes"
fi

# Install at
dpkg -l at > /dev/null 2>&1
HAS_AT=$?

if [[ $HAS_AT == 1 ]]; then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install --assume-yes at
fi

if [[ ($1 == "--disable") || ($1 == "0") ]]; then
    # Clean up
    rm --force $AUTO_LOGOUT_SCHEDULE_SCRIPT $AUTO_LOGOUT_DESKTOP_FILE
    atq | cut --fields 1 | xargs --no-run-if-empty atrm
    exit 0
fi

cat <<- EOF > $AUTO_LOGOUT_SCHEDULE_SCRIPT
	#!/usr/bin/env bash

  atq | cut --fields 1 | xargs --no-run-if-empty atrm

	TIME=$1

	if [ \$TIME -ge 5 ]; then
	    TM5=\$(expr \$TIME - 5)
	    echo 'DISPLAY=:0.0 XAUTHORITY=/home/user/.Xauthority /usr/bin/zenity --warning --text="$MESSAGE"' | at now + \$TM5 min
	fi

	echo "kill -9 -1" | at now + \$TIME min
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

exit 0
