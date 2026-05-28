#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

POLICY="/etc/opt/chrome/policies/managed/openworkplace-omnissa-horizon.json"

ACTIVATE=$1

DESCRIPTION=$(cat <<EOF
Chrome/Chromium: Policy for Omnissa Horizon klient

Omnissa Horizon klienten forventer at den specielle URL 'vmware-view:*' er tilgængelig.

Dette script tilføjer den relevante URL til listen over de tilladte URL'er via policien "URLAllowlist".

Cookie sessions skal også tillades for ens SSO leverandør, for eksempel kan følgende script benyttes
 - Chrome/Chromium: Policy for Microsoft SSO login
EOF
)

if [ "$ACTIVATE" = "False" ]; then
    rm --force "$POLICY"
elif [ "$ACTIVATE" = "True" ]; then
    mkdir --parents "$(dirname "$POLICY")"

    cat > "$POLICY" <<END
{
    "URLAllowlist": [
        "vmware-view:*"
    ]
}
END
else
    echo "Fejl: Scriptet forventede aktivér parameter True|False, men fik '${ACTIVATE}'"
    echo ""
    echo "$DESCRIPTION"
    exit 1
fi
