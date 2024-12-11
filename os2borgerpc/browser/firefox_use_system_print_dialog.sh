#!/usr/bin/env bash

set -x

FIREFOX_POLICIES="/etc/firefox/policies/policies.json"

ACTIVATE=$1

if [ "$ACTIVATE" = "True" ]; then
  sed --in-place '/DisableFirefoxAccounts/a\    "UseSystemPrintDialog": true,' "$FIREFOX_POLICIES"
else
  sed --in-place '/UseSystemPrintDialog/d' "$FIREFOX_POLICIES"
fi
