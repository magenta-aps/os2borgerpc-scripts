#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

LOCALE_FILE="/etc/default/locale"

LANG=$(grep "LANG=" $LOCALE_FILE | cut --delimiter "=" --fields 2 | cut --delimiter "_" --fields 1)

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

apt-get update > /dev/null

# shellcheck disable=SC2046 # We want word-splitting here
apt-get install --assume-yes $(check-language-support -l "$LANG")
