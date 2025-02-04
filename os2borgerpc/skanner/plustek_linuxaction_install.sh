#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

FILE=$1

apt-get --assume-yes update

dpkg -i "$FILE"

apt-get --assume-yes --fix-broken install
