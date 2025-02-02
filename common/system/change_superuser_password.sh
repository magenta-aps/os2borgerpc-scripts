#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2013 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch, Sebastian Heiberg
#
# This script will change the superuser password on a OS2borgerPC machine.
#
# Expects exactly two input parameters
#
# NOTE: Even if this script exits with an error due to the password not meeting password complexity requirements, it still updates the password, since practically any password is still better than the default.

set -e

if [ $# -ne 2 ]; then
    printf '%s\n' "usage: $(basename "$0") <password> <confirmation>"
    exit 1
fi

if [ "$1" = "$2" ]; then
    TARGET_USER=superuser
    PASSWORD="$1"

    # The chpasswd always return exit code 0, even when it fails.
    # We therefore need to check if there is a text, only failure to change the password generates text.
    output=$(echo "$TARGET_USER:$PASSWORD" | /usr/sbin/chpasswd 2>&1)

    if [ -n "$output" ]; then
        echo "The password was changed, but it didn't meet the default password complexity requirements, so we strongly recommend a stronger password!"
        echo "Error message: $output"
        exit 1
    fi
else
    printf '%s\n' "Passwords didn't match!"
    exit 1
fi
