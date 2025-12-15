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
POPUP_TIMER=${8:-0}

POPUP_AUTOSTART="/home/.skjult/.config/autostart/user_info.desktop"
POPUP_SCRIPT="/home/.skjult/user_info.sh"
USER_POPUP_SCRIPT="/home/user/user_info.sh"

if [ "$ACTIVATE" = "False" ]; then
  rm --force $POPUP_AUTOSTART $POPUP_SCRIPT
  exit 0
fi

if [ "$(lsb_release --release --short | cut --delimiter '.' --fields 1)" -ge 24 ]; then
  LOGOUT_TIMER_FILE="/usr/share/gnome-shell/extensions/logout-timer-24-04@os2borgerpc.magenta.dk/config.json"
else
  LOGOUT_TIMER_FILE="/usr/share/gnome-shell/extensions/logout-timer@os2borgerpc.magenta.dk/config.json"
fi

if [ "$POPUP_TIMER" -gt 0 ]; then
  TIMER_ACTIVE="--timeout=$POPUP_TIMER"
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

if [ -n "$FULL_LOGIN_TIME" ] && [ -f "$LOGOUT_TIMER_FILE" ]; then
  CURRENT_TIME=\$(jq '.timeMinutes' "$LOGOUT_TIMER_FILE")
  if [ \$CURRENT_TIME = $FULL_LOGIN_TIME ]; then
    if ! zenity --info $DIMENSIONS $TIMER_ACTIVE --title="$TITLE" --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT"; then
      if [ "$POPUP_TIMER" -gt 0 ]; then
        gnome-session-quit --logout --no-prompt
      fi
    fi
  fi
else
  if ! zenity --info $DIMENSIONS $TIMER_ACTIVE --title="$TITLE" --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT"; then
    if [ "$POPUP_TIMER" -gt 0 ]; then
      gnome-session-quit --logout --no-prompt
    fi
  fi
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
