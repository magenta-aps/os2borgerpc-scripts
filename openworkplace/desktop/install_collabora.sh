#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger

set -x

INSTALL="$1"

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive


# Resync the local package index from its remote counterpart
apt-get update
# Attempt to fix broken or interrupted installations
apt-get --assume-yes --fix-broken install

if [ "$INSTALL" = "True" ]; then

    # Install instructions taken from Collabora's web site:
    cd /usr/share/keyrings || exit
    wget https://collaboraoffice.com/downloads/gpg/collaboraonline-snapshot-keyring.gpg

    cat << EOF > /etc/apt/sources.list.d/collaboraoffice.sources
Types: deb
URIs: https://www.collaboraoffice.com/downloads/Collabora-Office-25-Snapshot/Linux/apt
Suites: ./
Signed-By: /usr/share/keyrings/collaboraonline-snapshot-keyring.gpg
EOF

    apt-get update

    apt-get --assume-yes install collaboraoffice-desktop
else
    apt-get --assume-yes remove collaboraoffice-desktop
    # Remove packages only installed as dependencies, which are no longer dependencies
    apt-get --assume-yes autoremove
    rm /etc/apt/sources.list.d/collaboraoffice.sources
    apt-get update
fi


