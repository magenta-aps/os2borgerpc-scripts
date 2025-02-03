#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

FIREFOX_POLICIES="/etc/firefox/policies/policies.json"

ACTIVATE=$1

if [ "$ACTIVATE" = "True" ]; then
  sed --in-place '/DisableFirefoxAccounts/a\    "UseSystemPrintDialog": true,' "$FIREFOX_POLICIES"
else
  sed --in-place '/UseSystemPrintDialog/d' "$FIREFOX_POLICIES"
fi
