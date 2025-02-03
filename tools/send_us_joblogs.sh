#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# TODO: This script is unfinished but is meant for debugging

cd /home/superuser || exit 1

cp --recursive /var/lib/os2borgerpc/jobs .

# Delete all other files
find ./jobs -not -iname output.log --delete

# Remove the arguments from the log as it may contain sensitive data
for file in jobs/*/*; do sed --in-place '/Starting process/d' "$file"; done

# Create a zip file of the output-logs
zip --recurse-paths output-logs.zip jobs

# TODO: Send the file somehow. Maybe base64 encode it and print it to screen so it's in the job log. Is it long enough?

#find /var/lib/os2borgerpc/jobs -name output.log | xargs -I {} zip /home/superuser/logs.zip {}
