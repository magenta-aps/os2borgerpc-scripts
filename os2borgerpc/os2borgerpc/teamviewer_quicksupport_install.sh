#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1

URL="https://download.teamviewer.com/download/teamviewer_qs.tar.gz"
ARCHIVE=$(basename "$URL")
INSTALL_TEMP_PATH="/home/superuser/.local/opt"
INSTALL_PATH="/home/.skjult/.local/opt"
DESKTOP_PATH="/home/.skjult/.local/share/applications"
CLEANUP_D_FILE="/usr/share/os2borgerpc/bin/user-cleanup.d/710-teamviewer-correct-path"
ICON_PATH="/usr/share/icons/teamviewer-icon.png"
ICON_DOWNLOAD_URL="https://os2borgerpc-media.magenta.dk/assorted/teamviewer-icon.png"

# Clean up after old versions of this script
rm --force "/usr/share/applications/teamviewer.desktop" "$CLEANUP_D_FILE"

if [ "$ACTIVATE" = "True" ]; then
    # Download teamviewer quick support (distributed as an archive).
    wget $URL

    tar -xf "$ARCHIVE" && rm "$ARCHIVE"

    mkdir --parents $INSTALL_TEMP_PATH $INSTALL_PATH $DESKTOP_PATH /home/superuser/.local/share/applications

    mv teamviewerqs $INSTALL_TEMP_PATH/teamviewerqs

    chown --recursive superuser:superuser $INSTALL_TEMP_PATH/teamviewerqs
    runuser -l superuser -c $INSTALL_TEMP_PATH/teamviewerqs/teamviewer

    # Ensure that the icon is present
    wget --output-document=$ICON_PATH --quiet $ICON_DOWNLOAD_URL
    sed --in-place "s@Icon=.*@Icon=$ICON_PATH@" $INSTALL_TEMP_PATH/teamviewerqs/teamviewer.desktop

    # Generalize the Exec path
    sed --in-place "s@Exec=.*@Exec=sh -c \"\$HOME/.local/opt/teamviewerqs/tv_bin/script/teamviewer\"@" $INSTALL_TEMP_PATH/teamviewerqs/teamviewer.desktop

    cp --recursive $INSTALL_TEMP_PATH/teamviewerqs $INSTALL_PATH/
    chown --recursive root:root $INSTALL_PATH/teamviewerqs

    cp $INSTALL_PATH/teamviewerqs/teamviewer.desktop /home/superuser/.local/share/applications/
    cp $INSTALL_PATH/teamviewerqs/teamviewer.desktop $DESKTOP_PATH/

else
    rm --recursive --force $INSTALL_PATH/teamviewerqs $DESKTOP_PATH/teamviewer.desktop

    # Remove the local files for all users
    USER_HOME_DIRS=$(ls /home/)
    for DIR in $USER_HOME_DIRS; do
      rm --force --recursive "/home/$DIR/.local/opt/teamviewerqs" "/home/$DIR/.local/share/applications/teamviewer.desktop"
    done
fi
