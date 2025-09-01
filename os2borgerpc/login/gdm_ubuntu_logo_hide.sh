#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Hides the Ubuntu logo on the GDM login-screen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1

DEFAULT_DM_FILE="/etc/X11/default-display-manager"
POLICY_FILE="/etc/dconf/db/gdm.d/07-login-screen-logo"
POLICY_LOCK_FILE="/etc/dconf/db/gdm.d/locks/07-login-screen-logo"
POLICY_PATH="org/gnome/login-screen"
POLICY="logo"

if ! grep --quiet gdm3 $DEFAULT_DM_FILE; then
  echo "This computer is not using GDM. Exiting."
  exit 1
fi

if [ "$ACTIVATE" = "True" ]; then
  cat << EOF > $POLICY_FILE
[$POLICY_PATH]
$POLICY=''
EOF

  cat << EOF > $POLICY_LOCK_FILE
/$POLICY_PATH/$POLICY
EOF
else
  rm --force $POLICY_FILE $POLICY_LOCK_FILE
fi

dconf update
