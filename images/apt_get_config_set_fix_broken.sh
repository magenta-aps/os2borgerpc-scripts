#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Andreas Poulsen
#
# This script is used to add or remove the setting fix-broken "true" from the apt-get configuration
# It takes a single boolean parameter: whether to add the setting or remove it

ACTIVATE=$1

APT_CONFIG_FILE=/etc/apt/apt.conf.d/local

# Always start by trying to remove the line to prevent duplicate entries
sed --in-place '/Fix-Broken/d' $APT_CONFIG_FILE

if [ "$ACTIVATE" = "True" ]; then
  cat << EOF >> $APT_CONFIG_FILE
Apt:Get {Fix-Broken "true";};
EOF
fi
