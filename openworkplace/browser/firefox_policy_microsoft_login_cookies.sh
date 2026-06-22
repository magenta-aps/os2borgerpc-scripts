#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Adds a policy to Firefox that only allows
# https://login.microsoftonline.com to store cookies for the current session

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE="$1"

FIREFOX_POLICIES="/etc/firefox/policies/policies.json"

if [ "$ACTIVATE" = "True" ]; then
  # Idempotency - Only add the policy once
  if ! grep --quiet "AllowSession" $FIREFOX_POLICIES; then
    # We add it as one line to make it easier to remove
    # The backslashes are for indexing
    sed --in-place "/BlockAboutSupport/a \
    \ \ \ \ \"Cookies\": {\"AllowSession\": [\"https://login.microsoftonline.com\"]}," $FIREFOX_POLICIES
  fi
else
  sed --in-place "/AllowSession/d" $FIREFOX_POLICIES
fi
