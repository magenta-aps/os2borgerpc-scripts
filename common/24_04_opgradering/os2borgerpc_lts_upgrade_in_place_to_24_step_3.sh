#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    os2borgerpc_lts_upgrade_in_place_to_24_step_3.sh
#
# DESCRIPTION
#    Step three of the upgrade from 22.04 to 24.04.
#    Designed for regular OS2borgerPC machines

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a Kiosk device."
  exit 1
fi

PREVIOUS_STEP_DONE="/etc/os2borgerpc/second_24_upgrade_step_done"
if [ ! -f "$PREVIOUS_STEP_DONE" ]; then
  echo "24.04 opgradering - Opgradering til Ubuntu 24.04 trin 2 has not been run."
  exit 1
fi

REBOOT_REQUIRED_FILE="/var/run/reboot-required"
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
  echo "The computer must be rebooted before running this script. Reboot the computer and run this script again."
  exit 1
fi

# Ensure that user crontab is reset after logout
USERCRON=/etc/os2borgerpc/usercron
USER_CLEANUP="/usr/share/os2borgerpc/bin/user-cleanup.bash"

# Move the current user crontab to a file
if [ ! -f "$USERCRON" ]; then
  crontab -u user -l > $USERCRON || true
fi
chmod 700 $USERCRON

sed --in-place "/notify-send\|zenity/! d" $USERCRON

if ! grep --quiet "crontab" $USER_CLEANUP; then
  cat << EOF >> $USER_CLEANUP

# Restore user crontab
crontab -u user $USERCRON
EOF
fi

if ! grep --quiet "atq" $USER_CLEANUP; then
  cat << EOF >> $USER_CLEANUP

# Remove possible scheduled at commands
if [ -f /usr/bin/at ]; then
  atq | cut --fields 1 | xargs --no-run-if-empty atrm
fi
EOF
fi

if ! grep --quiet "pkill" $USER_CLEANUP; then
  cat << EOF >> $USER_CLEANUP

# Kill all processes started by user
pkill -KILL -u user
EOF
fi
# Only delete user-owned files under /tmp/
sed --in-place "s@/tmp/\* /tmp/\.??\* @@" $USER_CLEANUP
if ! grep --quiet "FILES_DIRS" $USER_CLEANUP; then
  cat << EOF >> $USER_CLEANUP

# Find all files/directories owned by user in the world-writable directories
FILES_DIRS=\$(find /tmp/ /var/tmp/ /var/crash/ /var/metrics/ /var/lock/ -user user)
rm --recursive --force /dev/shm/* /dev/shm/.??* \$FILES_DIRS
EOF
else
  sed --in-place "s@find /var@find /tmp/ /var@" $USER_CLEANUP
fi

# Make double sure that the crontab has been emptied
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
if [ -f "$TMP_ROOTCRON" ]; then
  crontab -r || true
  crontab -u user -r || true
fi

# Ensure correct permissions on user-cleanup.bash
chmod 700 "/usr/share/os2borgerpc/bin/user-cleanup.bash"

# Switch to new method for hiding terminal if they are hiding terminal
PROGRAM_PATH="/usr/bin/gnome-terminal"
SKEL=".skjult"
SHORTCUT_LOCAL_PATH="/home/$SKEL/.local/share/applications/org.gnome.Terminal.desktop"
if grep --quiet "zenity" "$PROGRAM_PATH"; then
  dpkg-statoverride --remove "$PROGRAM_PATH.real" || true
  # Remove the shell script that prints the error message
  rm "$PROGRAM_PATH"
  # Remove location override and restore gnome-terminal.real back to gnome-terminal
  dpkg-divert --remove --rename "$PROGRAM_PATH"
  # Cleanup after older script versions: Turns out this is unnecessary to hide the program from users program list
  rm --force $SHORTCUT_LOCAL_PATH
  # Deny access
  dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true
fi

# Switch to new method for hiding settings if they are hiding settings
PROGRAM_PATH="/usr/bin/gnome-control-center"
SHORTCUT_LOCAL_PATH="/home/$SKEL/.local/share/applications/gnome-control-center.desktop"
if grep --quiet "zenity" "$PROGRAM_PATH"; then
  PROGRAM_HISTORICAL_PATH="$PROGRAM_PATH.real"

  dpkg-statoverride --remove "$PROGRAM_HISTORICAL_PATH" || true
  # Remove the shell script that prints the error message
  rm "$PROGRAM_PATH"
  # Remove location override and restore gnome-settings.real back to gnome-settings
  dpkg-divert --remove --no-rename "$PROGRAM_PATH"
  # dpkg-divert can --rename it itself, but the problem with doing that is that in some images
  # dpkg-divert is not used, it was simply moved/copied, so that won't restore it, leaving you
  # with no gnome-control-center
  mv "$PROGRAM_HISTORICAL_PATH" "$PROGRAM_PATH"
  # Cleanup after older script versions: Turns out this is unnecessary to hide the program from users program list
  rm --force $SHORTCUT_LOCAL_PATH
  # Remove access
  dpkg-statoverride --update --add superuser root 770 "$PROGRAM_PATH" || true
fi


# Make sure release-upgrade prompt is not never so that the upgrade can run
# Also set the prompt to lts so that the upgrader will only look for lts releases
release_upgrades_file=/etc/update-manager/release-upgrades

sed -i "s/Prompt=.*/Prompt=lts/" $release_upgrades_file

