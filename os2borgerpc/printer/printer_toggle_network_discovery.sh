#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch, Emil Nordahn Andersen, Andreas Poulsen
#
# Enable / Disable network printer discovery.
# Use a boolean to enable or disable. A checked box will disable
# network printer discovery and an unchecked one will enable it.
# As a side effect all network printers previously found are removed
# and any you want, have to be added manually.
# Log out or restart if changes don't take immediate effect.
#
# Attempted solutions that proved insufficient:
#   1. Disable fx. BrowseProtocols in /etc/cups/cupsd.conf AND
#      /etc/cups/cups-browsed.conf
#   2. Completely disable cups-browsed: systemctl mask cups-browsed

set -ex

ACTIVATE=$1

POLKIT_POLICY="/etc/polkit-1/rules.d/01-os2borgerpc-deny-user-managing-units.rules"
POLKIT_POLICY_LEGACY="/etc/polkit-1/localauthority/10-vendor.d/01-os2borgerpc-deny-user-managing-units.pkla"
RELEASE=$(lsb_release --release --short)

if [ "$ACTIVATE" = "True" ]; then
  # Disable network printer discovery
  systemctl mask avahi-daemon cups-browsed
  # Mask vs. disable: https://askubuntu.com/a/816378/284161
  systemctl stop avahi-daemon cups-browsed
  if [ "$RELEASE" = "20.04" ] || [ "$RELEASE" = "22.04" ]; then # 20.04 and 22.04 support
    cat <<- EOF > $POLKIT_POLICY_LEGACY
[User shan't manage units, to prevent simple-scan/saned from prompting for password trying to start avahi-daemon]
Identity=unix-user:user
Action=org.freedesktop.systemd1.manage-units
ResultAny=no
ResultInactive=no
ResultActive=no
EOF
  else # 24.04 support
    cat <<- EOF > $POLKIT_POLICY
polkit.addRule(function(action, subject) {
    var users = ["user"]
    var actions = ["org.freedesktop.systemd1.manage-units"]

    if (users.indexOf(subject.user) >= 0) {
      for (var i = 0; i < actions.length; i++) {
        if (action.id.includes(actions[i])) return polkit.Result.NO
      }
    }
})
EOF
  fi

else # Enable network printer discovery
  systemctl unmask avahi-daemon cups-browsed
  systemctl start avahi-daemon cups-browsed

  rm --force $POLKIT_POLICY $POLKIT_POLICY_LEGACY
fi
