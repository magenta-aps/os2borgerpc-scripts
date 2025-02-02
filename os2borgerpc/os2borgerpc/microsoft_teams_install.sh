#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Heini Leander Ovason

ACTIVATE=$1
FILE=$2

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ "$ACTIVATE" = "True" ]; then
  echo "##### Attempting to install Microsoft Teams #####"
  apt-get update --assume-yes
  apt-get install --fix-broken "$FILE" --assume-yes
else
  echo "##### Removing Microsoft Teams #####"
  apt-get purge teams --assume-yes
fi

rm "$FILE"
apt autoremove --assume-yes
