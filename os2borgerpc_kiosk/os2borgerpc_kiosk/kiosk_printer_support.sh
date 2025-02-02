#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

# Stop Debconf from interrupting when interacting with the package system
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get --assume-yes install cups
