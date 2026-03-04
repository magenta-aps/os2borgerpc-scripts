#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Autostart Chromium pointing at OpenStream

set -ex

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

if [ "$(lsb_release --release --short | cut --delimiter "." --fields 1)" -lt 24 ]; then
  echo "This script only works on computers with Ubuntu 24 or newer."
  exit 1
fi

# Separates the programmatic value from the text description
get_value_from_option() {
  echo "$1" | cut --delimiter ":" --fields 1
}

TIME=$1
API_KEY=$2
ORIENTATION=$3
LOCK_DOWN_KEYBINDS=$(get_value_from_option "$4")  # 0: No binds removed, 1: Most binds removed, 2: All binds removed (specifically most + binds for printing, reloading and changing zoom)
OPENSTREAM_SERVER=${5:-produktion}

CUSER="chrome"
XINITRC="/home/$CUSER/.xinitrc"
PROFILE="/home/$CUSER/.profile"
ENVIRONMENT_FILE="/etc/environment"
PC_NAME_FILE="/home/chrome/pc_name"
PC_NAME_FILE_UPDATE_SERVICE="/etc/systemd/system/pc_name_file_update.service"
PC_NAME_FILE_UPDATE_SCRIPT="/usr/share/os2borgerpc/bin/pc_name_file_update.sh"
CHROMIUM_SCRIPT='/usr/share/os2borgerpc/bin/start_chromium.sh'
CHROMIUM_SINGLETON_LOCK="/home/$CUSER/snap/chromium/common/chromium/SingletonLock"
ROTATE_SCREEN_SCRIPT_PATH="/usr/share/os2borgerpc/bin/rotate_screen.sh"
AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/autologin.sh"
AUTOLOGIN_COUNTER="/etc/os2borgerpc/login_counter.txt"
COUNTER_RESET_SERVICE="/etc/systemd/system/reset_login_counter.service"
REBOOT_SCRIPT="/usr/share/os2borgerpc/bin/chromium_error_reboot.sh"
MAXIMUM_CONSECUTIVE_AUTOLOGINS=3
# We use xbindkeys to disable some keyboard shortcuts in case people connect a keyboard to their Kiosk computer.
XBINDKEYS_CONFIG=/home/$CUSER/.xbindkeysrc
EXTENSION_POLICY_FILE="/var/snap/chromium/current/policies/managed/os2borgerpc-extension-settings.json"
EXTENSION_ID="gleekbfjekiniecknbkamfmkohkpodhe"

if ! get_os2borgerpc_config os2_product | grep --quiet rpi; then
  # Note: -intel and -qxl are technically under "recommends" for -all so specifying them isn't strictly needed
  VIDEO_DRIVERS="xserver-xorg-video-qxl xserver-xorg-video-intel xserver-xorg-video-all"
else
  VIDEO_DRIVERS=""
fi

case "$OPENSTREAM_SERVER" in
"test")
  BASE_URL="https://test.openstream.dk"
  ;;
"staging")
  BASE_URL="https://staging.openstream.dk"
  ;;
"produktion")
  BASE_URL="https://openstream.dk"
  ;;
*)
  BASE_URL="$OPENSTREAM_SERVER"
  ;;
esac

# Log output in English, please. More useable as search terms when debugging.
export LANG=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

# Get the computer UID, fail if we can't (though this should never happen)
PC_UID=$(get_os2borgerpc_config uid)
if [ -z "$PC_UID" ]; then
  echo "Failed to get UID. Exiting."
  exit 1
fi

# Install Chromium and a minimal X
apt-get update > /dev/null

apt-get install --assume-yes xinit xserver-xorg-core x11-xserver-utils --no-install-recommends --no-install-suggests
# shellcheck disable=SC2086  # We want word-splitting
apt-get install --assume-yes xdg-utils $VIDEO_DRIVERS xserver-xorg-input-all libleveldb-dev unclutter-xfixes xbindkeys

# Chromium is only available as a snap and will also be installed as
# a snap when using apt-get install
LOG_OUTPUT=$(apt-get install --assume-yes chromium-browser)
# Save exit status so we get the exit status of apt rather than from base64
EXIT_STATUS=$?
echo "$LOG_OUTPUT" | base64

if [ $EXIT_STATUS != 0 ]; then
  echo "Chromium installation failed. Exiting"
  exit $EXIT_STATUS
fi