# Temporarily stop usb-monitor if it exists
# as the upgrade seems to cause a usb-event for some reason
LOCKDOWN_USB_FILE=/usr/local/lib/os2borgerpc/usb-monitor
if [ -f "$LOCKDOWN_USB_FILE" ]; then
  systemctl disable --now os2borgerpc-usb-monitor.service
fi

# Make sure that we have a backup of jobmanager, just in case
if [ ! -f "/etc/os2borgerpc/jobmanager" ]; then
  cp "/usr/local/bin/jobmanager" "/etc/os2borgerpc/"
fi

# Perform the actual upgrade with some error handling
if lsb_release -d | grep --quiet 22; then
  do-release-upgrade -f DistUpgradeViewNonInteractive > /var/log/os2borgerpc_upgrade_2.log || true
fi

apt-get --assume-yes --fix-broken install || true
apt-get --assume-yes install --upgrade python3-pip || true

# Make sure that jobmanager can still find the client

# Install the client via pipx
apt-get --assume-yes install pipx || true
PIPX_ERRORS="False"
PIPX_BIN_DIR="/usr/local/bin" PIPX_HOME="/root/.local/share/pipx" pipx install --force os2borgerpc-client || PIPX_ERRORS="True"

if [ "$PIPX_ERRORS" = "True" ]; then
  mkdir --parents /usr/local/lib/python3.12
  cp --recursive /usr/local/lib/python3.10/dist-packages/ /usr/local/lib/python3.12/
  # Revert to the backup of jobmanager, which uses the client installed via pip
  cp "/etc/os2borgerpc/jobmanager" "/usr/local/bin/"
  echo "A problem occurred during the switch to pipx. Try rebooting and running this script again."
  echo "If the problem persists, contact support."
  exit 1
fi

# Modify update_client_and_register to use pipx
FILE="/usr/local/bin/update_client_and_register.sh"
if [ -f "$FILE" ]; then
  sed --in-place "s/pip install --upgrade/pipx upgrade/" "$FILE"
fi
# Also modify the reinstall-client superuser desktop shortcut to use pipx
DESKTOP=$(basename "$(runuser -u superuser xdg-user-dir DESKTOP)")
FILE="/home/superuser/$DESKTOP/os2borgerpc-reinstall-client.desktop"
if [ -f "$FILE" ]; then
  sed --in-place "s/pip install --force-reinstall/pipx reinstall/" "$FILE"
fi

# Some packages might not be upgraded during the release upgrade
# so we attempt to do so here
export DEBIAN_FRONTEND=noninteractive
apt-get --assume-yes update || true
apt-get --assume-yes upgrade || true
apt-get --assume-yes dist-upgrade || true
apt-get --assume-yes autoremove || true
apt-get --assume-yes clean || true

# Restart usb-monitor if it was stopped
if [ -f "$LOCKDOWN_USB_FILE" ]; then
  systemctl enable --now os2borgerpc-usb-monitor.service
fi

if ! lsb_release -d | grep --quiet 24; then
  echo "Opgraderingen er ikke blevet gennemført. Prøv at genstarte computeren og køre dette script igen."
  exit 1
fi

# Update the os_release config
RELEASE=$(lsb_release --release --short)
set_os2borgerpc_config _os_release "$RELEASE"
os2borgerpc_push_config_keys _os_release

# Delete the backup of jobmanager, which we no longer need
rm --force "/etc/os2borgerpc/jobmanager"

rm --force $PREVIOUS_STEP_DONE

touch /etc/os2borgerpc/third_24_upgrade_step_done
