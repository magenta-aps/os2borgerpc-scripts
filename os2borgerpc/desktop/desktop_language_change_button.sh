#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

ACTIVATE=$1
SHORTCUT_NAME=$2
ICON_UPLOAD=$3
INITIAL_LANGUAGES=$4

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a Kiosk device."
  exit 1
fi

USERNAME="user"
PAM_ENVIRONMENT="/home/$USERNAME/.pam_environment"

# Prevent the script from running while the language is changed
if [ -f "$PAM_ENVIRONMENT" ]; then
  echo "This script cannot run while the language is changed."
  echo "Log out the default user to reset the language before running this script again."
  exit 1
fi

# Determine the name of the user desktop directory. This is done via
# xdg-user-dir, which checks the /home/user/.config/user-dirs.dirs file. To ensure
# this file exists, we run xdg-user-dirs-update, which generates it based on the
# environment variable LANG. This variable is empty in lightdm so we first export it
# based on the value stored in /etc/default/locale
export "$(grep LANG= /etc/default/locale | tr -d '"')"
runuser -u user xdg-user-dirs-update
DEFAULT_DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")

# Check for the sporadic xdg-user-dir error
if [ "$DEFAULT_DESKTOP" = "$USERNAME" ]; then
  echo "A temporary error prevented the script from running. Try running this script again."
  exit 1
fi

LANGUAGE_SELECT_BUTTON="/home/.skjult/$DEFAULT_DESKTOP/language_select.desktop"
LANGUAGE_SELECT_SCRIPT="/usr/share/os2borgerpc/bin/language_select.sh"
LANGUAGE_INSTALL_SCRIPT="/usr/share/os2borgerpc/bin/language_install.sh"
LANGUAGE_INSTALL_SERVICE="/etc/systemd/system/os2borgerpc-language_install.service"
LANGUAGE_INSTALL_SERVICE_PATH="/etc/systemd/system/os2borgerpc-language_install.path"
LANGUAGE_CHANGE_SCRIPT="/usr/share/os2borgerpc/bin/language_change.sh"
USER_CLEANUP="/usr/share/os2borgerpc/bin/user-cleanup.bash"
GIO_LAUNCHER="/usr/share/os2borgerpc/bin/gio-fix-desktop-file-permissions.sh"
GIO_DBUS="/usr/share/os2borgerpc/bin/gio-dbus.sh"
USER_NEW_LANGUAGE_FILE="/home/$USERNAME/new_language"
NEW_LANGUAGE_FILE="/etc/os2borgerpc/new_language"
KEYBOARD_POLICY="/etc/dconf/db/os2borgerpc.d/01-keyboard-layout"
KEYBOARD_POLICY_LOCK="/etc/dconf/db/os2borgerpc.d/locks/01-keyboard-layout"
FIREFOX_POLICIES="/etc/firefox/policies/policies.json"

if [ "$ACTIVATE" != "True" ]; then
  systemctl disable --now "$(basename $LANGUAGE_INSTALL_SERVICE_PATH)"
  rm --force "$LANGUAGE_SELECT_BUTTON" $LANGUAGE_SELECT_SCRIPT $LANGUAGE_INSTALL_SCRIPT $LANGUAGE_INSTALL_SERVICE $LANGUAGE_INSTALL_SERVICE_PATH $LANGUAGE_CHANGE_SCRIPT $NEW_LANGUAGE_FILE $KEYBOARD_POLICY $KEYBOARD_POLICY_LOCK
  sed --in-place "/rsync/,/xdg-user-dir DESKTOP/ {/xdg-user-dir DESKTOP\|$(basename $LANGUAGE_CHANGE_SCRIPT)/d}" $USER_CLEANUP
  sed --in-place "/RequestedLocales/d" $FIREFOX_POLICIES
  dconf update
  exit 0
fi

# Ensure that the DESKTOP variable in the GIO scripts is quoted
# This is necessary to handle languages where the name of the desktop
# is in two words
if ! grep --quiet \"\$DESKTOP\" $GIO_DBUS; then
  # shellcheck disable=SC2016 # We don't want the expression expanded
  sed --in-place 's/\$DESKTOP/"\$DESKTOP"/' $GIO_DBUS
  # shellcheck disable=SC2016 # We don't want the expression expanded
  sed --in-place 's/\$DESKTOP/"\$DESKTOP"/' $GIO_LAUNCHER
fi

mkdir --parents "$(dirname "$LANGUAGE_SELECT_BUTTON")"

if [ -z "$ICON_UPLOAD" ]; then
  ICON="preferences-desktop-locale"
