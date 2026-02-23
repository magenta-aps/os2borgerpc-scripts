#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

set -x

# Script arguments
INSTALL="$1"                       # mandatory, install or uninstall of debian package and config files
HORIZON_MANDATORY_CONFIG_FILE="$2" # mandatory if INSTALL != False
HORIZON_DEFAULT_CONFIG_FILE="$3"   # optional in any case

# UPDATE VENDOR DEBIAN PACKAGE METADATA HERE
DOWNLOADS="https://customerconnect.omnissa.com/downloads/info/slug/virtual_desktop_and_apps/omnissa_horizon_clients/8"
DEBIAN_DEB="Omnissa-Horizon-Client-2512-8.17.0-20187591429.x64.deb"
DEBIAN_NAME="omnissa-horizon-client"
DEBIAN_SHA256SUM="578c16795a79fea19f1c951a9890d9f4fe9c886a9505d23d0448efa9c8f98d8c"
DEBIAN_URL="https://download3.omnissa.com/software/CART26FQ4_LIN64_DEBPKG_2512/$DEBIAN_DEB"
DEBIAN_VERSION="2512-8.17.0-20187591429"

# Omnissa Horizon config files installation pathes from vendor instructions
# When Omnissa Horizon client starts up, configuration settings are processed from various locations
# in the following order, where first wins over last
#  1. /etc/omnissa/horizon-mandatory-config
#  2. Command-line arguments
#  3. ~/.omnissa/horizon-preferences
#  4. /etc/omnissa/horizon-default-config

ETC_OMNISSA_DIR="/etc/omnissa"
HORIZON_MANDATORY_CONFIG_PATH="$ETC_OMNISSA_DIR/horizon-mandatory-config"
HORIZON_DEFAULT_CONFIG_PATH="$ETC_OMNISSA_DIR/horizon-default-config"
HORIZON_CLIENT="/usr/bin/horizon-client"
HORIZON_ICON="/usr/share/icons/horizon-client.png"

# Determine the name of the user desktop directory. This is done via
# xdg-user-dir, which checks the /home/user/.config/user-dirs.dirs file. To ensure
# this file exists, we run xdg-user-dirs-update, which generates it based on the
# environment variable LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DEFAULT_DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")
SKJULT_DESKTOP_DIR="/home/.skjult/$DEFAULT_DESKTOP"
HORIZON_DESKTOP="$SKJULT_DESKTOP_DIR/horizon-client.desktop"

echo ""

INSTALLED_DEBIAN_VERSION=$(dpkg --list "$DEBIAN_NAME" | grep "$DEBIAN_NAME" | grep '^ii' | awk '{ print $3}')

if [ "$INSTALL" = "False" ]; then
    echo "Removing manually installed Omnissa Horizon config files from directory '$ETC_OMNISSA_DIR'"
    rm --recursive --force "$HORIZON_MANDATORY_CONFIG_PATH"
    rm --recursive --force "$HORIZON_DEFAULT_CONFIG_PATH"
    echo ""

    echo "Removing manually installed Omnissa Horizon desktop launcher '$HORIZON_DESKTOP'"
    rm --force "$HORIZON_DESKTOP"
    echo ""

    echo "Checking Omnissa Horizon Debian package '$DEBIAN_NAME'";
    if [ -z "$INSTALLED_DEBIAN_VERSION" ] ; then
        echo "Omnissa Horizon Debian package '$DEBIAN_NAME' is not installed";
    else
        echo "Removing Omnissa Horizon Debian package '$DEBIAN_NAME'";
        if apt-get remove --assume-yes "$DEBIAN_NAME";
        then
            echo "Omnissa Horizon Debian package '$DEBIAN_NAME' sucessfully removed";
        else
            echo "Error: Omnissa Horizon Debian package '$DEBIAN_NAME' removal failed";
            exit 1
        fi
    fi
    exit 0
fi

# Omnissa Horizon Debian package fetch and install from providers own web site
# this installs ./usr/bin/horizon-client among others

