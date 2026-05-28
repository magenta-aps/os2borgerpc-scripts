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

POLICY="/etc/opt/chrome/policies/managed/openworkplace-microsoft-sso-login.json"

ACTIVATE=$1

DESCRIPTION=$(cat <<EOF
Chrome/Chromium: Policy for Microsoft SSO login

Dette script tilføjer en policy, der tillader Cookie sessioner for Microsoft login
URL'en 'https://login.microsoftonline.com'.
EOF
)

if [ "$ACTIVATE" = "False" ]; then
    rm --force "$POLICY"
elif [ "$ACTIVATE" = "True" ]; then
    mkdir --parents "$(dirname "$POLICY")"

    cat > "$POLICY" <<END
{
    "CookiesSessionOnlyForUrls": [
        "https://login.microsoftonline.com"
    ]
}
END
else
    echo "Fejl: Scriptet forventede aktivér parameter True|False, men fik '${ACTIVATE}'"
    echo ""
    echo "$DESCRIPTION"
    exit 1
fi
