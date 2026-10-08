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
# Omnissa Horizon Client deb package for 64-bit Linux 2026-08-24 version 2606 size 180.32 MB
DOWNLOADS="https://customerconnect.omnissa.com/downloads/info/slug/virtual_desktop_and_apps/omnissa_horizon_clients/8"
DEBIAN_DEB="Omnissa-Horizon-Client-2606-8.19.0-32216036411.x64.deb"
DEBIAN_NAME="omnissa-horizon-client"
DEBIAN_SHA256SUM="7ad50a9a4ad641b3b6985126ff005c34da29641ff59752437fb109851199d0ee"
DEBIAN_URL="https://download3.omnissa.com/software/CART27FQ2_LIN64_DEBPKG_2606/$DEBIAN_DEB"
DEBIAN_VERSION="2606-8.19.0-32216036411"

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

# Determine the name of the user desktop directory. This is done via
# xdg-user-dir, which checks the /home/user/.config/user-dirs.dirs file. To ensure
# this file exists, we run xdg-user-dirs-update, which generates it based on the
# environment variable LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update

DEFAULT_DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")
HORIZON_CLIENT_DESKTOP="horizon-client.desktop"

HORIZON_DESKTOP_LINK_SKJULT="/home/.skjult/$DEFAULT_DESKTOP/$HORIZON_CLIENT_DESKTOP"
HORIZON_DESKTOP_LINK_USER="/home/user/$DEFAULT_DESKTOP/$HORIZON_CLIENT_DESKTOP"
HORIZON_APPLICATION_FILE_SKJULT="/home/.skjult/.local/share/applications/$HORIZON_CLIENT_DESKTOP"
HORIZON_APPLICATION_FILE_USER="/home/user/.local/share/applications/$HORIZON_CLIENT_DESKTOP"
GLOBAL_HORIZON_FILE="/usr/share/applications/$HORIZON_CLIENT_DESKTOP"

# add two mime scheme handlers
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"
X_SCHEME_HANDLER_VMWARE_VIEW="x-scheme-handler/vmware-view=$HORIZON_CLIENT_DESKTOP"
X_SCHEME_HANDLER_HORIZON_CLIENT="x-scheme-handler/horizon-client=$HORIZON_CLIENT_DESKTOP"

# Additional Ubuntu Debian packages needed for Av1, H264, and HEVC media codecs.
# These will NOT be removed when uninstalling the Omnissa client, as they may have been installed
# for other purposes before, for example browser based MS Teams meetings.
# The second additional package depends on the GPU hardware.
DEBIAN_NAME_EXTRA_1="libopenh264-7"
GPU_VENDOR="$(lshw -class display | grep vendor: )"
if echo "$GPU_VENDOR" | grep --quiet --ignore-case "NVIDIA";
  then DEBIAN_NAME_EXTRA_2="libvdpau1"
elif echo "$GPU_VENDOR" | grep --quiet --ignore-case -e "AMD" -e "Advanced Micro Devices";
  then DEBIAN_NAME_EXTRA_2="libopengl0" # probably already installed
elif echo "$GPU_VENDOR" | grep --quiet --ignore-case "INTEL";
  then DEBIAN_NAME_EXTRA_2="intel-media-va-driver-non-free"
else echo "ERROR: Don't know what to do with GPU vendor '${GPU_VENDOR}'"; exit 1
fi

# It turns out that the protocol links from browsers don't work correctly if there is
# a local copy of horizon-client.desktop in ~/.local/share/applications for some reason
# We make sure to delete the local copies (backwards compatibility)
rm --force $HORIZON_APPLICATION_FILE_USER $HORIZON_APPLICATION_FILE_SKJULT 2> /dev/null

echo ""

INSTALLED_DEBIAN_VERSION=$(dpkg --list "$DEBIAN_NAME" | grep "$DEBIAN_NAME" | grep '^ii' | awk '{ print $3}')

# Stop Debconf from doing anything
export DEBIAN_FRONTEND=noninteractive

# Resync the local package index from its remote counterpart
apt-get -qq update

if [ "$INSTALL" = "False" ]; then
    echo "Removing manually installed Omnissa Horizon config files from directory '$ETC_OMNISSA_DIR'"
    rm --recursive --force "$HORIZON_MANDATORY_CONFIG_PATH" "$HORIZON_DEFAULT_CONFIG_PATH"
    echo ""

    echo "Removing manually installed Omnissa Horizon desktop launchers"
    rm --force "$HORIZON_DESKTOP_LINK_SKJULT" "$HORIZON_DESKTOP_LINK_USER" 2> /dev/null
    echo ""

    echo "Removing manually installed Omnissa Horizon mime scheme handlers"
    sed --in-place --expression "\|$X_SCHEME_HANDLER_HORIZON_CLIENT|d" \
        --expression "\|$X_SCHEME_HANDLER_VMWARE_VIEW|d" $GLOBAL_MIME_FILE
    echo ""

    echo "Checking Omnissa Horizon Debian package '$DEBIAN_NAME'";
    if [ -z "$INSTALLED_DEBIAN_VERSION" ] ; then
        echo "Omnissa Horizon Debian package '$DEBIAN_NAME' is not installed";
    else
        echo "Removing Omnissa Horizon Debian package '$DEBIAN_NAME'";
        if apt-get -qq --yes remove "$DEBIAN_NAME";
        then
            echo "Omnissa Horizon Debian package '$DEBIAN_NAME' sucessfully removed";
        else
            echo "Error: Omnissa Horizon Debian package '$DEBIAN_NAME' removal failed";
            exit 1
        fi
    fi

    echo "Not removing Av1, H264, and HEVC media codecs packages ${DEBIAN_NAME_EXTRA_1} ${DEBIAN_NAME_EXTRA_2}"

    # Remove packages only installed as dependencies, which are no longer dependencies
    apt-get -qq --yes autoremove

    exit 0
fi

# Omnissa Horizon Debian package fetch and install from providers own web site
# this installs ./usr/bin/horizon-client among others

echo "Installing extra Debian packages for Av1, H264, and HEVC media codecs: ${DEBIAN_NAME_EXTRA_1} ${DEBIAN_NAME_EXTRA_2}"
apt-get -qq --yes install "$DEBIAN_NAME_EXTRA_1" "$DEBIAN_NAME_EXTRA_2"

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

echo "Installing Omnissa Horizon desktop launcher '$HORIZON_DESKTOP_LINK_SKJULT'"
# ln can't overwrite existing files so we make sure to delete them first
rm --force "$HORIZON_DESKTOP_LINK_SKJULT" "$HORIZON_DESKTOP_LINK_USER"
mkdir --parents "$(dirname "$HORIZON_DESKTOP_LINK_SKJULT")"
ln --symbolic "$GLOBAL_HORIZON_FILE" "$HORIZON_DESKTOP_LINK_SKJULT"

echo "Installing Omnissa Horizon desktop x-scheme-handler"
# Make sure the mime file exists
if [ ! -f $GLOBAL_MIME_FILE ]; then
    cat <<- EOF > $GLOBAL_MIME_FILE
[Default Applications]
EOF
fi
# Idempotency - Only add the lines once
if ! grep --quiet "$HORIZON_CLIENT_DESKTOP" $GLOBAL_MIME_FILE; then
    # Make sure our extra lines are added to the '[Default Applications]' section
    sed --in-place "/Default Applications/a \
$X_SCHEME_HANDLER_VMWARE_VIEW\n\
$X_SCHEME_HANDLER_HORIZON_CLIENT" $GLOBAL_MIME_FILE
fi
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
