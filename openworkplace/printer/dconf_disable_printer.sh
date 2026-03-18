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

# Dconf prevent the user from printing and print setup changes
# Supported on Ubuntu 22.04 24.04 25.10
# schema org.gnome.desktop.lockdown
# key disable-print-setup Prevent the user from modifying print settings
# key disable-printing Prevent the user from printing

# gsettings list-recursively org.gnome.desktop.lockdown
# gsettings set org.gnome.desktop.lockdown disable-printing true
# gsettings set org.gnome.desktop.lockdown disable-print-setup true

POLICY_PATH="org/gnome/desktop/lockdown"
POLICY_KEY_1="disable-print-setup"
POLICY_KEY_2="disable-printing"
POLICY_VALUE="true"

POLICY_PREFIX="50-"
POLICY_FILE_NAME="disable-printing-all"
POLICY_FILE="/etc/dconf/db/os2borgerpc.d/$POLICY_PREFIX$POLICY_FILE_NAME"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/$POLICY_PREFIX$POLICY_FILE_NAME"

ACTIVATE=$1

if [ "$ACTIVATE" = "True" ]; then

    cat > "$POLICY_FILE" <<-END
[$POLICY_PATH]
$POLICY_KEY_1=$POLICY_VALUE
$POLICY_KEY_2=$POLICY_VALUE
END

    # Tell the system that the values of the dconf keys we've just set can no
    # longer be overridden by the user
    cat > "$POLICY_LOCK_FILE" <<-END
/$POLICY_PATH/$POLICY_KEY_1
/$POLICY_PATH/$POLICY_KEY_2
END

    # sync system's dconf databases
    dconf update

    # stop and disable local cups print daimon and network printing

    # Notice Debian and Ubuntu reverse dependency chain
    # cups.service
    # ● ├─cups-browsed.service
    # ● └─multi-user.target
    # ●   └─graphical.target

    # Notice order disable --now -> mask needed to succeed
    systemctl disable --now cups.service cups-browsed.service
    systemctl mask cups.service cups-browsed.service

elif [ "$ACTIVATE" = "False" ]; then

    rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"

    # sync system's dconf databases
    dconf update

    # start and enable local cups print daimon and network printing
    # Notice order unmask -> enable --now needed to succeed
    systemctl unmask cups.service cups-browsed.service
    systemctl enable --now cups.service cups-browsed.service

else

    echo "Error: expected True|False as first argument, but got argument '$ACTIVATE'"
    exit 1

fi
