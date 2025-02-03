#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE="$1"
POLICY="/etc/opt/chrome/policies/managed/os2borgerpc-guestmode-enforced.json"

if [ "$ACTIVATE" = "True" ]; then

  cat << EOF > "$POLICY"
{
  "BrowserGuestModeEnforced": true
}
EOF

else
  rm --force "$POLICY"
fi
