#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

NEW_URL="$1"

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

CHROMIUM_SCRIPT='/usr/share/os2borgerpc/bin/start_chromium.sh'

if [ ! -f "$CHROMIUM_SCRIPT" ]; then
  echo "Chromium Autostart must be run before this script. Exiting without doing anything."
  exit 1
fi

sed --in-place --regexp-extended "s%(IURL=\").*%\1$NEW_URL\"%" $CHROMIUM_SCRIPT
