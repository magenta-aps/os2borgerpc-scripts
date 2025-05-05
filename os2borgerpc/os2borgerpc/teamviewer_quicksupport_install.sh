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
INSTALL_TEMP_PATH="/home/user/.local/opt"
INSTALL_PATH="/home/.skjult/.local/opt"

if [ "$ACTIVATE" = "True" ]; then
    # Download teamviewer quick support (distributed as an archive).
    wget $URL

    tar -xf "$ARCHIVE" && rm "$ARCHIVE"

    mkdir --parents $INSTALL_TEMP_PATH $INSTALL_PATH

    mv teamviewerqs $INSTALL_TEMP_PATH/teamviewerqs

    chown -R user:user $INSTALL_TEMP_PATH/teamviewerqs
    runuser -l user -c $INSTALL_TEMP_PATH/teamviewerqs/teamviewer

    cp -r $INSTALL_TEMP_PATH/teamviewerqs $INSTALL_PATH/
    chown -R root:root $INSTALL_PATH/teamviewerqs

    cp $INSTALL_PATH/teamviewerqs/teamviewer.desktop /usr/share/applications/
else
    rm -Rf $INSTALL_TEMP_PATH/teamviewerqs $INSTALL_PATH/teamviewerqs
    rm /usr/share/applications/teamviewer.desktop
fi
