#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Natanel

# Check required parameters
if [ $# -ne 1 ]; then
    echo "This script takes 1 required argument."
    exit 1
fi

if ! lpadmin -d "$1"; then
    echo "It appears there was an error setting the default printer via lpadmin"
fi

if ! lpoptions -d "$1"; then
    echo "It appears there was an error setting the default printer via lpoptions"
fi

# Show the current default printer:
lpstat -d
