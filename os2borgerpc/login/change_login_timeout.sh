#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# Change the automatic login timeout. Default is 15 seconds.

# Needs to be an integer
NEW_TIMEOUT_IN_SECONDS=$1

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

GDM_AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/gdm-automatic-login.sh"
LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"

if grep --quiet gdm3 $DEFAULT_DM_FILE; then
  if [ -f "$GDM_AUTOLOGIN_SCRIPT" ]; then
    sed --in-place "s/sleep .*/sleep $NEW_TIMEOUT_IN_SECONDS/" $GDM_AUTOLOGIN_SCRIPT
  else
    echo "Automatic login is currently disabled. It must be enabled before running this script."
    exit 1
  fi
else
  if grep --quiet "autologin-user-timeout" $LIGHTDM_CONFIG; then
    sed --in-place "s/\(autologin-user-timeout=\).*/\1$NEW_TIMEOUT_IN_SECONDS/" $LIGHTDM_CONFIG
  else
    echo "Automatic login is currently disabled. It must be enabled before running this script."
    exit 1
  fi
fi
