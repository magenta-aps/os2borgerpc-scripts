#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2020 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Autostart Electron app used for Openstream

set -ex

# Separates the programmatic value from the text description
get_value_from_option() {
  echo "$1" | cut --delimiter ":" --fields 1
}

TIME=$1
API_KEY=$2
ORIENTATION=$3
LOCK_DOWN_KEYBINDS=$(get_value_from_option "$4")  # 0: No binds removed, 1: Most binds removed, 2: All binds removed (specifically most + binds for printing, reloading and changing zoom)

CUSER="chrome"
XINITRC="/home/$CUSER/.xinitrc"
ELECTRON_APP="/home/chrome/os2borgerPC-webview.AppImage"
ELECTRON_SCRIPT='/usr/share/os2borgerpc/bin/start_chromium.sh'
ROTATE_SCREEN_SCRIPT_PATH="/usr/share/os2borgerpc/bin/rotate_screen.sh"
AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/autologin.sh"
AUTOLOGIN_COUNTER="/etc/os2borgerpc/login_counter.txt"
COUNTER_RESET_SERVICE="/etc/systemd/system/reset_login_counter.service"
REBOOT_SCRIPT="/usr/share/os2borgerpc/bin/chromium_error_reboot.sh"
MAXIMUM_CONSECUTIVE_AUTOLOGINS=3
# We use xbindkeys to disable some keyboard shortcuts in case people connect a keyboard to their Kiosk computer.
XBINDKEYS_CONFIG=/home/$CUSER/.xbindkeysrc

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

if [ "$(lsb_release --release --short | cut --delimiter "." --fields 1)" -lt 24 ]; then
  echo "This script only works on computers with Ubuntu 24 or newer."
  exit 1
fi

# Log output in English, please. More useable as search terms when debugging.
export LANG=en_US.UTF-8
export DEBIAN_FRONTEND=noninteractive

if uname -m | grep --quiet x86; then
  DOWNLOAD_URL="https://os2borgerpc-media.magenta.dk/assorted/os2borgerPC-webview-1.0.0.AppImage"
  ARCHITECTURE_DEPS="libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libgtk-3-0t64 libnss3-dev"
else
  DOWNLOAD_URL="https://os2borgerpc-media.magenta.dk/assorted/os2borgerPC-webview-1.0.0-arm64.AppImage"
  ARCHITECTURE_DEPS="zlib1g-dev"
fi

# Make sure that we have support for X
# libfuse2 and libasound2t64 are required to start AppImages
apt-get update --assume-yes
apt-get install --assume-yes xinit xserver-xorg-core x11-xserver-utils --no-install-recommends --no-install-suggests
# We want word-splitting here
# shellcheck disable=SC2086
apt-get install --assume-yes xdg-utils xbindkeys libfuse2 libasound2t64 $ARCHITECTURE_DEPS

# Download the AppImage
# We can't overwrite the AppImage-file if it's currently running
# so we first need to make sure that it is not running
if [ -f $ELECTRON_APP ]; then
  echo "5" > $AUTOLOGIN_COUNTER
  killall xinit || true
  sleep 10 # Give the AppImage time to close completely
fi
wget --output-document=$ELECTRON_APP --quiet $DOWNLOAD_URL

chmod +x $ELECTRON_APP

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

systemctl enable --now "$(basename $COUNTER_RESET_SERVICE)"

# Create a script dedicated to launch the electron app, which both xinit or any wm
# launches, to avoid logic duplication, fx. having to update electron app settings
# in multiple files
# If this script's path/name is changed, remember to change it in
# wm_keyboard_install.sh as well
mkdir --parents "$(dirname "$ELECTRON_SCRIPT")"

cat << EOF > "$ELECTRON_SCRIPT"
#!/bin/sh

API_KEY="$API_KEY"
COMMON_SETTINGS="--no-sandbox"

DIMENSIONS=\$(xrandr | grep '*' | awk '{print \$1}')
IWIDTH="\$(echo \$DIMENSIONS | cut -d'x' -f1)"
IHEIGHT="\$(echo \$DIMENSIONS | cut -d'x' -f2)"

if [ "$ORIENTATION" = "left" ] || [ "$ORIENTATION" = "right" ] ; then
  TEMP=\$IWIDTH
  IWIDTH=\$IHEIGHT
  IHEIGHT=\$TEMP
fi

$ELECTRON_APP \$COMMON_SETTINGS --api_key=\$API_KEY --height=\$IHEIGHT --width=\$IWIDTH
EOF

chmod +x "$ELECTRON_SCRIPT"

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

# Launch the electron app upon starting up X
cat << EOF > $XINITRC
#!/bin/sh

xset s off
xset s noblank
xset -dpms

$ROTATE_SCREEN_SCRIPT_PATH $TIME $ORIENTATION

$XBINDKEYS_MAYBE

# Launch chromium with its non-WM settings
exec $ELECTRON_SCRIPT
EOF

# Start X upon login
PROFILE="/home/$CUSER/.profile"
if ! grep --quiet -- 'exit' $PROFILE; then # Ensure idempotency
  # This first line cleans up after previous versions of the script
  sed --in-place --expression "/startx/d" --expression "/for i in/d" --expression "/sleep/d" \
      --expression "/done/d" --expression "/chromium_error_reboot/d" $PROFILE
  cat << EOF >> $PROFILE
startx
exit
EOF
fi
