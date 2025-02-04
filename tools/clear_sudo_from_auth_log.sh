#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# Related to recurring security event issues in at least in OS2borgerPC image 3.1.0
# Clears all sudo entries from auth.log, which stops the recurring sudo security events

sed --in-place '/sudo/d' /var/log/auth.log
