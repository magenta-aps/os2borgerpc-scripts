#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2018 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Andreas Natanel, Marcus Funch
#
# Delete printer

PRINTER_NAME=$1

# Test if printer is deleted
if lpadmin -x "$PRINTER_NAME"; then
    printf '%s\n' "The printer named $PRINTER_NAME has been deleted."
else
    STATUS=$?
    printf '%s\n' "Error: The printer $PRINTER_NAME was not deleted (Error code: $STATUS)" \
                  "Either no printer exists by that name, or something failed when attempting to delete it."
    exit $STATUS
fi
