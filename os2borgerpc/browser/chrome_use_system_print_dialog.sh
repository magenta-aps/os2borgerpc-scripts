#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE="$1"

POLICY_FILE="/etc/opt/chrome/policies/managed/os2borgerpc-use-system-print-dialog.json"
mkdir --parents "$(dirname "$POLICY_FILE")"

if [ "$ACTIVATE" = "True" ]; then
  cat << EOF > $POLICY_FILE
{
    "DisablePrintPreview": true
}
EOF
else
  rm --force $POLICY_FILE
fi
