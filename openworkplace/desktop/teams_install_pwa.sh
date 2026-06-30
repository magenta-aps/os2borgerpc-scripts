#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -x

# Installs a website as a progressive web app, currently in Chrome.
# Rewriting to Chromium should not be that hard, but Firefox may work significantly differently.

USR=".skjult"
APP="teams"
APP_NAME="chrome-ompifgpmddkgmclendfeacglnodjjndh"
PROFILE="Profile_1"
APP_NAME_PROFILE="${APP_NAME}-$PROFILE"
APP_DESKTOP_FILE_BASENAME="$APP_NAME_PROFILE"
APP_DESKTOP_FILE_NAME="$APP_NAME_PROFILE.desktop"
ICON_DEST="/home/$USR/.local/share/icons" # Or use /usr/share/icons

wget https://os2borgerpc-media.magenta.dk/assorted/pwa/${APP}2.tar.gz
tar xzvf ${APP}2.tar.gz

# Determine the name of the user desktop directory. This is done via xdg-user-dir,
# which checks the /home/user/.config/user-dirs.dirs file. To ensure this file exists,
# we run xdg-user-dirs-update, which generates it based on the environment variable
# LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")

# Create the directories and desktop files that the PWA normally creates
# Normally it *also* creates icons under .config/google-chrome, though.
mkdir --parents "/home/$USR/$DESKTOP" /home/$USR/.gnome/apps

DESKTOP_FILE="/home/.skjult/$DESKTOP/$APP_DESKTOP_FILE_NAME"

# NOTE: Profile name is also hardcoded in here
# NOTE: The WM class should match the .desktop file name, without the ".desktop" extension
# This likely needs changes in Wayland, like as StartUPWMClass and --class, instead relying on wayland app-id
cat <<- EOF > "$DESKTOP_FILE"
	[Desktop Entry]
	Version=1.0
	Terminal=false
	Type=Application
	Name=Microsoft Teams (PWA)
	MimeType=x-scheme-handler/web+msteams;x-scheme-handler/google-chrome;
	Exec=/opt/google/chrome/google-chrome "--profile-directory=Profile 1" --app="https://teams.cloud.microsoft" --class="$APP_DESKTOP_FILE_BASENAME" %U
	Icon=$APP_NAME_PROFILE
	StartupWMClass=$APP_DESKTOP_FILE_BASENAME
EOF

cp "$DESKTOP_FILE" /home/$USR/.local/share/applications/
cp "$DESKTOP_FILE" /home/$USR/.gnome/apps/
echo "OnlyShowIn=Old;" >> /home/$USR/.gnome/apps/$APP_DESKTOP_FILE_NAME

cp --recursive $APP/icons/* $ICON_DEST
update-icon-caches $ICON_DEST

# Cleanup
rm --recursive $APP ${APP}2.tar.gz
