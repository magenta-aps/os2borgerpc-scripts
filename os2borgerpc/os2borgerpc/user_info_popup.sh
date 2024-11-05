#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be used on a Kiosk device."
  exit 1
fi

# We escape possible double quotes in the string parameters as the
# double quotes will otherwise be ignored by zenity
ACTIVATE="$1"
TITLE="${2//\"/\\\"}"
DIALOG_TEXT="${3//\"/\\\"}"
BUTTON_TEXT="${4//\"/\\\"}"
WIDTH="$5"
HEIGHT="$6"
FULL_LOGIN_TIME="$7"

POPUP_AUTOSTART=/home/.skjult/.config/autostart/user_info.desktop
POPUP_SCRIPT=/home/.skjult/user_info.sh
USER_POPUP_SCRIPT=/home/user/user_info.sh

if [ "$ACTIVATE" = "False" ]; then
  rm --force $POPUP_AUTOSTART $POPUP_SCRIPT
  exit 0
fi

if [ -n "$WIDTH" ] && [ -n "$HEIGHT" ]; then
  DIMENSIONS="--width=$WIDTH --height=$HEIGHT"
elif [ -n "$WIDTH" ] && [ -z "$HEIGHT" ]; then
  DIMENSIONS="--width=$WIDTH"
elif [ -z "$WIDTH" ] && [ -n "$HEIGHT" ]; then
  DIMENSIONS="--height=$HEIGHT"
fi

# Ensure that the autostart folder exists
mkdir --parents "$(dirname "$POPUP_AUTOSTART")"

cat << EOF > $POPUP_SCRIPT
#!/usr/bin/env bash

LOGOUT_TIMER_FILE="/usr/share/gnome-shell/extensions/logout-timer@os2borgerpc.magenta.dk/config.json"

if [ -n "$FULL_LOGIN_TIME" ] && [ -f \$LOGOUT_TIMER_FILE ]; then
  CURRENT_TIME=\$(jq '.timeMinutes' \$LOGOUT_TIMER_FILE)
  if [ \$CURRENT_TIME = $FULL_LOGIN_TIME ]; then
    zenity --info $DIMENSIONS --title="$TITLE" --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT"
  fi
else
  zenity --info $DIMENSIONS --title="$TITLE" --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT"
fi

rm --force $USER_POPUP_SCRIPT
EOF

chmod u+x $POPUP_SCRIPT

cat << EOF > $POPUP_AUTOSTART
[Desktop Entry]
Type=Application
Name=OS2borgerPC info popup
Exec=$USER_POPUP_SCRIPT
EOF

chmod u+x $POPUP_AUTOSTART
