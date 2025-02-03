#!/bin/sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Alexander Faithful
#
# SYNOPSIS
#    install_hook_support.sh
#
# DESCRIPTION
#
#    This script patches the OS2borgerPC job manager with support for running
#    hook scripts before and after checking in with the administration system.
#
#    Newer versions of the OS2borgerPC client packages include this
#    functionality by default. This script will do nothing in this case.

set -x

if [ ! -f "/usr/local/bin/jobmanager.real" ]; then
    mv --force /usr/local/bin/jobmanager /usr/local/bin/jobmanager.real
    cat <<"END" > /usr/local/bin/jobmanager
#!/bin/bash

if [ -d "/etc/os2borgerpc/pre-checkin.d" ]; then
    for i in "/etc/os2borgerpc/pre-checkin.d/"*; do
        test -x "$i" && \
                echo "$0: running pre-checkin script $i" && \
                "$i" pre-checkin
    done
fi

/usr/local/bin/jobmanager.real "$@"
STATUS="$?"

if [ -d "/etc/os2borgerpc/post-checkin.d" ]; then
    for i in "/etc/os2borgerpc/post-checkin.d/"*; do
        test -x "$i" && \
                echo "$0: running post-checkin script $i" && \
                "$i" post-checkin "$STATUS"
    done
fi
END
    chmod +x /usr/local/bin/jobmanager
    mkdir --parents /etc/os2borgerpc/pre-checkin.d /etc/os2borgerpc/post-checkin.d
fi
