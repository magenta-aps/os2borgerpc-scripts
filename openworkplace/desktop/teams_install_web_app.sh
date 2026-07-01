#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -x

# Installs a website as a "web app", currently in Chrome.
# Rewriting to Chromium should not be that hard, but Firefox may work significantly differently.

USR=".skjult"
APP="teams"
APP_NAME="chrome-ompifgpmddkgmclendfeacglnodjjndh"
PROFILE="Profile_1"
APP_NAME_PROFILE="${APP_NAME}-$PROFILE"
APP_DESKTOP_FILE_BASENAME="$APP_NAME_PROFILE"
APP_DESKTOP_FILE_NAME="ow-teams.desktop"
#ICON_DEST="/home/$USR/.local/share/icons" # Path option 1
ICON_DEST="/usr/share/icons" # Path option 2

# Determine the name of the user desktop directory. This is done via xdg-user-dir,
# which checks the /home/user/.config/user-dirs.dirs file. To ensure this file exists,
# we run xdg-user-dirs-update, which generates it based on the environment variable
# LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")

DESKTOP_FILE_DEST_1="/home/$USR/$DESKTOP/$APP_DESKTOP_FILE_NAME"
DESKTOP_FILE_DEST_2="/home/$USR/.local/share/applications/$APP_DESKTOP_FILE_NAME"

ACTIVATE=$1

if [ "$ACTIVATE" = "True" ]; then

  wget https://os2borgerpc-media.magenta.dk/assorted/pwa/${APP}2.tar.gz
  tar xzvf ${APP}2.tar.gz

  # Create the directories and desktop files that the PWA normally creates
  # Normally it *also* creates icons under .config/google-chrome, though.
  mkdir --parents "/home/$USR/$DESKTOP"

  # NOTE: Profile name is also hardcoded in here
  # NOTE: The WM class should match the .desktop file name, without the ".desktop" extension
  # This likely needs changes in Wayland, like as StartUPWMClass and --class, instead relying on wayland app-id
	cat <<- EOF > "$DESKTOP_FILE_DEST_1"
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

  cp "$DESKTOP_FILE_DEST_1" $DESKTOP_FILE_DEST_2

  cp --recursive $APP/icons/hicolor $ICON_DEST/
  chmod --recursive a+rX $ICON_DEST/hicolor/

  # NOTE: This needs to point directly to a or multiple directories with the index.theme file
  update-icon-caches $ICON_DEST/hicolor
  #gtk-update-icon-cache $ICON_DEST/hicolor

  # Cleanup
  rm --recursive $APP ${APP}2.tar.gz
else
  find /home -iname "*$APP_DESKTOP_FILE_NAME" -delete
  find $ICON_DEST -iname "*$APP_NAME*" -delete
fi