else
  # HANDLE ICON HERE
  if ! echo "$ICON_UPLOAD" | grep --quiet '.png\|.svg\|.jpg\|.jpeg'; then
    printf "Error: Only .svg, .png, .jpg and .jpeg are supported as icon-formats."
    exit 1
  else
    ICON_BASE_PATH=/usr/local/share/icons
    ICON_NAME="$(basename "$ICON_UPLOAD")"
    mkdir --parents "$ICON_BASE_PATH"
    # Copy icon from the default destination to where it should actually be
    cp "$ICON_UPLOAD" $ICON_BASE_PATH
    # Two ways to reference an icons:
    # 1. As a full path to the icon including it's extension. This works for PNG, SVG, JPG
    # 2. As a name without path and extension, likely as long as it's within an icon cache path. This works for PNG, SVG - but not JPG!
    ICON=$ICON_BASE_PATH/$ICON_NAME

    update-icon-caches $ICON_BASE_PATH
  fi
fi

# Install selected initial languages
apt-get update
IFS=", " read -ra LANG_ARRAY <<< "$INITIAL_LANGUAGES"
PACKAGE_LIST=""
for LANG in "${LANG_ARRAY[@]}"; do
  PACKAGE_LIST="$PACKAGE_LIST $(check-language-support -l "$LANG")"
done
export DEBIAN_FRONTEND=noninteractive # Stop Debconf from doing anything
# shellcheck disable=SC2086 # We want word-splitting here
apt-get install --assume-yes $PACKAGE_LIST

# Make necessary changes to user-cleanup, ensure idempotency
if ! grep --quiet $LANGUAGE_CHANGE_SCRIPT $USER_CLEANUP; then
  sed --in-place --expression "\@$GIO_LAUNCHER@i $LANGUAGE_CHANGE_SCRIPT \"\$DESKTOP\"" \
   --expression "\@$GIO_LAUNCHER@a DESKTOP=\$(runuser -u \$USERNAME xdg-user-dir DESKTOP)" $USER_CLEANUP
fi

# The desktop shortcut
cat << EOF > "$LANGUAGE_SELECT_BUTTON"
[Desktop Entry]
Version=1.0
Type=Application
Name=$SHORTCUT_NAME
Comment=Sprogskifte
Icon=$ICON
Exec=$LANGUAGE_SELECT_SCRIPT
EOF

# Script run when clicking the desktop shortcut
cat << EOF > $LANGUAGE_SELECT_SCRIPT
#!/bin/sh

# If the zenity window is present, we get two PIDs for some reason,
# maybe because the zenity window was started by a service
PID_ZENITY=\$(pgrep --full "Installation af sprog fejlede")
if [ -n "\$PID_ZENITY" ]; then
  for PID in \$PID_ZENITY; do
    kill \$PID
  done
fi

# This needs to be written in a single line to allow us to include spaces in the language names
CHOSEN_LANGUAGE=\$(zenity --list --title "Skift sprog" --text "Vælg det ønskede sprog fra listen" --width=400 --height=600 --hide-column=1 --column "code" --column "Mulige sprog" af_ZA Afrikaans sq_AL Albansk am_ET Amharisk ar_EG Arabisk an_ES Aragonisk as_IN Assamesisk ast_ES Asturian az_AZ Azerbaijansk bn_BD Bengali eu_ES Baskisk bs_BA Bosnisk bg_BG Bulgarsk my_MM Burmesisk ca_ES Catalansk da_DK Dansk en_US Engelsk et_EE Estisk fi_FI Finsk fr_FR Fransk fur_IT Friulian gd_GB Gaelic gl_ES Galicisk el_GR Græsk gu_IN Gujarati he_IL Hebraisk hi_IN Hindi nl_NL Hollandsk be_BY Hviderussisk id_ID Indonesisk ga_IE Irsk is_IS Islandsk it_IT Italiensk ja_JP Japansk kab_DZ Kabyle kn_IN Kannaresisk kk_KZ Kasakhisk km_KH Khmer zh_CN Kinesisk ko_KR Koreansk hr_HR Kroatisk ckb_IQ Central-kurdisk ku_TR Kurdisk lv_LV Lettisk ms_MY Malajisk ml_IN Malayalam mr_IN Marathi ne_NP Nepalesisk nn_NO Nynorsk oc_FR "Occitansk (efter 1500)" or_IN Orija pa_PK Punjabi fa_IR "Persisk (Farsi)" pl_PL Polsk pt_PT Portugisisk ro_RO Rumænsk ru_RU Russisk sr_RS Serbisk szl_PL Silezia si_LK Sinhala sl_SI Slovensk es_ES Spansk sv_SE Svensk tg_TJ Tajik ta_LK Tamil crh_UA Krimtatarisk te_IN Telugu th_TH Thai cs_CZ Tjekkisk tr_TR Tyrkisk de_DE Tysk ug_CN Uigurisk uk_UA Ukrainsk vi_VN Vietnamesisk cy_GB Walisisk xh_ZA Xhosa)

