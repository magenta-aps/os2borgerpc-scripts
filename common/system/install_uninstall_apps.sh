#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen, Marcus Funch

set -x

INSTALL="$1"
APPNAMES="$2"

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

# Resync the local package index from its remote counterpart
apt-get --assume-yes update
# Attempt to fix broken or interrupted installations
apt-get --assume-yes --fix-broken install

# On 24.04, Pinta can only be installed as a snap
if lsb_release -d | grep --quiet 24 && echo "$APPNAMES" | grep --quiet pinta; then
  PINTA_SNAP="True"
  APPNAMES="${APPNAMES//pinta/}"
fi

# Firefox is a snap on 22.04 and 24.04
if echo "$APPNAMES" | grep --quiet firefox; then
  FIREFOX_SNAP="True"
fi

# Install or remove the chosen package
if [ "$INSTALL" = "True" ]; then
  # shellcheck disable=SC2086  # We want word-splitting to handle multiple apps
  apt-get --assume-yes install $APPNAMES
  if [ "$PINTA_SNAP" = "True" ]; then
    snap install pinta
  fi
else
  # shellcheck disable=SC2086  # We want word-splitting to handle multiple apps
  apt-get --assume-yes remove $APPNAMES
  if [ "$PINTA_SNAP" = "True" ]; then
    snap remove pinta
  fi
  if [ "$FIREFOX_SNAP" = "True" ]; then
    snap remove firefox
  fi
fi

# Remove packages only installed as dependencies, which are no longer dependencies
apt-get --assume-yes autoremove
