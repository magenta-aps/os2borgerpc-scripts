#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2019 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als
#
# SYNOPSIS
#    logout_user
#
# DESCRIPTION
#    This script will logout the user user immediately

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

user=$(who | grep -wo 'user')

if [ -z "$user" ]; then
    echo "User is not logged in..."
else
    pkill -KILL -u "$user"
    echo "User $user is now logged out."
fi
