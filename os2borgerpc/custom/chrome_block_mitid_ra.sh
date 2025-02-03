#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

BLOCK="$1"
URL="https://www.mitid.dk/ra"

POLICY_FILE="/etc/opt/chrome/policies/managed/os2borgerpc-defaults.json"

if [ "$BLOCK" = "True" ]; then
  # Idempotency check
  if ! grep $URL $POLICY_FILE; then
    sed --in-place "/URLBlocklist/a\ \ \ \ \ \ \"$URL\"," $POLICY_FILE
  fi
else
  sed --in-place "\,$URL,d" $POLICY_FILE
fi
