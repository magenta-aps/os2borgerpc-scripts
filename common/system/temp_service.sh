#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

# Update the client
if [ -d "/root/.local/share/pipx/venvs/os2borgerpc-client" ]; then
  pipx upgrade os2borgerpc-client
else
  pip3 install --upgrade os2borgerpc-client
fi

# The remaining operations are not relevant on kiosk
if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  exit 0
fi

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

# Update apt packages
apt-get update > /dev/null # Resync the local package index from its remote counterpart
# Configure any packages which have been unpacked but not configured, as otherwise --fix-broken might fail
# However, package configuration can also fail due to dependency issues that would be fixed by --fix-broken
# so if the command fails, try to run --fix-broken
dpkg --configure -a || apt-get --assume-yes --fix-broken install
# Attempt to fix broken or interrupted installations
# If this fails, try to configure any packages which have been unpacked but not configured
apt-get --assume-yes --fix-broken install || dpkg --configure -a

# Get locale
LOCALE=$(grep LANG= /etc/default/locale | cut --delimiter '=' --fields 2 | tr --delete '"' | cut --delimiter '_' --fields 1)

# Ensure that language-support is correctly installed
# shellcheck disable=SC2046 # We want word-splitting here
apt-get install --assume-yes $(check-language-support -l "$LOCALE")

# Set Firefox language correctly
FIREFOX_POLICY_FILE="/etc/firefox/policies/policies.json"
if ! grep --quiet "RequestedLocales" $FIREFOX_POLICY_FILE; then
  sed --in-place "/SanitizeOnShutdown/i \ \ \ \ \"RequestedLocales\": \"$LOCALE\"," $FIREFOX_POLICY_FILE
fi

# Ensure that default pdf reader is set correctly
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"
if [ -f "$GLOBAL_MIME_FILE" ]; then
  sed --in-place "s@/usr/share/applications/@@" $GLOBAL_MIME_FILE
fi

# Correctly block terminal
PROGRAM_PATH="/usr/bin/gnome-terminal"
# Making sure we're not removing the actual program
if grep --quiet "zenity" "$PROGRAM_PATH"; then
  dpkg-statoverride --remove "$PROGRAM_PATH.real" || true
  # Remove the shell script that prints the error message
  rm "$PROGRAM_PATH"
  # Remove location override and restore gnome-terminal.real back to gnome-terminal
  dpkg-divert --remove --rename "$PROGRAM_PATH"
fi
# Make sure the terminal is correctly installed
if [ ! -f "$PROGRAM_PATH" ] || [ ! -f "$PROGRAM_PATH.real" ]; then
  apt-get install --reinstall --assume-yes gnome-terminal
fi
# Remove possible old statoverride with different permissions
dpkg-statoverride --remove "$PROGRAM_PATH" || true
# Deny access
dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH.real" || true
dpkg-statoverride --update --add root superuser 750 "$PROGRAM_PATH" || true
