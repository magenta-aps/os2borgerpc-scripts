#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  error "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
fi

DOMAIN="$1"
AD_ORG_UNIT_NAME="$2"
AD_ADMIN_USERNAME="$3"
AD_ADMIN_PASSWORD="$4"

export DEBIAN_FRONTEND=noninteractive

apt-get update --quiet

# Install necessary packages
# We need expect to handle a password prompt during the join
if ! apt-get install --assume-yes realmd sssd sssd-tools adcli; then
  echo "Failed to install necessary packages. Exiting."
  exit 1
fi

# Leave the AD domain before we join to ensure that
# we join with the current settings
realm leave "$DOMAIN"

# Ensure that the home dir exists
pam-auth-update --enable mkhomedir

# Join the domain
# We use echo to supply the password that the realm command will ask for
echo "$AD_ADMIN_PASSWORD" | realm join -v -U "$AD_ADMIN_USERNAME" --computer-ou="OU=$AD_ORG_UNIT_NAME" --os-name="$(lsb_release --id --short)" --os-version="$(lsb_release --release --short)" "$DOMAIN"
