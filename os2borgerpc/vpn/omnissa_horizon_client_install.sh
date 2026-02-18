#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# UPDATE DEBIAN PACKAGE METADATA HERE
DOWNLOADS="https://customerconnect.omnissa.com/downloads/info/slug/virtual_desktop_and_apps/omnissa_horizon_clients/8"
DEBIAN_NAME="omnissa-horizon-client"
DEBIAN_DEB="Omnissa-Horizon-Client-2512-8.17.0-20187591429.x64.deb"
DEBIAN_URL="https://download3.omnissa.com/software/CART26FQ4_LIN64_DEBPKG_2512/$DEBIAN_DEB"
DEBIAN_SHA256SUM="578c16795a79fea19f1c951a9890d9f4fe9c886a9505d23d0448efa9c8f98d8c"

# Omnissa Horizon config files installation pathes
ETC_OMNISSA_DIR="/etc/omnissa"
HORIZON_MANDATORY_CONFIG_PATH="$ETC_OMNISSA_DIR/horizon-mandatory-config"
HORIZON_DEFAULT_CONFIG_PATH="$ETC_OMNISSA_DIR/horizon-default-config"

# When Omnissa Horizon client starts up, configuration settings are processed from various locations
# in the following order, where first wins over last

#  1. /etc/omnissa/horizon-mandatory-config
#  2. Command-line arguments
#  3. ~/.omnissa/horizon-preferences
#  4. /etc/omnissa/horizon-default-config

# Script arguments for install or uninstall of debian package and config files
INSTALL="$1"
if [ "$INSTALL" = "False" ];
then
    if [ -d "$ETC_OMNISSA_DIR" ];
    then
        echo ""
        echo "Removing Omnissa Horizon config directory '$ETC_OMNISSA_DIR'"
        rm -rf "$ETC_OMNISSA_DIR"
    fi
    if dpkg -l "$DEBIAN_NAME";
    then
        echo "Removing Omnissa Horizon Debian package '$DEBIAN_NAME'";
        echo ""
        if apt-get remove --assume-yes "$DEBIAN_NAME";
        then
            echo "Omnissa Horizon Debian package '$DEBIAN_NAME' sucessfully removed";
        else
            echo "Error: Omnissa Horizon Debian package '$DEBIAN_NAME' removal failed";
            exit 1
        fi
    fi
    exit
fi

# Install Debian package and config files now

# Script arguments for config file content 2: mandatory, 3: default (optional)
# check existance of arguments and supplied file pathes
HORIZON_MANDATORY_CONFIG_FILE="$2"
HORIZON_DEFAULT_CONFIG_FILE="$3"
[ -z "$HORIZON_MANDATORY_CONFIG_FILE" ] \
    && echo "Error: expected HORIZON_MANDATORY_CONFIG_FILE path as second argument" \
    && exit 1
[ -n "$HORIZON_DEFAULT_CONFIG_FILE" ] \
    && echo "Optional HORIZON_DEFAULT_CONFIG_FILE path given as as third argument '$HORIZON_DEFAULT_CONFIG_FILE'"

[ ! -f "$HORIZON_MANDATORY_CONFIG_FILE" ] \
    && echo "Error: expected HORIZON_MANDATORY_CONFIG_FILE path '$HORIZON_MANDATORY_CONFIG_FILE' to exist" \
    && exit 1
[ -n "$HORIZON_DEFAULT_CONFIG_FILE" ] && [ ! -f "$HORIZON_DEFAULT_CONFIG_FILE" ] \
    && echo "Error: expected HORIZON_DEFAULT_CONFIG_FILE path '$HORIZON_DEFAULT_CONFIG_FILE' to exists" \
    && exit 1

[ ! -d "$ETC_OMNISSA_DIR" ] && mkdir -m 755 "$ETC_OMNISSA_DIR"
[ -f "$HORIZON_MANDATORY_CONFIG_FILE" ] \
    && mv "$HORIZON_MANDATORY_CONFIG_FILE" "$HORIZON_MANDATORY_CONFIG_PATH" \
    && chmod 644 "$HORIZON_MANDATORY_CONFIG_PATH"
[ -n "$HORIZON_DEFAULT_CONFIG_FILE" ] && [ -f "$HORIZON_DEFAULT_CONFIG_FILE" ] \
    && mv "$HORIZON_DEFAULT_CONFIG_FILE" "$HORIZON_DEFAULT_CONFIG_PATH" \
    && chmod 644 "$HORIZON_DEFAULT_CONFIG_PATH"

echo "Added or updated Omnissa Horizon client config files"
ls -lh "$ETC_OMNISSA_DIR"/*
echo ""

# Omnissa Horizon Debian package fetch and install from providers own web site
# this installs ./usr/bin/horizon-client among others

if dpkg -l "$DEBIAN_NAME";
then
    echo ""
    echo "Omnissa Horizon Debian package is already installed";
    exit
fi

echo ""
echo "Installing Omnissa Horizon Debian package from vendor";
echo "Downloading URL '$DEBIAN_URL'"

TMP_DIR="$(mktemp -t -d  omnissa_horizon_debian_package_XXXXXXXX)"
TMP_DEB="$TMP_DIR/$DEBIAN_DEB"
wget "$DEBIAN_URL" -O "$TMP_DEB"

if echo "$DEBIAN_SHA256SUM  $TMP_DEB" | sha256sum -c;
then
    echo "Debian package '$DEBIAN_DEB' sha256sum OK";
else                                                                                     
    echo "Error: Debian package '$DEBIAN_DEB' sha256sum mismatch";
    echo "Check and correct script against info found in URL '$DOWNLOADS'";
    [ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"
    [ -d "$ETC_OMNISSA_DIR" ] && rm -rf "$ETC_OMNISSA_DIR"
    exit 1;
fi

echo ""
echo "Installing Omnissa Horizon Debian package";
dpkg --install "$TMP_DEB"
[ -d "$TMP_DIR" ] && rm -rf "$TMP_DIR"

echo ""
if dpkg -l "$DEBIAN_NAME";
then
    echo "Omnissa Horizon Debian package sucessfully installed";
else
    echo "Error: Omnissa Horizon Debian package install failed";
    [ -d "$ETC_OMNISSA_DIR" ] && rm -rf "$ETC_OMNISSA_DIR"
    exit 1
fi
