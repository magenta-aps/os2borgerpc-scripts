#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# SYNOPSIS
#    gnome-shell-hostname-on-panel.sh True|False
#
# DESCRIPTION
#    This script installs a gnome shell extention that displays hostname on the gnome panel bar
#
#    The extention itself is licensed GNU GPL 3 and is found at
#    https://extensions.gnome.org/extension/7353/hostname-on-panel/
#    https://extensions.gnome.org/extension-info/?pk=7353
#
#    Use a boolean argument to decide whether to install or remove the extention.

set -x

# Script arguments
INSTALL=$1 # True | False

# TODO: figure out if we wish to check product ???
# $PRODUCT="$(get_os2borgerpc_config os2_product)"
# if [ "$PRODUCT" != "openworkplace" ]; then
#   echo "Error: Dette script er til 'openworkplace' maskiner, ikke '$PRODUCT'"
#   exit 1
# fi

# download configuration
GNOME_EXT_UUID="hostname-on-panel@casadasereia.net"
GNOME_EXT_VERSION="3"
GNOME_EXT_ZIP_FILE="hostname-on-panelcasadasereia.net.v$GNOME_EXT_VERSION.shell-extension.zip"
GNOME_EXT_ZIP_URL="https://extensions.gnome.org/extension-data/$GNOME_EXT_ZIP_FILE"
GNOME_HIDDEN_DIR="/home/.skjult/.local/share/gnome-shell/extensions/$GNOME_EXT_UUID"
AUTO_HIDDEN_DIR="/home/.skjult/.config/autostart"
AUTO_HIDDEN_FILE="/home/.skjult/.config/autostart/gnome-shell-hostname-on-panel.desktop"

INSTALL_USERS=( 'user' 'superuser' ) # Openworkplace PC installation
# INSTALL_USERS=( "$USER" ) # only for local testing, comment out

if [ "$INSTALL" = "True" ]; then
    echo "Installing Gnome Shell Extention '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION'";
    echo "Downloading URL '$GNOME_EXT_ZIP_URL'"
    TMP_DIR="$(mktemp -t -d 'gnome-extention-hostname-on-panel_XXXXXX')"
    chmod 775 "$TMP_DIR"
    TMP_ZIP="$TMP_DIR/$GNOME_EXT_ZIP_FILE"
    wget --no-verbose "$GNOME_EXT_ZIP_URL" -O "$TMP_ZIP"
    chmod 664 "$TMP_ZIP"
    ls -lhd "$TMP_DIR"
    ls -lh "$TMP_ZIP"

    for INSTALL_USER in "${INSTALL_USERS[@]}"; do
        GNOME_EXT_DIR="/home/$INSTALL_USER/.local/share/gnome-shell/extensions/$GNOME_EXT_UUID"
        GNOME_AUTO_DIR="/home/$INSTALL_USER/.config/autostart"
        GNOME_AUTO_FILE="/home/$INSTALL_USER/.config/autostart/gnome-shell-hostname-on-panel.desktop"

        # normal openworkplace PC script runs as root
        echo "Installing Gnome extention '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION' as user '$INSTALL_USER'"
        # Note: 'runuser -c command user' failed big time ... trying 'runuser --login -c command'
        runuser --login "$INSTALL_USER" -c "gnome-extensions install --force $TMP_ZIP"
        echo "runuser gnome-extensions install return value: $?"
        chmod 664 "$GNOME_EXT_DIR/metadata.json"

        # runuser gnome-extensions enable $GNOME_EXT_UUID does not work here, use autostart file

        echo "Enabeling Gnome extention '$GNOME_EXT_UUID' autostart in '$GNOME_AUTO_FILE'"
        mkdir --parents "$GNOME_AUTO_DIR"
        cat <<- EOF > "$GNOME_AUTO_FILE"
[Desktop Entry]
Type=Application
Exec=gnome-extensions enable $GNOME_EXT_UUID
EOF

        chmod 775 "$GNOME_AUTO_FILE"
        ls -lh "$GNOME_AUTO_FILE"
        cat "$GNOME_AUTO_FILE"

        # '.skjult' is only a directory, not a system user, need to copy manually
        if [ "$INSTALL_USER" == 'user' ]; then
            echo "Copying Gnome extention '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION' to '$GNOME_HIDDEN_DIR'"
            rm --recursive --force "$GNOME_HIDDEN_DIR" # remove old installation before installing
            mkdir --parents "$GNOME_HIDDEN_DIR"
            rsync --perms --recursive --times --verbose "$GNOME_EXT_DIR/" "$GNOME_HIDDEN_DIR"
            ls -lh "$GNOME_HIDDEN_DIR"

            echo "Copying Gnome extention '$GNOME_EXT_UUID' autostart to '$AUTO_HIDDEN_FILE'"
            mkdir --parents "$AUTO_HIDDEN_DIR"
            rsync --perms --recursive --times --verbose "$GNOME_AUTO_DIR/" "$AUTO_HIDDEN_DIR"
        fi
    done

    rm --recursive --force "$TMP_DIR"

elif [ "$INSTALL" = "False" ]; then
    echo "Removing Gnome Shell Extention '$GNOME_EXT_UUID'";

    for INSTALL_USER in "${INSTALL_USERS[@]}"; do
        GNOME_EXT_DIR="/home/$INSTALL_USER/.local/share/gnome-shell/extensions/$GNOME_EXT_UUID"

        # normal openworkplace PC script runs as root
        echo "Removing Gnome extention '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION' as user '$INSTALL_USER'"
        # Note: 'runuser -c command user' failed big time ...
        runuser --login "$INSTALL_USER" -c "gnome-extensions uninstall $GNOME_EXT_UUID"
        echo "runuser gnome-extensions uninstall return value: $?"

        echo "Removing Gnome extention '$GNOME_EXT_UUID' autostart '$GNOME_AUTO_FILE'"
        rm --force "$GNOME_AUTO_FILE"

        # '.skjult' is only a directory, not a system user, need to remove manually
        if [ "$INSTALL_USER" == 'user' ]; then
            echo "Removing Gnome extention '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION' from '/home/.skjult'"
            rm --recursive --force "$GNOME_HIDDEN_DIR" # remove installation

            echo "Removing Gnome extention '$GNOME_EXT_UUID' autostart '$AUTO_HIDDEN_FILE'"
            rm --force "$AUTO_HIDDEN_FILE"
        fi
    done

else
    echo "Script '$0' expected first argument INSTALL=True|False, but got '$1'";
    exit 1
fi
