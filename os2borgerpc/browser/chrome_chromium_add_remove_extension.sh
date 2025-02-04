#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason
#
# Ref: https://chromeenterprise.google/policies/#ExtensionSettings
#
# This script can:
# 1. Create an ExtensionSettings policy if none exists.
# 2. Add/remove a list(1..*) of Chrome Extensions to/from the ExtensionSettings file.
# 3. Remove the ExtensionSettings policy.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1
EXTENSIONS_ARRAY=$2

POLICIES_DIR="/etc/opt/chrome/policies/managed"
POLICY_FILE="os2borgerpc-extension-settings.json"

if [ "$ACTIVATE" = "True" ]; then

  if [ ! -d "$(dirname "$POLICY_FILE")" ]; then
    mkdir --parents "$(dirname "$POLICY_FILE")"
  fi

  EXTENSIONS_DICT=""
  if [ -n "$EXTENSIONS_ARRAY" ]; then
    IFS=',' read -ra EXTENSIONS_ARRAY <<< "$EXTENSIONS_ARRAY"
    ARR_LEN="${#EXTENSIONS_ARRAY[@]}"

    C=0
    for EXTENSION in "${EXTENSIONS_ARRAY[@]}"
    do
      DICT_TEMPLATE="\"$EXTENSION\": {
      \"installation_mode\": \"force_installed\",
      \"toolbar_pin\": \"force_pinned\",
      \"update_url\": \"https://clients2.google.com/service/update2/crx\"
    }"
      C=$((C+1))
      if [ "$C" -eq "$ARR_LEN" ]; then
        EXTENSIONS_DICT+="    $DICT_TEMPLATE"
      else
        EXTENSIONS_DICT+="$DICT_TEMPLATE,
"
      fi
    done
  fi

  cat << EOF > "$POLICIES_DIR/$POLICY_FILE"
{
  "ExtensionSettings": {
    $EXTENSIONS_DICT
  }
}
EOF

else
    rm "$POLICIES_DIR/$POLICY_FILE"
fi
