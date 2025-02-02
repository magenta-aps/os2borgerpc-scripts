#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Andreas Natanel

# Check required parameters
if [ $# -ne 1 ]; then
    echo "This script takes 1 required argument."
    exit 1
fi

lpadmin -d "$1" && lpstat -d
