#!/usr/bin/env bash

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1

# We need to hide the button, block the "Super"-shortcut
# and block the "Super+s"-shortcut. This requires
# three different policies

# Hide the show apps button
POLICY_PATH1="org/gnome/shell/extensions/dash-to-dock"
POLICY1="show-show-apps-button"
POLICY_VALUE1="false"

# Block the "Super"-shortcut
POLICY_PATH2="org/gnome/mutter"
POLICY2="overlay-key"
POLICY_VALUE2="''"

# Block the "Super+s"-shortcut
POLICY_PATH3="org/gnome/shell/keybindings"
POLICY3="toggle-overview"
POLICY_VALUE3="@as []"

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/04-block-apps-overview"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/04-block-apps-overview"

if [ "$ACTIVATE" = "True" ]; then
  cat << EOF > $POLICY_FILE
[$POLICY_PATH1]
$POLICY1=$POLICY_VALUE1
[$POLICY_PATH2]
$POLICY2=$POLICY_VALUE2
[$POLICY_PATH3]
$POLICY3=$POLICY_VALUE3
EOF
  cat << EOF > $POLICY_LOCK_FILE
/$POLICY_PATH1/$POLICY1
/$POLICY_PATH2/$POLICY2
/$POLICY_PATH3/$POLICY3
EOF
else
  rm --force $POLICY_FILE $POLICY_LOCK_FILE
fi

dconf update
