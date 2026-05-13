#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# Script arguments
INSTALL=$1 # True | False

export DEBIAN_FRONTEND=noninteractive

# debian packages configuration
DEB_INFO="https://www.synaptics.com/products/displaylink-graphics/downloads/ubuntu"
DEB_KEYRING="synaptics-repository-keyring.deb"
DEB_PACKAGE_DRIVER="displaylink-driver"
DEB_PACKAGE_KEYRING="synaptics-repository-keyring"
DEB_SITE="https://www.synaptics.com/sites/default/files/Ubuntu/pool/stable/main/all/"

DEB_KEYRING_URL=$DEB_SITE$DEB_KEYRING

DESCRIPTION=$(cat <<EOF
Installér Synaptics DisplayLink driver

Denne driver benyttes eksempelvis af Polycom Bar eller Lenovo Thinkpad Displaylink.

Computeren skal genstartes efter installationen for at aktivere Displaylink driveren.
Dette kan f.eks. gøres via scriptet "System - Genstart computeren NU".

Kendte mangler:

  Baggrundsbilledet på loginskærmen GDM bliver uhensigtsmæssigt delt over to eller flere skærme, men
  baggrundsbilledet vises korrekt efter login. Dette er en generel udfordring med GDM, som også
  optræder, hvis man benytter flere skærme uden at anvende Displaylink.

  Scriptet virker ikke korrekt med UEFI secure boot. Hvis UEFI secure boot er aktiveret, vil
  installationen forsøge at prompte brugeren til at signere modulet for secure boot, hvilket medfører
  at scriptet hænger indtil timeout.

Producentens information:

  $DEB_INFO

Parametre:

  INSTALL = True|False

Eksempel:

  synaptics_displaylink_driver.sh True|False

EOF
)

set -e

if [ "$INSTALL" = "True" ]; then
    echo "Installing Synaptics Displaylink debian package '$DEB_PACKAGE_DRIVER'"

    TMP_DIR="$(mktemp -t -d 'synaptics-displaylink_XXXXXX')"
    chmod 775 "$TMP_DIR"

    TMP_DEB_KEYRING="$TMP_DIR/$DEB_KEYRING"

    wget --no-verbose "$DEB_KEYRING_URL" -O "$TMP_DEB_KEYRING"
    chmod 664 "$TMP_DEB_KEYRING"

    apt-get install --fix-broken --assume-yes "$TMP_DEB_KEYRING"
    apt-get update
    apt-get install --fix-broken --assume-yes $DEB_PACKAGE_DRIVER
    apt-cache policy $DEB_PACKAGE_KEYRING $DEB_PACKAGE_DRIVER

    rm --recursive --force "$TMP_DIR"

elif [ "$INSTALL" = "False" ]; then
    echo "Removing Synaptics Displaylink debian package '$DEB_PACKAGE_DRIVER'"

    apt-get remove --assume-yes $DEB_PACKAGE_KEYRING $DEB_PACKAGE_DRIVER
    apt-cache policy $DEB_PACKAGE_KEYRING $DEB_PACKAGE_DRIVER

else
    echo "ERROR script expected argument True|False, but got '$INSTALL'"
    echo ""
    echo "$DESCRIPTION"

    exit 1

fi
