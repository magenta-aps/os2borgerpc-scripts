#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL
#
# SPDX-FileContributor: Søren Howe Gersager
#
# SYNOPSIS
#    change_admin_site args $(admin site url) $(site UID)
#
# DESCRIPTION
#    This script "migrates" a computer to a new admin site.
#
#    This involves changing the admin site url and (optionally)
#    the site uid in the os2borgerpc config file and
#    re-registering. The script works for both BorgerPC and Kiosk.

ADMIN_SITE_URL=$1
SITE_UID=$2

[ "$#" -lt 1 ] && printf "The script needs at least one argument. Exiting." && exit 1

set_os2borgerpc_config admin_url "$ADMIN_SITE_URL"

if [ -n "$SITE_UID" ]; then
    set_os2borgerpc_config site "$SITE_UID"
fi

os2borgerpc_register_in_admin
