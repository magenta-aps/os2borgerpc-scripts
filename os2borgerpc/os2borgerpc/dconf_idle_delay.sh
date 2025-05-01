#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Change these three to set a different policy to another value
POLICY_PATH="org/gnome/desktop/session"
POLICY="idle-delay"
POLICY_VALUE="uint32 0"

DEFAULT_DM_FILE="/etc/X11/default-display-manager"
POLICY_FILE="/etc/dconf/db/os2borgerpc.d/00-$POLICY"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/00-$POLICY"
GDM_POLICY_FILE="/etc/dconf/db/gdm.d/00-$POLICY"
GDM_POLICY_LOCK_FILE="/etc/dconf/db/gdm.d/locks/00-$POLICY"
XSET_FILE="/usr/share/os2borgerpc/bin/xset.sh"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"

ACTIVATE=$1

if [ "$ACTIVATE" = 'True' ]; then

  cat << EOF > "$POLICY_FILE"
[$POLICY_PATH]
$POLICY=$POLICY_VALUE
EOF

  # Tell the system that the values of the dconf keys we've just set can no
  # longer be overridden by the user
  cat << EOF > "$POLICY_LOCK_FILE"
/$POLICY_PATH/$POLICY
EOF

  if grep --quiet "gdm3" $DEFAULT_DM_FILE; then
    cp "$POLICY_FILE" "$GDM_POLICY_FILE"
    cp "$POLICY_LOCK_FILE" "$GDM_POLICY_LOCK_FILE"
  else
    cat << EOF > $XSET_FILE
#!/usr/bin/env bash

xset s off
xset -dpms
EOF

    chmod 700 $XSET_FILE

    if ! grep --quiet "display-setup-script" $LIGHTDM_CONF; then
      echo "display-setup-script=$XSET_FILE" >> $LIGHTDM_CONF
    fi
  fi
else
  rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE" "$GDM_POLICY_FILE" "$GDM_POLICY_LOCK_FILE" $XSET_FILE
  if [ -f $LIGHTDM_CONF ]; then
    sed --in-place "/display-setup-script/d" $LIGHTDM_CONF
  fi
fi

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
