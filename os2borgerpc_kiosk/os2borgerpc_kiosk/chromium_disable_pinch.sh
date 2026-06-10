#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

ACTIVATE="$1"

CHROMIUM_SCRIPT='/usr/share/os2borgerpc/bin/start_chromium.sh'

if [ ! -f "$CHROMIUM_SCRIPT" ] || ! grep --quiet "chromium-browser" $CHROMIUM_SCRIPT; then
  echo "Chromium Autostart has not been run. Exiting without doing anything."
  exit 1
fi

if [ "$ACTIVATE" = "True" ]; then
  # Idempotency - only add the argument once
  if ! grep --quiet "disable-pinch" $CHROMIUM_SCRIPT; then
    sed --in-place "s/chromium-browser/chromium-browser --disable-pinch/" $CHROMIUM_SCRIPT
  fi
else
  sed --in-place "s/ --disable-pinch//" $CHROMIUM_SCRIPT
fi
