#! /usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

# Because this script removes the current DM (when switching), which terminates any desktop sessions,
# and interrupts any scripts run from those sessions, the script will not work properly if run manually
# by running jobmanager in a terminal on the desktop while logged in. If one wishes to run the script
# manually, one should therefore do so by running jobmanager in a separate tty

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ "$(lsb_release --release --short | cut --delimiter "." --fields 1)" -lt 24 ]; then
  echo "This script only works on computers with Ubuntu 24 or newer."
  exit 1
fi

CHOSEN_DM=$1

if [ "$CHOSEN_DM" != "lightdm" ] && [ "$CHOSEN_DM" != "gdm" ]; then
  echo "This script only supports choosing lightdm or gdm. Exiting."
  exit 1
fi

DEFAULT_DM_FILE="/etc/X11/default-display-manager"

if grep --quiet "$CHOSEN_DM" $DEFAULT_DM_FILE; then
  echo "This computer is already using $CHOSEN_DM. Exiting without doing anything."
  exit 0
fi

CICERO_PAM_PYTHON_MODULE="/usr/lib/x86_64-linux-gnu/security/os2borgerpc-cicero-pam-module.py"
OTHER_PAM_PYTHON_MODULE="/usr/lib/x86_64-linux-gnu/security/os2borgerpc-custom-login-pam-module.py"
GDM_CONF="/etc/gdm3/custom.conf"
GDM_AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/gdm-automatic-login.sh"
GDM_BG_IMAGE_POLICY="/etc/dconf/db/gdm.d/06-login-screen-bg-image"
GDM_BG_IMAGE_POLICY_LOCK="/etc/dconf/db/gdm.d/locks/06-login-screen-bg-image"
GDM_NUMLOCK_POLICY="/etc/dconf/db/gdm.d/00-numlock"
GDM_NUMLOCK_POLICY_LOCK="/etc/dconf/db/gdm.d/locks/00-numlock"
GDM_POST_SESSION_SCRIPT="/etc/gdm3/PostSession/Default"
GDM_POST_SESSION_DIR="/etc/os2borgerpc/post-session-scripts"
GDM_SUSPEND_SCRIPT="/etc/os2borgerpc/post-session-scripts/suspend_after_time.sh"
GDM_SUSPEND_SERVICE="/etc/systemd/system/suspend_after_time.service"
GDM_IDLE_POLICY="/etc/dconf/db/gdm.d/00-idle-delay"
GDM_IDLE_POLICY_LOCK="/etc/dconf/db/gdm.d/locks/00-idle-delay"
GDM_PAM_FILE="/etc/pam.d/gdm-password"
GDM_PAM_AUTOLOGIN="/etc/pam.d/gdm-autologin"
GDM_PAM_FILES="$GDM_PAM_FILE $GDM_PAM_AUTOLOGIN"
XSET_FILE="/usr/share/os2borgerpc/bin/xset.sh"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
LIGHTDM_DISABLE_WAYLAND_FILE="/etc/lightdm/lightdm.conf.d/10-disable-wayland"
LIGHTDM_GREETER_SETUP_SCRIPT="/etc/lightdm/greeter_setup_script.sh"
LIGHTDM_GREETER_SETUP_DIR="/etc/lightdm/greeter-setup-scripts"
LIGHTDM_NUMLOCK_SCRIPT="/etc/lightdm/greeter-setup-scripts/enable_numlock.sh"
LIGHTDM_BG_IMAGE_POLICY="/etc/dconf/db/os2borgerpc.d/06-login-screen-bg-image"
LIGHTDM_BG_IMAGE_POLICY_LOCK="/etc/dconf/db/os2borgerpc.d/locks/06-login-screen-bg-image"
LIGHTDM_STATE_FILE="/var/lib/lightdm/.cache/unity-greeter/state"
LIGHTDM_PAM_FILE="/etc/pam.d/lightdm"
LIGHTDM_GREETER_PAM="/etc/pam.d/lightdm-greeter"
LIGHTDM_AUTOLOGIN_PAM="/etc/pam.d/lightdm-autologin"
LIGHTDM_PAM_FILES="$LIGHTDM_PAM_FILE $LIGHTDM_GREETER_PAM $LIGHTDM_AUTOLOGIN_PAM"
LOGOUT_TIMER_ACTUAL_LAUNCHER="/usr/share/os2borgerpc/bin/logout_timer_actual_launcher.sh"
OUR_USER="user"

export DEBIAN_FRONTEND=noninteractive
apt-get --assume-yes update