CHROMIUM_POLICY_FILE="/var/snap/chromium/current/policies/managed/os2borgerpc-defaults.json"
mkdir --parents "$(dirname "$CHROMIUM_POLICY_FILE")"
cat << EOF > $CHROMIUM_POLICY_FILE
{
  "AutofillAddressEnabled": false,
  "AutofillCreditCardEnabled": false,
  "AutoplayAllowed": true,
  "PasswordManagerEnabled": false,
  "TranslateEnabled": false
}
EOF

# Autologin default user
mkdir --parents /etc/systemd/system/getty@tty1.service.d

# Note: The empty ExecStart is not insignificant!
# By default the value is appended, so the empty line changes it to an override
# We make agetty use our own login-program instead of /bin/login
# so we can customize the behavior
cat << EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --login-program $AUTOLOGIN_SCRIPT --autologin $CUSER %I $TERM
Type=idle
EOF

# Create the autologin script

# Ensure that the folder exists
mkdir --parents "$(dirname $AUTOLOGIN_SCRIPT)"

cat << EOF > $AUTOLOGIN_SCRIPT
#!/usr/bin/env bash
COUNTER=\$(cat $AUTOLOGIN_COUNTER)
COUNTER=\$((COUNTER+1))
echo \$COUNTER > $AUTOLOGIN_COUNTER
if [ \$COUNTER -le $MAXIMUM_CONSECUTIVE_AUTOLOGINS ]; then
  if [ \$COUNTER -gt 1 ]; then
    # Sleep before autologin attempts other than the first
    sleep 10
  fi
  # Autologin as $CUSER
  /bin/login -f $CUSER
else
  # Regular login prompt
  /bin/login
fi
EOF

# To maintain the functionality of the error reboot script
if [ -f "$REBOOT_SCRIPT" ]; then
  sed --in-place --expression "\@else@{ n; n; s@/bin/login@$REBOOT_SCRIPT@ }" \
      --expression "s/Regular login prompt/Reboot the computer/" $AUTOLOGIN_SCRIPT
fi

chmod 700 $AUTOLOGIN_SCRIPT

# Create login counter
echo "0" > $AUTOLOGIN_COUNTER

# Create service to reset counter when
# the computer is booted
cat << EOF > $COUNTER_RESET_SERVICE
[Unit]
Description=Reset the autologin counter when the computer starts

[Service]
Type=oneshot
ExecStart=sh -c 'echo "0" > $AUTOLOGIN_COUNTER'

[Install]
WantedBy=multi-user.target
EOF

systemctl enable "$(basename $COUNTER_RESET_SERVICE)"

# Kiosk mode cannot currently be set via policy
# so we set the value in the environment file
# To prevent overwriting changes made by other scripts
# we only set the value if it does not exist
if ! grep --quiet "BPC_KIOSK" "$ENVIRONMENT_FILE"; then
  echo 'BPC_KIOSK="--kiosk"' >> "$ENVIRONMENT_FILE"
fi

# Create a script dedicated to launch chromium, which both xinit or any wm
# launches, to avoid logic duplication, fx. having to update chromium settings
# in multiple files
# If this script's path/name is changed, remember to change it in
# wm_keyboard_install.sh as well
mkdir --parents "$(dirname "$CHROMIUM_SCRIPT")"

cat << EOF > "$CHROMIUM_SCRIPT"
#!/bin/sh

API_KEY="$API_KEY"
COMMON_SETTINGS="--password-store=basic --enable-offline-auto-reload"

# Get pc name
PC_NAME=\$(cat $PC_NAME_FILE)

DIMENSIONS=\$(xrandr | grep '*' | awk '{print \$1}')
IWIDTH="\$(echo \$DIMENSIONS | cut -d'x' -f1)"
IHEIGHT="\$(echo \$DIMENSIONS | cut -d'x' -f2)"

if [ "$ORIENTATION" = "left" ] || [ "$ORIENTATION" = "right" ] ; then
  TEMP=\$IWIDTH
  IWIDTH=\$IHEIGHT
  IHEIGHT=\$TEMP
fi

# Ensure that the Chromium SingletonLock has been deleted
rm --force /home/chrome/snap/chromium/common/chromium/SingletonLock

CONNECT_URL="$BASE_URL/connect-screen?hostname=\$PC_NAME&uid=$PC_UID&apiKey=$API_KEY"

exec chromium-browser "\$BPC_KIOSK" "\$CONNECT_URL" --window-size="\$IWIDTH,\$IHEIGHT" --window-position=0,0 "\$COMMON_SETTINGS"
EOF

