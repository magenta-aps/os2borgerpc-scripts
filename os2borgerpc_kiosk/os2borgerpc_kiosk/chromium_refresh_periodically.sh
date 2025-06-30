#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

CUSER="chrome"
XINITRC="/home/$CUSER/.xinitrc"
CHROMIUM_SCRIPT='/usr/share/os2borgerpc/bin/start_chromium.sh'
ROTATE_SCREEN_SCRIPT="/usr/share/os2borgerpc/bin/rotate_screen.sh"
PERIODIC_REFRESH_SCRIPT="/usr/share/os2borgerpc/bin/chromium_periodic_refresh.sh"

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

if [ ! -f $CHROMIUM_SCRIPT ]; then
  echo "Chromium Autostart must be run before this script. Exiting without doing anything."
  exit 1
fi

ACTIVATE=$1
REFRESH_PERIOD_IN_MINS=$2

# Idempotency
rm --force $PERIODIC_REFRESH_SCRIPT
sed --in-place "\@$PERIODIC_REFRESH_SCRIPT@d" $XINITRC

if [ "$ACTIVATE" = "True" ]; then

  apt-get --assume-yes update
  apt-get --assume-yes install xdotool

  REFRESH_PERIOD_IN_SECS=$((REFRESH_PERIOD_IN_MINS * 60))

  cat << EOF > $PERIODIC_REFRESH_SCRIPT
#!/usr/bin/env sh

while true; do
  sleep $REFRESH_PERIOD_IN_SECS
  xdotool key F5
done
EOF

  chmod +x $PERIODIC_REFRESH_SCRIPT

  sed --in-place "\@$ROTATE_SCREEN_SCRIPT@a $PERIODIC_REFRESH_SCRIPT \&" $XINITRC
fi