if [ ! -z \$CHOSEN_LANGUAGE ]; then
  if [ ! -z "\$(check-language-support -l "\$CHOSEN_LANGUAGE")" ]; then
    zenity --info --title "Installation af sprog" --text "Vent venligst mens det valgte sprog installeres." &
  fi
  # The file is monitored by a .path-service
  echo "\$CHOSEN_LANGUAGE" > $USER_NEW_LANGUAGE_FILE
fi
EOF

chmod +x $LANGUAGE_SELECT_SCRIPT

# Service that simply runs the language installation script
# We need this because .path-services can only start other services and not scripts
# It does not need to be enabled
cat << EOF > $LANGUAGE_INSTALL_SERVICE
[Unit]
Description=OS2borgerPC language install service

[Service]
Type=oneshot
ExecStart=$LANGUAGE_INSTALL_SCRIPT
EOF

# This .path-service will run and start another service
# if $USER_NEW_LANGUAGE_FILE exists
cat << EOF > $LANGUAGE_INSTALL_SERVICE_PATH
[Path]
PathExists=$USER_NEW_LANGUAGE_FILE

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now "$(basename $LANGUAGE_INSTALL_SERVICE_PATH)"

# Script that installs missing language support for the chosen language
cat << EOF > $LANGUAGE_INSTALL_SCRIPT
#!/bin/sh

if [ -f "$USER_NEW_LANGUAGE_FILE" ]; then
  CHOSEN_LANGUAGE=\$(cat $USER_NEW_LANGUAGE_FILE)
  # Delete the file to prevent the .path-service from running again
  rm $USER_NEW_LANGUAGE_FILE
else # This script should only be run when $USER_NEW_LANGUAGE_FILE exists
  exit 1
fi

MISSING_LANGUAGE_SUPPORT=\$(check-language-support -l "\$CHOSEN_LANGUAGE")

INSTALL_ERROR="False"
if [ ! -z "\$MISSING_LANGUAGE_SUPPORT" ]; then
  apt-get update
  apt-get install --assume-yes \$MISSING_LANGUAGE_SUPPORT || INSTALL_ERROR="True"
fi

export DISPLAY=\$(who | grep -w '$USERNAME' | sed -rn 's/.*\((:[0-9]*)\).*/\1/p')

PID_ZENITY=\$(pgrep --full "Installation af sprog")
if [ -n "\$PID_ZENITY" ]; then
  kill \$PID_ZENITY
fi

if [ "\$INSTALL_ERROR" = "True" ]; then
  runuser -u $USERNAME -- zenity --info --title "Installation af sprog fejlede" --text "Noget gik galt under installationen af det valgte sprog. Vent 5 minutter og prøv igen."
  exit 1
else
  # The script that actually changes the language checks this file
  echo "\$CHOSEN_LANGUAGE" > $NEW_LANGUAGE_FILE
  if runuser -u $USERNAME -- zenity --question --title "Færdiggør sprogskifte" --text "Du skal logge ud og ind igen for at færdiggøre sprogskiftet. Vil du logges ud for at færdiggøre sprogskiftet?"; then
    # I couldn't make gnome-session-quit work when run by a service so I used pkill.
    pkill -KILL -u $USERNAME
  fi
fi
EOF

chmod +x $LANGUAGE_INSTALL_SCRIPT

# Script that actually changes the language, which is run during user-cleanup
cat << END > $LANGUAGE_CHANGE_SCRIPT
#!/bin/sh

NEW_LANGUAGE_FILE="$NEW_LANGUAGE_FILE"
PAM_ENVIRONMENT="$PAM_ENVIRONMENT"
DEFAULT_DESKTOP="$DEFAULT_DESKTOP"
CURRENT_DESKTOP="\$(basename "\$1")"

