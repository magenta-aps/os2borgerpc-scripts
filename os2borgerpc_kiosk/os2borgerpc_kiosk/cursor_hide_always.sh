#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# DESCRIPTION
#    This script is used to always hide the cursor on kiosk.

set -x

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

ACTIVATE=$1

CUSER="chrome"
PROFILE="/home/$CUSER/.profile"

if ! grep --quiet "startx" $PROFILE; then
  echo "You must run Chromium Autostart before this script."
  exit 1
fi

# Idempotency
sed --in-place "s/startx -- -nocursor/startx/" $PROFILE

if [ "$ACTIVATE" = "True" ]; then
  sed --in-place "s/startx/startx -- -nocursor/" $PROFILE
fi
