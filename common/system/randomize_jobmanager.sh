#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als, Carsten Agger, Marcus Funch, Andreas Poulsen
#
# SYNOPSIS
#    randomize_jobmanager args $(interval in minutes)
#
# DESCRIPTION
#    This script sets the cron.d/os2borgerpc_jobmanager job to execute
#    at a random startup time with a certain interval.
#    So if the interval is 5 minutes, the jobmanager could run at
#    1, 6, 11...56 every hour, instead of 0, 5, 10 ...55.

INTERVAL=$1

CHECKIN_SCRIPT="/usr/share/os2borgerpc/bin/check-in.sh"
CRON_PATH="/etc/cron.d/os2borgerpc-jobmanager"

if [ $# -ne 1 ]; then
    echo "This job takes exactly one parameter."
    exit 1
fi

if [ "$INTERVAL" -gt 59 ] || [ "$INTERVAL" -lt 3 ]; then
    echo "Interval must be between 3 and 59 inclusive."
    exit 1
fi

RANDOM_NUMBER=$((RANDOM%INTERVAL+0))
CRON_COMMAND="$RANDOM_NUMBER,"
# Generate a pseudo-random number between 0 and 59
DELAY_IN_SECONDS=$((RANDOM%60))

# Make sure the folder for the check-in script exists
mkdir --parents "$(dirname "$CHECKIN_SCRIPT")"

cat <<EOF > "$CHECKIN_SCRIPT"
#!/usr/bin/env sh

sleep $DELAY_IN_SECONDS

/usr/local/bin/jobmanager
EOF

chmod 700 "$CHECKIN_SCRIPT"

while [ $((RANDOM_NUMBER+INTERVAL)) -lt 60 ]
do
    RANDOM_NUMBER=$((RANDOM_NUMBER+INTERVAL))
    if [ $((RANDOM_NUMBER+INTERVAL)) -ge 60 ]
    then
        CRON_COMMAND="$CRON_COMMAND$RANDOM_NUMBER * * * * root $CHECKIN_SCRIPT"
    else
        CRON_COMMAND="$CRON_COMMAND$RANDOM_NUMBER,"
    fi
done
echo "$CRON_COMMAND"

# Note: The PATH below is inherited by the scripts jobmanager runs. Fx. they can't find scripts in /usr/local/bin without it
cat <<EOF > "$CRON_PATH"
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$CRON_COMMAND
EOF
