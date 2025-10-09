#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

ALLOW_PASSWORD_MANAGER="$1"

POLICY_FILE="/etc/opt/chrome/policies/managed/os2borgerpc-defaults.json"
POLICY="PasswordManagerEnabled"
POLICY2="ForceEphemeralProfiles"

set -x

if [ "$ALLOW_PASSWORD_MANAGER" = "True" ]; then
  sed --in-place "s/\"$POLICY\": false,/\"$POLICY\": true,/" $POLICY_FILE
  sed --in-place "s/\"$POLICY2\": true,/\"$POLICY2\": false,/" $POLICY_FILE
else
  sed --in-place "s/\"$POLICY\": true,/\"$POLICY\": false,/" $POLICY_FILE
  sed --in-place "s/\"$POLICY2\": false,/\"$POLICY2\": true,/" $POLICY_FILE
  # Idempotency check
  if ! grep "$POLICY" $POLICY_FILE; then
    sed --in-place "/MetricsReportingEnabled/a\ \ \ \ \"$POLICY\": false," $POLICY_FILE
  fi
fi
