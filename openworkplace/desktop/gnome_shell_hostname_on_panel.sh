#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme, Marcus Funch

# SYNOPSIS
#    gnome-shell-hostname-on-panel.sh True|False
#
# DESCRIPTION
#    This script installs a gnome shell extension that displays hostname on the gnome panel bar
#
#    The extension itself is licensed GNU GPL 3 and is found at
#    https://extensions.gnome.org/extension/7353/hostname-on-panel/
#    https://extensions.gnome.org/extension-info/?pk=7353
#
#    Use a boolean argument to decide whether to install or remove the extension.

set -x

# Script arguments
INSTALL=$1 # True | False

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# download configuration
GNOME_EXT_UUID="hostname-on-panel@casadasereia.net"
GNOME_EXT_DIR="/usr/share/gnome-shell/extensions/$GNOME_EXT_UUID"
GNOME_EXT_VERSION="3"
GNOME_EXT_ZIP_FILE="hostname-on-panelcasadasereia.net.v$GNOME_EXT_VERSION.shell-extension.zip"
GNOME_EXT_ZIP_URL="https://extensions.gnome.org/extension-data/$GNOME_EXT_ZIP_FILE"

INSTALL_USERS=".skjult superuser" # Openworkplace PC installation
# INSTALL_USERS="$USER" # only for local testing, comment out

if [ "$INSTALL" = "True" ]; then
    echo "Installing Gnome Shell extension '$GNOME_EXT_UUID' version '$GNOME_EXT_VERSION'";
    echo "Downloading URL '$GNOME_EXT_ZIP_URL'"
    TMP_DIR="$(mktemp -t -d 'gnome-extension-hostname-on-panel_XXXXXX')"
    chmod 775 "$TMP_DIR"
    TMP_ZIP="$TMP_DIR/$GNOME_EXT_ZIP_FILE"
    wget --no-verbose "$GNOME_EXT_ZIP_URL" -O "$TMP_ZIP"
    ls -lhd "$TMP_DIR"

    gnome-extensions install --force "$TMP_ZIP"
    rm --recursive --force "$TMP_DIR" $GNOME_EXT_DIR
    mv /root/.local/share/gnome-shell/extensions/$GNOME_EXT_UUID $GNOME_EXT_DIR/
    # For some reason they start out with permissions not allowing others than root to read them, unlike other extensions in the dir
    chmod 664 "$GNOME_EXT_DIR/metadata.json"

    for INSTALL_USER in $INSTALL_USERS; do
        GNOME_AUTO_FILE="/home/$INSTALL_USER/.config/autostart/gnome-shell-hostname-on-panel.desktop"

        # gnome-extensions enable $GNOME_EXT_UUID does not work here, use autostart file
        mkdir --parents "$(dirname "$GNOME_AUTO_FILE")"
        cat <<- EOF > "$GNOME_AUTO_FILE"
[Desktop Entry]
Type=Application
Exec=gnome-extensions enable $GNOME_EXT_UUID
EOF
        chmod 775 "$GNOME_AUTO_FILE"
    done

elif [ "$INSTALL" = "False" ]; then
    echo "Removing Gnome Shell Extension '$GNOME_EXT_UUID'"

    rm --recursive --force $GNOME_EXT_DIR /home/user/.config/autostart/gnome-shell-hostname-on-panel.desktop

    for INSTALL_USER in $INSTALL_USERS; do
        GNOME_AUTO_FILE="/home/$INSTALL_USER/.config/autostart/gnome-shell-hostname-on-panel.desktop"
        rm --force "$GNOME_AUTO_FILE"
    done
else
    echo "Script '$0' expected first argument INSTALL=True|False, but got '$1'";
    exit 1
fi
