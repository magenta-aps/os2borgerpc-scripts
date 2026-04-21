#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas
#
# Fetches the files and file names relevant for profile login in Edge and sends them to the admin portal

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

OUR_USER="user"
KEYRING="/home/$OUR_USER/.local/share/keyrings/Standardnøglering.keyring"
PREFERENCES="/home/$OUR_USER/.config/microsoft-edge/Default/Preferences"
IDENTITY_CACHE_BASE="/home/$OUR_USER/.cache/Microsoft/Edge/IdentityCache/1/UD"

if [ ! -d "/home/$OUR_USER/.config/microsoft-edge" ] || [ ! -d "$IDENTITY_CACHE_BASE" ]; then
  echo "One or more Edge folders not found!"
  echo "Remember to start Edge and log in to the desired profile then close Edge before running this script."
  exit 1
fi

if [ ! -d "$(dirname "$PREFERENCES")" ]; then
  echo "The Edge profile folder has a different name than Default."
  echo "Try logging out and back in again on the computer then start Edge, log in to the desired profile and close Edge before running this script."
  exit 1
fi

if [ -n "$(pgrep edge)" ]; then
  echo "Edge is currently running."
  echo "If this script is run while Edge is running, it may cause unintended behavior on the computers that the fetched profile is added to."
  echo "Please close Edge before running this script again."
  exit 1
fi

# Dynamically determine the names of the folders and files that vary between profiles
IDENTITY_CACHE_FOLDER1=$(ls "$IDENTITY_CACHE_BASE")
IDENTITY_CACHE_FOLDER2=$(ls "$IDENTITY_CACHE_BASE"/"$IDENTITY_CACHE_FOLDER1")
ACCOUNTS_FILE=$(find "$IDENTITY_CACHE_BASE" -regex ".*/Accounts/.*.bin")
PRT_FILE=$(find "$IDENTITY_CACHE_BASE" -regex ".*/PRT/.*.bin")

if [ -f "$PREFERENCES" ] && [ -f "$ACCOUNTS_FILE" ] && [ -f "$PRT_FILE" ]; then
  echo "Below are the names of the two folders and two files whose names may vary between profiles:"
  printf "\n"
  echo "Name of folder 1: $IDENTITY_CACHE_FOLDER1"
  printf "\n"
  echo "Name of folder 2: $IDENTITY_CACHE_FOLDER2"
  printf "\n"
  echo "Name of the Accounts file: $(basename "$ACCOUNTS_FILE")"
  printf "\n"
  echo "Name of the PRT file: $(basename "$PRT_FILE")"
  printf "\n\n"
  echo "Below are the four relevant files necessary to save the Edge profile."
  echo "Their contents have been base64 encoded to prevent issues with special characters."
  echo "The empty lines are not included in the files."
  printf "\n\n"
  echo "This is the keyring file:"
  printf "\n\n"
  base64 "$KEYRING"
  printf "\n\n"
  echo "This is the preferences file:"
  printf "\n\n"
  base64 "$PREFERENCES"
  printf "\n\n"
  echo "This is the accounts file:"
  printf "\n\n"
  base64 "$ACCOUNTS_FILE"
  printf "\n\n"
  echo "This is the PRT file:"
  printf "\n\n"
  base64 "$PRT_FILE"
  printf "\n\n"
else
  echo "One or more of the expected files are missing."
  echo "Try logging out and back in again on the computer then start Edge and log in to the desired profile before running this script."
  exit 1
fi
