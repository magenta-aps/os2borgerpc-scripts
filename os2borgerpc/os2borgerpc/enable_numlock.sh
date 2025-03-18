#!/bin/sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Emil Nordahn Andersen, Marcus Funch, Andreas Poulsen
#
# DESCRIPTION
# Requires "lightdm_greeter_setup_scripts" to be run and enabled to take effect
# if the computer is using lightdm.
#
# If the computer is using gdm, numlock is controlled via a dconf policy
#
# This script will install numlockx and enable it when the pc reaches the login screen
# if the computer is using lightdm.
#
# PARAMETERS
# 1. Checkbox. Enables or disables numlock

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

NUMLOCK_ON=$1

LIGHTDM_SCRIPT="/etc/lightdm/greeter-setup-scripts/enable_numlock.sh"
POLICY="/etc/dconf/db/os2borgerpc.d/00-numlock"
POLICY_LOCK="/etc/dconf/db/os2borgerpc.d/locks/00-numlock"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"
GDM_DCONF_FILE="/etc/dconf/db/gdm.d/00-numlock"
GDM_DCONF_LOCK_FILE="/etc/dconf/db/gdm.d/locks/00-numlock"
# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

# Cleanup after old versions of the script
rm --force /etc/xdg/autostart/os2borgerpc-numlock.desktop

if [ "$NUMLOCK_ON" = "True" ]; then

  # gdm is used as the display manager
  if grep --quiet gdm3 $DEFAULT_DM_FILE; then

    cat << EOF > $GDM_DCONF_FILE
[org/gnome/desktop/peripherals/keyboard]
numlock-state=true
EOF

    # Tell the system that the value of the dconf key we've just set
    # can no longer be overridden by the user. This is necessary
    # to ensure that numlock is reenabled on the login screen after
    # logout if a user previously disabled it via the button
    cat << EOF > $GDM_DCONF_LOCK_FILE
/org/gnome/desktop/peripherals/keyboard/numlock-state
EOF

  else # lightdm is used as the display manager

    if [ ! -f "/usr/bin/numlockx" ]; then
      apt-get update -qq > /dev/null
      apt-get -yqq install numlockx
    fi

    mkdir --parents "$(dirname $LIGHTDM_SCRIPT)"

    cat << EOF > "$LIGHTDM_SCRIPT"
#!/bin/sh

numlockx on
EOF
    # Set the correct permissions on the file, so it can be executed by lightdm
    chmod 700 "$LIGHTDM_SCRIPT"
  fi

  cat << EOF > $POLICY
[org/gnome/desktop/peripherals/keyboard]
numlock-state=true
EOF

  cat << EOF > $POLICY_LOCK
/org/gnome/desktop/peripherals/keyboard/numlock-state
EOF
  echo "Added the numlock policy as: $POLICY"
else
  if [ -f "/usr/bin/numlockx" ]; then
    apt-get remove -yqq numlockx
  fi
  rm --force "$POLICY" "$POLICY_LOCK" "$LIGHTDM_SCRIPT" "$GDM_DCONF_FILE" "$GDM_DCONF_LOCK_FILE"
fi

dconf update