if [ "$DEBIAN_VERSION" = "$INSTALLED_DEBIAN_VERSION" ]; then
    echo "Omnissa Horizon Debian package '$DEBIAN_NAME' version '$INSTALLED_DEBIAN_VERSION' is already installed";
else
    echo "Installing Omnissa Horizon Debian package version '$DEBIAN_VERSION' from vendor";
    echo "Downloading URL '$DEBIAN_URL'"

    TMP_DIR="$(mktemp -t -d  omnissa_horizon_debian_package_XXXXXXXX)"
    TMP_DEB="$TMP_DIR/$DEBIAN_DEB"
    wget --no-verbose "$DEBIAN_URL" -O "$TMP_DEB"

    if echo "$DEBIAN_SHA256SUM  $TMP_DEB" | sha256sum -c; then
        echo "Debian package '$DEBIAN_DEB' sha256sum OK";
    else
        echo "Error: Debian package '$DEBIAN_DEB' sha256sum mismatch";
        echo "Check and correct script against info found in URL '$DOWNLOADS'";
        [ -d "$TMP_DIR" ] && rm --recursive --force "$TMP_DIR"
        exit 1;
    fi

    echo ""
    echo "Installing Omnissa Horizon Debian package";
    dpkg --install "$TMP_DEB"
    [ -d "$TMP_DIR" ] && rm --recursive --force "$TMP_DIR"

    INSTALLED_DEBIAN_VERSION=$(dpkg --list "$DEBIAN_NAME" | grep "$DEBIAN_NAME" | grep '^ii' | awk '{ print $3}')
    if [ "$DEBIAN_VERSION" = "$INSTALLED_DEBIAN_VERSION" ]; then
        echo "Omnissa Horizon Debian package '$DEBIAN_NAME' version '$INSTALLED_DEBIAN_VERSION' successfully installed";
    else
        echo "Error: Omnissa Horizon Debian package '$DEBIAN_NAME' version '$DEBIAN_VERSION' install failed";
    exit 1
    fi
fi

echo "Installing Omnissa Horizon desktop launcher '$HORIZON_DESKTOP'"
mkdir --parents --verbose "$SKJULT_DESKTOP_DIR"
cat << EOF > "$HORIZON_DESKTOP"
[Desktop Entry]
Version=$DEBIAN_VERSION
Type=Application
Name=Horizon client
Comment=Omnissa Horizon VPN client
Icon=$HORIZON_ICON
Exec=$HORIZON_CLIENT
EOF
echo ""

# Install admin portal supplied config files in ETC_OMNISSA_DIR
# which exists after above Debian package install
echo ""
echo "Check existence of mandatory and optional arguments when INSTALL=True"

# mandatory config file
[ -z "$HORIZON_MANDATORY_CONFIG_FILE" ] \
    && echo "Error: expected HORIZON_MANDATORY_CONFIG_FILE path as second argument" \
    && exit 1

echo "Mandatory HORIZON_MANDATORY_CONFIG_FILE path given as as second argument '$HORIZON_MANDATORY_CONFIG_FILE'" \
    && mv "$HORIZON_MANDATORY_CONFIG_FILE" "$HORIZON_MANDATORY_CONFIG_PATH" \
    && chmod 644 "$HORIZON_MANDATORY_CONFIG_PATH"

# optional default config file
[ -n "$HORIZON_DEFAULT_CONFIG_FILE" ] \
    && echo "Optional HORIZON_DEFAULT_CONFIG_FILE path given as as third argument '$HORIZON_DEFAULT_CONFIG_FILE'" \
    && mv "$HORIZON_DEFAULT_CONFIG_FILE" "$HORIZON_DEFAULT_CONFIG_PATH" \
    && chmod 644 "$HORIZON_DEFAULT_CONFIG_PATH"

echo "Added or updated Omnissa Horizon client config files"
ls -lh "$ETC_OMNISSA_DIR"/*

exit 0