if [ "$CHOSEN_DM" = "lightdm" ]; then
  apt-get install --assume-yes lightdm
  echo "/usr/sbin/lightdm" > $DEFAULT_DM_FILE

  mkdir --parents $LIGHTDM_GREETER_SETUP_DIR

  cat << EOF > $LIGHTDM_CONF
[Seat:*]
session-cleanup-script=/usr/share/os2borgerpc/bin/user-cleanup.bash
allow-guest=false
xserver-allow-tcp=false
greeter-setup-script=/etc/lightdm/greeter_setup_script.sh
EOF

  mkdir --parents "$(dirname $LIGHTDM_DISABLE_WAYLAND_FILE)"

  cat << EOF > $LIGHTDM_DISABLE_WAYLAND_FILE
# No /usr/share/wayland-sessions please
[LightDM]
sessions-directory=/usr/share/xsessions:/usr/share/lightdm/sessions
EOF

  cat << EOF > $LIGHTDM_GREETER_SETUP_SCRIPT
#!/bin/sh
SCRIPT_DIR="$LIGHTDM_GREETER_SETUP_DIR"
greeter_setup_scripts=\$(find \$SCRIPT_DIR -mindepth 1)
for file in \$greeter_setup_scripts
do
    ./"\$file" &
done
EOF

  chmod 700 $LIGHTDM_GREETER_SETUP_SCRIPT

  mv $GDM_POST_SESSION_DIR/* $LIGHTDM_GREETER_SETUP_DIR/ || true
  chmod --recursive 700 $LIGHTDM_GREETER_SETUP_DIR

  # Maintain a chosen login background image
  if [ -f $GDM_BG_IMAGE_POLICY ]; then
    mkdir --parents "$(dirname $LIGHTDM_BG_IMAGE_POLICY_LOCK)"
    BG_IMAGE=$(grep "background-picture-uri" $GDM_BG_IMAGE_POLICY | sed "s@background-picture-uri='file://@'@")
    cat << EOF > $LIGHTDM_BG_IMAGE_POLICY
[com/canonical/unity-greeter]
draw-user-backgrounds=false
background=$BG_IMAGE
EOF
    echo "/com/canonical/unity-greeter/background" > $LIGHTDM_BG_IMAGE_POLICY_LOCK
  fi

  # Maintain idle delay settings
  if [ -f $GDM_IDLE_POLICY ]; then
    cat << EOF > $XSET_FILE
#!/usr/bin/env bash

xset s off
xset -dpms
EOF

    chmod 700 $XSET_FILE

    echo "display-setup-script=$XSET_FILE" >> $LIGHTDM_CONF
  fi

  # Maintain numlock settings
  if [ -f $GDM_NUMLOCK_POLICY ]; then
    if [ ! -f "/usr/bin/numlockx" ]; then
      apt-get update -qq > /dev/null
      apt-get -yqq install numlockx
    fi

    cat << EOF > $LIGHTDM_NUMLOCK_SCRIPT
#!/bin/sh

numlockx on
EOF

    chmod 700 $LIGHTDM_NUMLOCK_SCRIPT

    rm --force $GDM_NUMLOCK_POLICY $GDM_NUMLOCK_POLICY_LOCK
  fi

  # Maintain automatic login settings
  if grep "AutomaticLogin" $GDM_CONF; then
    AUTOMATIC_LOGIN_TIMEOUT=$(grep "sleep" $GDM_AUTOLOGIN_SCRIPT | cut --delimiter " " --fields 2)
    cat << EOF >> $LIGHTDM_CONF
autologin-user-timeout=$AUTOMATIC_LOGIN_TIMEOUT
autologin-user=$OUR_USER
EOF
  fi

  # Ensure that the suspend script continues working if enabled
  if [ -f $GDM_SUSPEND_SERVICE ]; then
    systemctl disable --now "$(basename $GDM_SUSPEND_SERVICE)"
    rm --force $GDM_SUSPEND_SERVICE
  fi

  # Ensure that user is default on the login screen
  mkdir --parents "$(dirname $LIGHTDM_STATE_FILE)"
  cat << EOF > $LIGHTDM_STATE_FILE
[greeter]
last-user=$OUR_USER
EOF
  chown --recursive lightdm:lightdm /var/lib/lightdm/
  chattr +i $LIGHTDM_STATE_FILE

  # Maintain presence/absence of the backup logout timer
  if grep --quiet "# OS2borgerPC Timer" $GDM_PAM_FILE && ! grep --quiet "# OS2borgerPC Timer" $LIGHTDM_PAM_FILE; then
    for f in $LIGHTDM_PAM_FILES; do
      sed --in-place "/@include common-session/i# OS2borgerPC Timer\nsession [success=1 default=ignore] pam_succeed_if.so user != user\nsession optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER" "$f"
    done
  elif ! grep --quiet "# OS2borgerPC Timer" $GDM_PAM_FILE; then
    for f in $LIGHTDM_PAM_FILES; do
      sed --in-place --expression "/# OS2borgerPC Timer/d" --expression "\@session optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER@d" \
      --expression "/session \[success=1 default=ignore\] pam_succeed_if.so user != user/d" "$f"
    done
  fi

  # Ensure that the login integrations continue working
  # We first clean up possible old lines
  sed --in-place --expression '/pam_succeed_if.so user = user/d' --expression '/# OS2borgerPC Cicero/d' \
  --expression '/auth \[success=1 default=ignore\] pam_succeed_if.so user != user/d' --expression "\@auth required pam_python.so@d" \
  --expression '/# OS2borgerPC custom login/d' $LIGHTDM_PAM_FILE
  if [ -f $CICERO_PAM_PYTHON_MODULE ]; then
    sed --in-place "/common-auth/i# OS2borgerPC Cicero\nauth [success=4 default=ignore] pam_succeed_if.so user = user" $LIGHTDM_PAM_FILE
    sed --in-place "/include common-account/i# OS2borgerPC Cicero\nauth [success=1 default=ignore] pam_succeed_if.so user != user\nauth required pam_python.so $CICERO_PAM_PYTHON_MODULE" $LIGHTDM_PAM_FILE
  elif [ -f $OTHER_PAM_PYTHON_MODULE ]; then
    sed --in-place "/common-auth/i# OS2borgerPC custom login\nauth [success=4 default=ignore] pam_succeed_if.so user = user" $LIGHTDM_PAM_FILE
    sed --in-place "/include common-account/i# OS2borgerPC custom login\nauth [success=1 default=ignore] pam_succeed_if.so user != user\nauth required pam_python.so $OTHER_PAM_PYTHON_MODULE" $LIGHTDM_PAM_FILE
  fi

  apt-get remove --assume-yes gdm3

elif [ "$CHOSEN_DM" = "gdm" ]; then
  apt-get install --assume-yes gdm3
  echo "/usr/sbin/gdm3" > $DEFAULT_DM_FILE

  mkdir --parents $GDM_POST_SESSION_DIR

  cat << EOF > $GDM_CONF
[daemon]
WaylandEnable=false

[security]
DisallowTCP=true

[xdmcp]

[chooser]

[debug]
EOF

  cat << EOF > $GDM_POST_SESSION_SCRIPT
#! /usr/bin/env sh

/usr/share/os2borgerpc/bin/user-cleanup.bash

post_session_scripts=\$(find /etc/os2borgerpc/post-session-scripts -mindepth 1)
for file in \$post_session_scripts
do
  ./"\$file" &
done

exit 0
EOF

  chmod 700 $GDM_POST_SESSION_SCRIPT

  # Maintain numlock settings
  if [ -f $LIGHTDM_NUMLOCK_SCRIPT ]; then
    cat << EOF > $GDM_NUMLOCK_POLICY
[org/gnome/desktop/peripherals/keyboard]
numlock-state=true
EOF

    echo "/org/gnome/desktop/peripherals/keyboard/numlock-state" > $GDM_NUMLOCK_POLICY_LOCK

    # In gdm, numlock is controlled via the above dconf policy rather than a post session script
    rm --force $LIGHTDM_NUMLOCK_SCRIPT
  fi

  mv $LIGHTDM_GREETER_SETUP_DIR/* $GDM_POST_SESSION_DIR || true
  chmod --recursive 700 $GDM_POST_SESSION_DIR

  # Ensure that lightdm state file is mutable
  chattr -i $LIGHTDM_STATE_FILE

  # Ensure that gdm supports passwdless login
  if ! grep --quiet "nopasswdlogin" $GDM_PAM_FILE; then
    sed --in-place "/include common-auth/i auth sufficient pam_succeed_if.so user ingroup nopasswdlogin" $GDM_PAM_FILE
  fi

  # Ensure that dconf is set up for gdm
  cat << EOF > "/etc/dconf/profile/gdm"
user-db:user
system-db:gdm
EOF

  mkdir --parents "$(dirname $GDM_BG_IMAGE_POLICY_LOCK)"

  # Maintain a chosen login background image
  if [ -f $LIGHTDM_BG_IMAGE_POLICY ]; then
    BG_IMAGE=$(grep "background=" $LIGHTDM_BG_IMAGE_POLICY | cut --delimiter "'" --fields 2)
    cat << EOF > $GDM_BG_IMAGE_POLICY
[com/ubuntu/login-screen]
background-size='contain'
background-picture-uri='file://$BG_IMAGE'
EOF
    echo "/com/ubuntu/login-screen/background-picture-uri" > $GDM_BG_IMAGE_POLICY_LOCK
  fi

  # Maintain idle delay settings
  if grep --quiet "display-setup-script" $LIGHTDM_CONF; then
    cat << EOF > $GDM_IDLE_POLICY
[org/gnome/desktop/session]
idle-delay=uint32 0
EOF

    echo "/org/gnome/desktop/session/idle-delay" > $GDM_IDLE_POLICY_LOCK
  fi

  # Maintain automatic login settings
  if grep "autologin-user" $LIGHTDM_CONF; then
    AUTOMATIC_LOGIN_TIMEOUT=$(grep "autologin-user-timeout" $LIGHTDM_CONF | cut --delimiter "=" --fields 2)
    cat << EOF > $GDM_AUTOLOGIN_SCRIPT
#!/usr/bin/env bash

sleep $AUTOMATIC_LOGIN_TIMEOUT
if [ -z \$(users) ]; then
  systemctl restart gdm
fi
EOF

    chmod 700 $GDM_AUTOLOGIN_SCRIPT

    sed --in-place "/exit 0/i $GDM_AUTOLOGIN_SCRIPT &" $GDM_POST_SESSION_SCRIPT
    sed --in-place "/daemon/a AutomaticLoginEnable=true\nAutomaticLogin=$OUR_USER" $GDM_CONF
  fi

  # Ensure that the suspend script continues working if enabled
  if [ -f $GDM_SUSPEND_SCRIPT ]; then
    cat << EOF > $GDM_SUSPEND_SERVICE
[Unit]
Description=OS2borgerPC suspend_after_time service

[Service]
Type=simple
ExecStart=$GDM_SUSPEND_SCRIPT

[Install]
WantedBy=multi-user.target
EOF
    systemctl enable "$(basename $GDM_SUSPEND_SERVICE)"
  fi

  # Maintain presence/absence of the backup logout timer
  if grep --quiet "# OS2borgerPC Timer" $LIGHTDM_PAM_FILE && ! grep --quiet "# OS2borgerPC Timer" $GDM_PAM_FILE; then
    for f in $GDM_PAM_FILES; do
      sed --in-place "/@include common-session/i# OS2borgerPC Timer\nsession [success=1 default=ignore] pam_succeed_if.so user != user\nsession optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER" "$f"
    done
  elif ! grep --quiet "# OS2borgerPC Timer" $LIGHTDM_PAM_FILE; then
    for f in $GDM_PAM_FILES; do
      sed --in-place --expression "/# OS2borgerPC Timer/d" --expression "\@session optional pam_exec.so $LOGOUT_TIMER_ACTUAL_LAUNCHER@d" \
      --expression "/session \[success=1 default=ignore\] pam_succeed_if.so user != user/d" "$f"
    done
  fi

  # Ensure that the login integrations continue working
  # We first clean up possible old lines
  sed --in-place --expression '/pam_succeed_if.so user = user/d' --expression '/# OS2borgerPC Cicero/d' \
  --expression '/auth \[success=1 default=ignore\] pam_succeed_if.so user != user/d' --expression "\@auth required pam_python.so@d" \
  --expression '/# OS2borgerPC custom login/d' $GDM_PAM_FILE
  if [ -f $CICERO_PAM_PYTHON_MODULE ]; then
    sed --in-place "/common-auth/i# OS2borgerPC Cicero\nauth [success=4 default=ignore] pam_succeed_if.so user = user" $GDM_PAM_FILE
    sed --in-place "/include common-account/i# OS2borgerPC Cicero\nauth [success=1 default=ignore] pam_succeed_if.so user != user\nauth required pam_python.so $CICERO_PAM_PYTHON_MODULE" $GDM_PAM_FILE
  elif [ -f $OTHER_PAM_PYTHON_MODULE ]; then
    sed --in-place "/common-auth/i# OS2borgerPC custom login\nauth [success=4 default=ignore] pam_succeed_if.so user = user" $GDM_PAM_FILE
    sed --in-place "/include common-account/i# OS2borgerPC custom login\nauth [success=1 default=ignore] pam_succeed_if.so user != user\nauth required pam_python.so $OTHER_PAM_PYTHON_MODULE" $GDM_PAM_FILE
  fi

  apt-get remove --assume-yes lightdm

  # Create symlink necessary for gdm to start automatically
  rm --force /etc/systemd/system/display-manager.service
  ln --symbolic /lib/systemd/system/gdm3.service /etc/systemd/system/display-manager.service
fi

# Update dconf settings
dconf update

# Reboot to complete the switch
reboot
