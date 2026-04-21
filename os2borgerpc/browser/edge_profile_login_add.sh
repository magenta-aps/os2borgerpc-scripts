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

IDENTITY_CACHE_FOLDER1="$1"
IDENTITY_CACHE_FOLDER2="$2"
ACCOUNTS_FILE_NAME="$3"
PRT_FILE_NAME="$4"
KEYRING_FILE="$5"
PREFERENCES_FILE="$6"
ACCOUNTS_FILE="$7"
PRT_FILE="$8"

KEYRING_PATH="/home/.skjult/.local/share/keyrings/Standardnøglering.keyring"
PREFERENCES_PATH="/home/.skjult/.config/microsoft-edge/Default/Preferences"
IDENTITY_CACHE_BASE_PATH="/home/.skjult/.cache/Microsoft/Edge/IdentityCache/1/UD"
IDENTITY_CACHE_PATH="$IDENTITY_CACHE_BASE_PATH/$IDENTITY_CACHE_FOLDER1/$IDENTITY_CACHE_FOLDER2"
POLICY_FILE="/etc/opt/edge/policies/managed/os2borgerpc-defaults.json"
POLICY="BrowserSignin"
POLICY2="ForceEphemeralProfiles"

[ ! -f $POLICY_FILE ] && echo "This script should be run after Edge has been installed! Exiting." && exit 1

if [ ! -f "$KEYRING_FILE" ] || [ ! -f "$PREFERENCES_FILE" ] || [ ! -f "$ACCOUNTS_FILE" ] || [ ! -f "$PRT_FILE" ]; then
  echo "One or more of the required file parameters are missing. Exiting."
  exit 1
fi

set -x

# Ensure that the Edge policies allow profile login
sed --in-place "s/\"$POLICY\": 0,/\"$POLICY\": 1,/" $POLICY_FILE
sed --in-place "s/\"$POLICY2\": true,/\"$POLICY2\": false,/" $POLICY_FILE

# Attempt to ensure that the binary files have the correct file ending
if ! echo "$ACCOUNTS_FILE_NAME" | grep --quiet ".bin"; then
  ACCOUNTS_FILE_NAME="$ACCOUNTS_FILE_NAME.bin"
fi
if ! echo "$PRT_FILE_NAME" | grep --quiet ".bin"; then
  PRT_FILE_NAME="$PRT_FILE_NAME.bin"
fi

ACCOUNTS_FILE_PATH="$IDENTITY_CACHE_PATH/Accounts/$ACCOUNTS_FILE_NAME"
PRT_FILE_PATH="$IDENTITY_CACHE_PATH/PRT/$PRT_FILE_NAME"

# Remove $IDENTITY_CACHE_BASE_PATH before adding the new folders and files
# to prevent the possibility of multiple folders related to different profiles
# existing simultaneously
rm --force --recursive $IDENTITY_CACHE_BASE_PATH

# Create the directories and move the files
mkdir --parents "$(dirname "$KEYRING_PATH")" "$(dirname "$PREFERENCES_PATH")" \
"$(dirname "$ACCOUNTS_FILE_PATH")" "$(dirname "$PRT_FILE_PATH")"

cp "$KEYRING_FILE" "$KEYRING_PATH"
cp "$PREFERENCES_FILE" "$PREFERENCES_PATH"
cp "$ACCOUNTS_FILE" "$ACCOUNTS_FILE_PATH"
cp "$PRT_FILE" "$PRT_FILE_PATH"
