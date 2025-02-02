#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

OLD_OS2BORGERPC_PULSEAUDIO_CONFIG="/etc/pulse/profile.pa.d/os2borgerpc.pa"
OS2BORGERPC_PULSEAUDIO_CONFIG="/etc/pulse/default.pa.d/os2borgerpc.pa"

[ -f $OLD_OS2BORGERPC_PULSEAUDIO_CONFIG ] && echo "" > $OLD_OS2BORGERPC_PULSEAUDIO_CONFIG
[ -f $OS2BORGERPC_PULSEAUDIO_CONFIG ] && echo "" > $OS2BORGERPC_PULSEAUDIO_CONFIG
