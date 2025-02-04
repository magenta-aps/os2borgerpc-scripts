#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

export DEBIAN_FRONTEND=noninteractive

ACTIVATE=$1

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

PKG="linux-generic-hwe-$(lsb_release --release --short)"

if [ "$ACTIVATE" = "True" ]; then
  apt-get install --assume-yes "$PKG"
else
  apt-get remove --assume-yes "$PKG"
fi
