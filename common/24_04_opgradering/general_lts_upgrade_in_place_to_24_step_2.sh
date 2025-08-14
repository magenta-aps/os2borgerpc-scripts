#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    general_lts_upgrade_in_place_to_24_step_2.sh
#
# DESCRIPTION
#    Step two of the upgrade from 22.04 to 24.04.

set -ex

PREVIOUS_STEP_DONE="/etc/os2borgerpc/first_24_upgrade_step_done"
if [ ! -f "$PREVIOUS_STEP_DONE" ]; then
  echo "24.04 opgradering - Opgradering til Ubuntu 24.04 trin 1 has not been run."
  exit 1
fi

# Make double sure that the crontab has been emptied
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
USERCRON=/etc/os2borgerpc/usercron
if [ -f "$TMP_ROOTCRON" ]; then
  crontab -r || true
  if [ -f "$USERCRON" ]; then
    crontab -u user -r || true
  fi
fi

# Fix dpkg settings to avoid interactivity.
cat << EOF > /etc/apt/apt.conf.d/local
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};
Dpkg::Lock {Timeout "3600";};
Dpkg {ConfigurePending "true";};
Apt:Get {Fix-Broken "true";};
EOF

# Prevent timezone issues
hwclock --hctosys

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

# Resync the local package index from its remote counterpart
apt-get --assume-yes update

# Attempt to fix errors in the package management system
# shellcheck disable=SC2034
for i in 1 2 3 4; do
  dpkg --configure -a || true
  apt-get --assume-yes --fix-broken install || true
done
dpkg --configure -a || apt-get --assume-yes --fix-broken install
apt-get --assume-yes --fix-broken install || dpkg --configure -a

# Remove unnecessary packages
apt-get remove --assume-yes python3-dev 

# Run available updates in preparation for the release-upgrade
apt-get --assume-yes upgrade

apt-get --assume-yes dist-upgrade

# Prepare to use pipx
echo 'PIPX_BIN_DIR="/usr/local/bin"' >> /etc/environment
echo 'PIPX_HOME="/root/.local/share/pipx"' >> /etc/environment

# Remove packages only installed as dependencies, which are no longer dependencies
apt-get --assume-yes autoremove

# Remove local repository of retrieved package files
apt-get --assume-yes clean

# Update config for last full update
# The output from "date --iso-8601='minutes'" has the format 2024-12-03T15:45+01:00
UPDATE_TIME="$(date --iso-8601='minutes' | tr 'T' ' ' | cut --delimiter '+' --fields 1)"
set_os2borgerpc_config _last_full_update_time "$UPDATE_TIME"
os2borgerpc_push_config_keys _last_full_update_time

# Take a backup of jobmanager, just in case
cp "/usr/local/bin/jobmanager" "/etc/os2borgerpc/"

rm --force $PREVIOUS_STEP_DONE

touch /etc/os2borgerpc/second_24_upgrade_step_done