chmod +x "$CHROMIUM_SCRIPT"

# Create script to update PC_NAME_FILE
# and delete Chromium's SingletonLock if the name
# has changed. We need PC_NAME_FILE because the
# CHROMIUM_SCRIPT can't use get_os2borgerpc_config
# since it's run by the CUSER user.
# We need to delete Chromium's SingletonLock if the
# name has changed because hostname also changes
# when name changes, which causes Chromium to refuse
# to start unless we delete the SingletonLock
cat << EOF > $PC_NAME_FILE_UPDATE_SCRIPT
#!/usr/bin/env sh

NAME_IN_CONFIG=\$(get_os2borgerpc_config name)

if [ -f "$PC_NAME_FILE" ]; then
  NAME_IN_FILE=\$(cat "$PC_NAME_FILE")
  if [ "\$NAME_IN_CONFIG" != "\$NAME_IN_FILE" ]; then
    rm --force $CHROMIUM_SINGLETON_LOCK
  fi
fi

echo \$NAME_IN_CONFIG > $PC_NAME_FILE
EOF

chmod 700 "$PC_NAME_FILE_UPDATE_SCRIPT"

# Create service to run PC_NAME_FILE_UPDATE_SCRIPT on boot
cat << EOF > $PC_NAME_FILE_UPDATE_SERVICE
[Unit]
Description=Update the pc name file when the computer starts

[Service]
Type=oneshot
ExecStart=$PC_NAME_FILE_UPDATE_SCRIPT

[Install]
WantedBy=multi-user.target
EOF

systemctl enable --now "$(basename $PC_NAME_FILE_UPDATE_SERVICE)"

if [ "$LOCK_DOWN_KEYBINDS" -lt "1" ]; then
  rm --force $XBINDKEYS_CONFIG
else
  XBINDKEYS_MAYBE='xbindkeys &'
  # Attempt at preventing everything except reload, print and zoom
  cat << EOF > $XBINDKEYS_CONFIG
# Prevent saving the page
""
  control + s

# Prevent closing tabs/windows/the browser
""
  control + w
""
  control + shift + w

# Prevent opening new tabs
""
  control + t
""
  control + shift + t

# Prevent opening new windows
""
  control + n
""
  control + shift + n

# Prevent opening the tab selection window
""
  control + shift + a

# Prevent bookmarking
""
  control + d
""
  control + shift + d
""
  control + shift + o

# Prevent opening a file from disk
""
  control + o

# Prevent opening history
""
  control + h

# Prevent opening download history
""
  control + j

# Prevent closing the browser, f has to be uppercase for it to work
""
  alt + F4

# Prevent selecting all text
""
  control + 7
EOF
  # Additionally prevent print, reload and zoom
  if [ "$LOCK_DOWN_KEYBINDS" -gt "1" ]; then
  cat << EOF >> $XBINDKEYS_CONFIG
# Additionally prevent reloading, printing and changing zoom

# Prevent reloading
""
  control + r

# Prevent printing
""
  control + p

# Prevent changing zoom
""
  control + 0
""
  control + shift + 0
""
  control + plus
""
  control + shift + plus
""
  control + minus
""
  control + shift + minus
""
  control + KP_Add
""
  control + KP_Subtract
EOF
  fi
fi

# Launch chromium upon starting up X
cat << EOF > $XINITRC
#!/bin/sh

xset s off
xset s noblank
xset -dpms

$ROTATE_SCREEN_SCRIPT_PATH $TIME $ORIENTATION

$XBINDKEYS_MAYBE

# Launch chromium with its non-WM settings
exec $CHROMIUM_SCRIPT
EOF

# Start X upon login
if ! grep --quiet -- 'exit' $PROFILE; then # Ensure idempotency
  # This first line cleans up after previous versions of the script
  sed --in-place --expression "/startx/d" --expression "/for i in/d" --expression "/sleep/d" \
      --expression "/done/d" --expression "/chromium_error_reboot/d" $PROFILE
  cat << EOF >> $PROFILE
startx
exit
EOF
fi

# Add the extension that makes iFrames work
cat << EOF > $EXTENSION_POLICY_FILE
{
  "ExtensionSettings": {
    "$EXTENSION_ID": {
      "installation_mode": "force_installed",
      "toolbar_pin": "force_pinned",
      "update_url": "https://clients2.google.com/service/update2/crx"
    }
  }
}
EOF
