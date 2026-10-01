#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

set -x

INSTALL=$1

DEB_DOWNLOAD_URL="https://fsn1.your-objectstorage.com/openworkplace-prod/assorted/cisco-secure-client-vpn_5.1.17.3394_amd64.deb"
DEB_FILE="/tmp/cisco-secure-client-vpn.deb"

if [ "$INSTALL" = "True" ]; then
  # Get the .deb file from our bucket
  wget --output-document=$DEB_FILE --quiet $DEB_DOWNLOAD_URL

  # Install the program from the .deb file
  apt-get -qq update
  apt-get -qq --yes install $DEB_FILE
  # Cleanup
  rm --force $DEB_FILE
else
  apt-get -qq --yes remove "cisco-secure-client-vpn"
fi
