#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason, Marcus Funch
#
# Lists available scanners

set -x
echo "Running scanimage. Use the output of this command for the default scanner script:"
scanimage -L

echo "See if airscan sees any Apple Airscan or Microsoft WSD supporting scanners:"
airscan-discover
