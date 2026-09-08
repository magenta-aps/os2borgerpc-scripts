#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason

file=$1

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if dpkg -l "cisco-jvdi-client" > /dev/null; then
    echo "#############################################################"
    echo "# Removing already installed Cisco Jabber and configuration #"
    echo "#############################################################"
    apt-get -qq --assume-yes purge cisco-jvdi-client
fi

echo "############################"
echo "# Installing Cisco Jabber. #"
echo "############################"
apt-get -qq update
apt-get -qq --assume-yes install -f "$file"
rm "$file"
apt-get -qq --assume-yes autoremove