# Ensure that Desktop shortcuts get added correctly
# even if they're added while the language is changed.
# Since we do this after rsync, the desktop shortcut won't
# show up until after next logout, but that's fine
if [ -n "\$CURRENT_DESKTOP" ] && [ "\$DEFAULT_DESKTOP" != "\$CURRENT_DESKTOP" ] && [ -d "/home/.skjult/\$CURRENT_DESKTOP" ]; then
  mv /home/.skjult/"\$CURRENT_DESKTOP"/* /home/.skjult/"\$DEFAULT_DESKTOP"/
  rm --recursive "/home/.skjult/\$CURRENT_DESKTOP"
fi

if [ -f "\$NEW_LANGUAGE_FILE" ]; then # Change the language for user
  NEW_LANGUAGE=\$(cat \$NEW_LANGUAGE_FILE)
  NEW_LANG=\$NEW_LANGUAGE.UTF-8
  # Generate the standard user folders in the new language
  LANG=\$NEW_LANG runuser -u $USERNAME xdg-user-dirs-update
  # This file determines the language used by GNOME
  cat << EOF > \$PAM_ENVIRONMENT
LANGUAGE  DEFAULT=\$NEW_LANGUAGE:en
LANG  DEFAULT=\$NEW_LANG
LC_NUMERIC  DEFAULT=\$NEW_LANG
LC_TIME DEFAULT=\$NEW_LANG
LC_MONETARY DEFAULT=\$NEW_LANG
LC_PAPER  DEFAULT=\$NEW_LANG
LC_NAME DEFAULT=\$NEW_LANG
LC_ADDRESS  DEFAULT=\$NEW_LANG
LC_TELEPHONE  DEFAULT=\$NEW_LANG
LC_MEASUREMENT  DEFAULT=\$NEW_LANG
LC_IDENTIFICATION DEFAULT=\$NEW_LANG
EOF
  chown $USERNAME:$USERNAME \$PAM_ENVIRONMENT
  NEW_DESKTOP=\$(basename "\$(runuser -u $USERNAME xdg-user-dir DESKTOP)")
  # Rename the desktop folder. We do it this way for two reasons
  # The first is to avoid having to move all files/folders
  # from the old desktop to the new one
  # The second is to partially circumvent the weird issue where
  # xdg-user-dir rarely fails in such a way that
  # DESKTOP=/home/$USERNAME. The language change will still fail
  # when this error occurs, but we avoid /home/$USERNAME ending
  # up in a weird state
  rm --force --recursive "/home/$USERNAME/\$NEW_DESKTOP"
  if [ "\$NEW_DESKTOP" != "$USERNAME" ]; then
    mv "/home/$USERNAME/\$DEFAULT_DESKTOP" "/home/$USERNAME/\$NEW_DESKTOP"
  fi
  # Change the keyboard layout, but allow user to switch back to default keyboard
  DEFAULT_KEYBOARD=\$(grep LANG= /etc/default/locale | cut --delimiter '_' --fields 2 | cut --delimiter '.' --fields 1 | tr '[:upper:]' '[:lower:]')
  if [ "\$NEW_LANGUAGE" = "ar_EG" ]; then
    CHOSEN_KEYBOARD="ara"
  else
    CHOSEN_KEYBOARD=\$(echo \$NEW_LANGUAGE | cut --delimiter '_' --fields 2 | tr '[:upper:]' '[:lower:]')
  fi
  cat << EOF > $KEYBOARD_POLICY
[org/gnome/desktop/input-sources]
sources=[('xkb','\$CHOSEN_KEYBOARD'),('xkb','\$DEFAULT_KEYBOARD')]
EOF
  echo "/org/gnome/desktop/input-sources/sources" > $KEYBOARD_POLICY_LOCK
  # Firefox doesn't automatically detect the chosen language
  # unlike Chrome and Edge so we modify the policy file to specify
  # the desired language
  sed --in-place "/RequestedLocales/d" $FIREFOX_POLICIES
  sed --in-place "/SanitizeOnShutdown/i \ \ \ \ \"RequestedLocales\": \"\$NEW_LANGUAGE\"," $FIREFOX_POLICIES
  rm \$NEW_LANGUAGE_FILE
  dconf update
else # Ensure that the language is correctly reverted to the default
  \$(grep LANG= /etc/default/locale | tr -d '"') runuser -u $USERNAME xdg-user-dirs-update
  # Revert the change to the Firefox policy file
  sed --in-place "/RequestedLocales/d" $FIREFOX_POLICIES
  # Delete the keyboard layout policy files.
  # It's done this way to avoid running dconf update on every logout
  if [ -f "$KEYBOARD_POLICY" ]; then
    rm --force $KEYBOARD_POLICY $KEYBOARD_POLICY_LOCK
    dconf update
  fi
fi
END

chmod 700 $LANGUAGE_CHANGE_SCRIPT
