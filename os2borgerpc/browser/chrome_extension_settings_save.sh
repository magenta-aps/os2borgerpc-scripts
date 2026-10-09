#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to be run on a Kiosk-machine. Exiting."
  exit 1
fi

POLICY="/etc/opt/chrome/policies/managed/os2borgerpc-defaults.json"
SKELETON=".skjult"
CHROME_PROFILE_PATH="/home/$SKELETON/.config/google-chrome/Default"
EXTENSION_SETTINGS_PATH="/home/user/.config/google-chrome/Default/Local Extension Settings"
COOKIES_PATH="/home/user/.config/google-chrome/Default/Cookies"

set -x

ACTIVATE=$1

if [ ! -f "$POLICY" ]; then
  echo "This script should be run after Chrome has been installed! Exiting."
  exit 1
fi

if [ "$ACTIVATE" = "False" ]; then
  rm --recursive --force "$CHROME_PROFILE_PATH/Local Extension Settings" "$CHROME_PROFILE_PATH/Cookies" \
  "$EXTENSION_SETTINGS_PATH" "$COOKIES_PATH"
  echo "Deleted the saved extension settings."
  exit 0
fi

# Install sqlite3 needed to modify the copied cookies database
apt-get -qq update
apt-get -qq --yes install --fix-broken  # Attempt to fix possible apt errors
apt-get -qq --yes install sqlite3

if grep --quiet "ForceEphemeral" "$POLICY"; then
  sed --in-place "/ForceEphemeral/d" $POLICY
  echo "First run complete. Next, please log out on the target computer and log in as citizen."
  echo "Then, open Chrome, choose the desired extension settings and rerun this script without logging out."
elif [ ! -d "$EXTENSION_SETTINGS_PATH" ]; then
  echo "No extension settings found."
  echo "Please log out and log in as citizen, choose the desired extension settings then rerun this script without logging out."
  exit 1
else
  mkdir --parents "$CHROME_PROFILE_PATH"
  cp --recursive "$EXTENSION_SETTINGS_PATH" "$CHROME_PROFILE_PATH/"
  # Delete all cookies not related to Appwriter Cloud before copying cookies file
  # Copy the file if the delete succeeds
  if sqlite3 "$COOKIES_PATH" 'delete from cookies where host_key != ".lingapps.dk"'; then
    cp "$COOKIES_PATH" "$CHROME_PROFILE_PATH/"
  fi
  chown --recursive root:root "$CHROME_PROFILE_PATH/"
  echo "The extension settings have been saved. It is now fine to log out."
fi
