#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch, Andreas Poulsen

set -ex

# lpadmin doesn't like spaces
NAME="$(echo "$1" | tr ' ' '_')"
HOST="$2"
DESCRIPTION="$3"
PROTOCOL="${4:-ipp}"
SET_STANDARD="$5"

[ "$PROTOCOL" = "ipp" ] || [ "$PROTOCOL" = "ipps" ] && ENABLE_IPP_EVERYWHERE="-m everywhere"

# shellcheck disable=SC2086  # We want word-splitting in the last argument
lpadmin -p "$NAME" -v "$PROTOCOL://$HOST" -D "$DESCRIPTION" -L "$DESCRIPTION" -E $ENABLE_IPP_EVERYWHERE

if [ "$SET_STANDARD" = "True" ]; then
  # Set the printer as standard printer
  lpadmin -d "$NAME" && lpstat -d
fi
