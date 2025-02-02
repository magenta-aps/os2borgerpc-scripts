#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
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
    apt-get purge cisco-jvdi-client -y
fi

echo "############################"
echo "# Installing Cisco Jabber. #"
echo "############################"
apt-get update -y
apt-get install -f "$file" -y
rm "$file"
sudo apt autoremove -y
