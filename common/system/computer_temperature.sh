#!/bin/bash

# SPDX-FileCopyrightText: 2020 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Carsten Agger

# Install acpi
dpkg -l acpi > /dev/null 2>&1
HAS_ACPI=$?

if [[ $HAS_ACPI == 1 ]]; then
    apt-get update -q
    apt-get install -q -y acpi
fi

# Aflæs temperaturen
acpi -t
