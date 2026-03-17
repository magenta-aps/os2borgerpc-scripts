#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# SYNOPSIS
#    dconf_mount_removable_storage_devices_as_read_only.sh [True|False]
#
# DESCRIPTION
#    This script installs a policy that prevents users from
#    writing data to removable block storage devices such as USB flash drives, cameras and phones
#
#    Use a boolean to decide whether to enforce or not. An unchecked box will
#    remove the policy and a checked one will enforce it.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Dconf prevent the user from writing to removable meadia
# Supported on Ubuntu 22.04 24.04 25.10
# schema org.gnome.desktop.lockdown
# key mount-removable-storage-devices-as-read-only

# gsettings list-recursively org.gnome.desktop.lockdown
# gsettings set org.gnome.desktop.lockdown mount-removable-storage-devices-as-read-only true

POLICY="mount-removable-storage-devices-as-read-only"
POLICY_PATH="org/gnome/desktop/lockdown"
POLICY_PREFIX="50-"
POLICY_VALUE="true"

ACTIVATE=$1

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/$POLICY_PREFIX$POLICY"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/$POLICY_PREFIX$POLICY"

if [ "$ACTIVATE" = "True" ]; then

    cat > "$POLICY_FILE" <<-END
[$POLICY_PATH]
$POLICY=$POLICY_VALUE
END

    # Tell the system that the values of the dconf keys we've just set can no
    # longer be overridden by the user
    cat > "$POLICY_LOCK_FILE" <<-END
/$POLICY_PATH/$POLICY
END

    # sync system's dconf databases
    dconf update

elif [ "$ACTIVATE" = "False" ]; then

    rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"

    # sync system's dconf databases
    dconf update

else

    echo "Error: expected True|False as first argument, but got argument '$ACTIVATE'"
    exit 1

fi
