#!/bin/sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL
#
# SPDX-FileContributor: Alexander Faithful
#
# SYNOPSIS
#    network_up.sh
#
# DESCRIPTION
#    This script installs or removes a pre-checkin hook that instructs
#    NetworkManager to bring up all network connections known to the target
#    machine.
#
#    Use a boolean to decide whether to enforce this policy or remove it.
#    A checked box enables it, an unchecked box removes the policy.

set -x

if [ ! -f "/usr/local/bin/jobmanager.real" ]; then
    echo "This machine does not have jobmanager hook support"
    exit 1
fi
mkdir --parents /etc/os2borgerpc/pre-checkin.d /etc/os2borgerpc/post-checkin.d

HOOKS="/etc/os2borgerpc/pre-checkin.d/network_up.sh"

if [ "$1" = "True" ]; then
    tee $HOOKS <<"END" > /dev/null
#!/bin/sh

nmcli() {
    command nmcli --terse --colors no "$@"
}

case "$1" in
    pre-checkin)
        nmcli radio wifi on
        nmcli networking on
        for device in $(
            nmcli --fields device,type device status \
                    | egrep '(wifi|ethernet)' \
                    | cut --delimiter : --fields 1); do
            nmcli device connect "$device" && break
        done ;;
    post-checkin)
        # nothing to do
        : ;;
    *)
        echo "$0: unknown or missing hook: $1" 1>&2 ;;
esac
END
    chmod +x $HOOKS
else
    rm --force $HOOKS
fi
