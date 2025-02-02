#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Søren Howe Gersager, Marcus Funch, Andreas Poulsen
#
# One-off synchronize time with htpdate.
# Used on instances where NTP ports or NTP synchronization in general are blocked.
# If possible, we recommend opening up in the firewall for NTP instead.
#
# This script may cause jobmanager to time out due to changes in the time settings

set -x

SERVERS_TO_CHECK="0.pool.ntp.org 1.pool.ntp.org 2.pool.ntp.org 3.pool.ntp.org www.wikipedia.org"

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install --assume-yes htpdate

# Ensure that the htpdate service is disabled in case the script times out before htpdate is removed
systemctl disable --now htpdate

echo "Time BEFORE attempting to update the time is:"
date

# htpdate can actually take multiple servers as arguments, but we check the URLs one at a time with timeouts, because by default htpdate seems to check ALL servers,
# not just until one succeeds, and if one doesn't respond it takes minutes to timeout, if it does so at all
# ...so previously the script would end with a jobmanager timeout because a server didn't respond
# With the logic below we stop once the first server responds
for SERVER in $SERVERS_TO_CHECK; do
    if timeout --preserve-status 30s htpdate -s "$SERVER"; then
        echo "Synchronising time with the server $SERVER succeeded."
        SUCCESS=1
        break
    else
        echo "The server $SERVER timed out. Trying the next one if there is one."
    fi
done

echo "Time AFTER attempting to update the time is:"
date

# htpdate only updates the system clock so update the hardware clock from the system clock
hwclock --systohc

# Enabling this service as previous versions of the script disabled it
# because it was under suspicion for interfering and syncing the time back to be incorrect
# (if NTP is blocked by the firewall)
systemctl enable --now systemd-timesyncd

# Clean up and remove htpdate, as otherwise it leaves a service running which continually syncs time
# via htpdate
apt-get remove --assume-yes htpdate

if [ -z "$SUCCESS" ]; then
    echo "Synchronisation failed with all the listed servers"
    exit 1
fi
