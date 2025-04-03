#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2013 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch
#
# Logout the user from the graphical user interface after N minutes.
# Takes exactly one parameter.

if [ $# -ne 1 ]; then
    echo "This job takes exactly one parameter."
    exit 1
fi

TIME=$1

OUR_USER="user"

dpkg -l at > /dev/null 2>&1
HAS_AT=$?

if [[ $HAS_AT == 1 ]]; then
    apt-get update
    apt-get install --assume-yes at
fi


if [ "$TIME" -ge 5 ]; then
  TM5=$(( TIME - 5))
  cat << EOF > /tmp/notify
export DISPLAY=\$(who | grep -w '$OUR_USER' | sed -rn 's/.*\((:[0-9]*)\).*/\1/p')

/usr/sbin/runuser -u $OUR_USER -- /usr/bin/zenity --warning --text="Computeren lukkes ned om fem minutter"
EOF
  at -f /tmp/notify now + $TM5 min
fi

echo '/sbin/reboot' > /tmp/quit

at -f /tmp/quit now + "$TIME" min

exit 0
