#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# SYNOPSIS
#    dconf_disable_printer.sh [ENFORCE]
#
# DESCRIPTION
#    This script installs two policies that forces all printers to be
#    disabled at all times.
#
#    Use a boolean to decide whether to enforce or not. An unchecked box will
#    remove the policy and a checked one will enforce it.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Dconv prevent the user from printing and print setup changes
# Supported on Ubuntu 22.04 24.04 25.10
# schema org.gnome.desktop.lockdown
# key disable-print-setup Prevent the user from modifying print settings
# key disable-printing Prevent the user from printing

# gsettings list-recursively org.gnome.desktop.lockdown
# gsettings set org.gnome.desktop.lockdown disable-printing true
# gsettings set org.gnome.desktop.lockdown disable-print-setup true

POLICIES=("disable-print-setup" "disable-printing")
POLICY_PATH="org/gnome/desktop/lockdown"
POLICY_PREFIX="03-"
POLICY_VALUE="true"

ACTIVATE=$1

for POLICY in "${POLICIES[@]}"; do
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

        else
            rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"
    fi
done

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
