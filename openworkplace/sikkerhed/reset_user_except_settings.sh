#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

ACTIVATE=$1

CLEANUP_D_FILE="/usr/share/os2borgerpc/bin/user-cleanup.d/601-reset-user-except-settings"

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ ! -d "$(dirname $CLEANUP_D_FILE)" ]; then
  echo "This computer does not support user-cleanup.d files. Exiting without doing anything."
  exit 0
fi

if [ "$ACTIVATE" != "True" ]; then
  rm --force $CLEANUP_D_FILE
  exit 0
fi

cat << EOF > $CLEANUP_D_FILE
#!/usr/bin/env sh

# Some settings are saved system-wide and will not be affected by deleting folders in /home/
# These include wifi and automatic time sync
# The following files should not be deleted in order to maintain
# system settings for the user $USERNAME
# /home/$USERNAME/.config/dconf/user - user-specific dconf settings
# /home/$USERNAME/.config/monitors.xml - screen settings
# /home/$USERNAME/.local/share/flatpak/db/notifications - some (but not all) permissions settings for programs
# /home/$USERNAME/.local/state/wireplumber/default-routes - sound settings including bluetooth headphones
# /home/$USERNAME/.config/mimeapps.list - default programs
# /home/$USERNAME/.pam_environment - user-specific language settings
FILES_TO_KEEP="/home/$USERNAME/.config/dconf/user /home/$USERNAME/.config/monitors.xml /home/$USERNAME/.local/share/flatpak/db/notifications /home/$USERNAME/.local/state/wireplumber/default-routes /home/$USERNAME/.config/mimeapps.list /home/$USERNAME/.pam_environment"

# Find all files/directories owned by $USERNAME in the world-writable directories
FILES_DIRS=\$(find /tmp/ /var/tmp/ /var/crash/ /var/metrics/ /var/lock/ -user $USERNAME)

chattr +i \$FILES_TO_KEEP
rm --force --recursive /dev/shm/* /dev/shm/.??* /home/$USERNAME/ \$FILES_DIRS
chattr -i \$FILES_TO_KEEP
EOF

chmod 700 $CLEANUP_D_FILE
