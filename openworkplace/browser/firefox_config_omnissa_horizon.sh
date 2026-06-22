#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Adds an autoconfig to Firefox that automatically allows opening
# the protocol vmware-view: with external protocol handlers.
# This is needed for Omnissa Horizon

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE="$1"

AUTOCONFIG_PREFS="/etc/firefox/defaults/pref/config-prefs.js"
AUTOCONFIG_FILE="/etc/firefox/config.js"
CONFIG_NAME="network.protocol-handler.external.vmware-view"
CONFIG_VALUE="true"

if [ "$ACTIVATE" = "True" ]; then

  # Ensure the folder exists
  mkdir --parents "$(dirname "$AUTOCONFIG_PREFS")"

  cat << EOF > $AUTOCONFIG_PREFS
pref("general.config.filename", "$(basename $AUTOCONFIG_FILE)");
pref("general.config.obscure_value", 0);
EOF

  # Ensure that the autoconfig file starts with a comment
  if [ ! -f "$AUTOCONFIG_FILE" ]; then
    cat << EOF > $AUTOCONFIG_FILE
// IMPORTANT: Start your code on the 2nd line
EOF
  fi

  # Idempotency - only add it once
  if ! grep --quiet "$CONFIG_NAME" $AUTOCONFIG_FILE; then
    cat << EOF >> $AUTOCONFIG_FILE
lockPref("$CONFIG_NAME", $CONFIG_VALUE);
EOF
  fi
else
  if [ -f "$AUTOCONFIG_FILE" ]; then
    sed --in-place "/$CONFIG_NAME/d" $AUTOCONFIG_FILE
  fi
fi
