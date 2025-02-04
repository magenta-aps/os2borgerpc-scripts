#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason, Sebastian Heiberg
#
# Reference: https://chromeenterprise.google/policies/#IncognitoModeAvailability

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1
INPUT_MODE=$2
POLICY="/etc/opt/chrome/policies/managed/os2borgerpc-enforce-incognito.json"

case $INPUT_MODE in
"Incognito mode available")
    INCOGNITO_MODE=0
    ;;
"Incognito mode disabled")
    INCOGNITO_MODE=1
    ;;
"Incognito mode forced")
    INCOGNITO_MODE=2
    ;;
esac


if [ "$ACTIVATE" = "True" ]; then

    mkdir --parents "$(dirname "$POLICY")"

    cat << EOF > "$POLICY"
{
    "IncognitoModeAvailability": $INCOGNITO_MODE
}

EOF
else
    rm --force $POLICY
fi
