#!/usr/bin/env sh

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# CUPS/lpadmin doesn't like spaces
NAME="$(echo "$1" | tr ' ' '_')"
PRINCH_ID="$2"
DESCRIPTION="$3"
SET_DEFAULT="$4"

if [ "$SET_DEFAULT" = "True" ]; then
  DEFAULT_MAYBE="--default"
fi

# Delete the printer if a printer already exists by that NAME
lpadmin -x "$NAME" || true

# No princh-cloud-printer binary in path, so checking for princh-setup
if which princh-setup > /dev/null; then
   # The two driver options are ISO and US, determining the paper sizes it uses, and specifically whether princheu.ppd (ISO) or princhus.ppd (US) is being used
   # shellcheck disable=SC2086  # With quotes around princh_setup gets an explicitly empty argument and fails because of it
   princh-setup add --name "$NAME" --device-id "$PRINCH_ID" --driver iso --description "$DESCRIPTION" $DEFAULT_MAYBE
   # Finally additionally set the location on the newly added printer
   lpadmin -p "$NAME" -L "$DESCRIPTION"
else
   echo "Princh is not installed. Please run the script that installs Princh before this one."
   exit 1
fi
