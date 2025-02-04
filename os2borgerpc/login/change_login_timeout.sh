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

sed --in-place "s/\(autologin-user-timeout=\).*/\1$NEW_TIMEOUT_IN_SECONDS/" /etc/lightdm/lightdm.conf
