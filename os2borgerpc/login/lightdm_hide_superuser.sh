#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch
#
# Note: /etc/lighdm/users.conf has a setting to hide a user via this line:
# hidden-users=nobody user2 user3
# HOWEVER this doesn't work if an AccountService has been installed, and it has on Ubuntu incl. BorgerPC.
# Hence we change it in the AccountService config instead.
#
# Reboot or run "systemctl restart lightdm" (which logs you out immediately) for it to take effect.

HIDE_SUPERUSER=$1
SHOW_CUSTOM_LOGIN_FIELD=$2

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

CHOSEN_USER="superuser"
ACCOUNT_SERVICE_SUPERUSER="/var/lib/AccountsService/users/$CHOSEN_USER"
LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"

if [ "$HIDE_SUPERUSER" = "True" ]; then
  FROM="false"
  TO="true"
else
  FROM="true"
  TO="false"
fi

sed --in-place "s/SystemAccount=$FROM/SystemAccount=$TO/" $ACCOUNT_SERVICE_SUPERUSER

if [ "$SHOW_CUSTOM_LOGIN_FIELD" = "True" ]; then

  # Idempotency: Don't add it if it's already there
  if ! grep --quiet -- "greeter-show-manual-login" "$LIGHTDM_CONFIG"; then
    sed --in-place '$ a greeter-show-manual-login=true' $LIGHTDM_CONFIG
  fi
else
  sed --in-place '/greeter-show-manual-login/d' $LIGHTDM_CONFIG
fi
