#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# Stop switches and lid switches from hibernating or suspending
#
# Designed for OS2borgerPC, but it *should* work on OS2borgerPC Kiosk as well.

DISABLE_SUSPEND_HIBERNATE="$1"

if [ "$DISABLE_SUSPEND_HIBERNATE" = "True" ]; then
  systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
else
  systemctl unmask sleep.target suspend.target hibernate.target hybrid-sleep.target
fi
