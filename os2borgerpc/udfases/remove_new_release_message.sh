#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Andreas Natanel

release_upgrades_file=/etc/update-manager/release-upgrades

# Simple backup
if [ ! -f $release_upgrades_file.org ]
then 
	cp $release_upgrades_file $release_upgrades_file.org
fi

# Replace Prompt with never value
sed --in-place 's/Prompt=.*/Prompt=never/' $release_upgrades_file
