#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1
ICON_SIZE="$2"

# Hide the show apps button
POLICY_PATH="org/gnome/shell/extensions/ding"
POLICY="icon-size"

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/06-desktop-icon-size"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/06-desktop-icon-size"

if [ "$ACTIVATE" = "True" ]; then
  cat << EOF > $POLICY_FILE
[$POLICY_PATH]
$POLICY="$ICON_SIZE"
EOF
  cat << EOF > $POLICY_LOCK_FILE
/$POLICY_PATH/$POLICY
EOF
else
  rm --force $POLICY_FILE $POLICY_LOCK_FILE
fi

dconf update
