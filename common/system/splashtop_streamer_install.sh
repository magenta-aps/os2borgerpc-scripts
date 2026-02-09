#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Install Splashtop Streamer

set -x

DEB_FILE=$1
GATEWAY=$2
DEPLOY_CODE=$3

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

apt-get update > /dev/null
# Remove possible old versions of splashtop-streamer
apt-get remove --assume-yes splashtop-streamer || true
# On Kiosk, install cups and restart all the related services
# to prevent a weird cups-related error where cups asks for
# the root password
# Splashtop Streamer will install cups anyway
if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  apt-get install --assume-yes cups
  # Restart all cups-related services
  systemctl list-units | grep cups | sed --expression "s/^[ ]\+//g" | cut --delimiter " " --fields 1 | xargs -L 1 systemctl restart
fi
# Install Splashtop Streamer via apt-get
apt-get install --assume-yes "$DEB_FILE"

# Configure Splashtop Streamer
splashtop-streamer config -sec_opt=0

# Deploy with the supplied gateway and code
splashtop-streamer deploy "$GATEWAY" "$DEPLOY_CODE"
