#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Søren Howe Gersager, Andreas Poulsen
#
# SYNOPSIS
#    unexpire_user.sh
#
# DESCRIPTION
#    This script unexpires the "user" account after it has been
#    set expired.
#
#    For use with the "lockdown_usb.sh" and
#    "detect_user_expired_event.py" script.

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Check if we should run user-cleanup.bash,
# i.e. if the user account has actually been expired
EXPIRED=$(chage -l user | grep 1970)

# Unexpire user
usermod -e '' user

# Run user-cleanup.bash after unexpiring user to avoid issues with gio
if [ -n "$EXPIRED" ]; then
  /usr/share/os2borgerpc/bin/user-cleanup.bash
fi
