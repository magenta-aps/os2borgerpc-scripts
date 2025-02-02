#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

set -x

NET_USB="$1"
NAME="$2"
IP="$3" # If $1 is "net"

[ "$NET_USB" = "0" ] && NET_USB="usb" || NET_USB="net"
[ "$NET_USB" = "usb" ] && unset IP  # Make sure it's empty in case something random has been typed in

# -x: Print no test page
hp-setup --interactive --auto -x --printer "$NAME" -b "$NET_USB" "$IP"
