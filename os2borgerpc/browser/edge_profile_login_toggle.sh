#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

ALLOW_PROFILE_LOGIN="$1"

POLICY_FILE="/etc/opt/edge/policies/managed/os2borgerpc-defaults.json"
POLICY="BrowserSignin"
POLICY2="ForceEphemeralProfiles"

set -x

if [ "$ALLOW_PROFILE_LOGIN" = "True" ]; then
  sed --in-place "s/\"$POLICY\": 0,/\"$POLICY\": 1,/" $POLICY_FILE
  sed --in-place "s/\"$POLICY2\": true,/\"$POLICY2\": false,/" $POLICY_FILE
else
  sed --in-place "s/\"$POLICY\": 1,/\"$POLICY\": 0,/" $POLICY_FILE
  sed --in-place "s/\"$POLICY2\": false,/\"$POLICY2\": true,/" $POLICY_FILE
  # Delete any potential saved profiles
  rm --force --recursive "/home/.skjult/.config/microsoft-edge/Default/Preferences" "/home/.skjult/.cache/Microsoft/"
fi
