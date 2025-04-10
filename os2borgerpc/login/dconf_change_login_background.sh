#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2019 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Alexander Faithful, Heini Leander Ovason, Marcus Funch
#
# Sets new background image on login-screen

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

ACTIVATE=$1
IMAGE_UPLOAD=$2

IMAGE_NAME=$(basename "$IMAGE_UPLOAD")
POLICY_VALUE="/usr/share/backgrounds/$IMAGE_NAME"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"

# Set the policy for the gdm user, if using GDM, or the os2borgerpc user, if using LightDM
if grep --quiet gdm3 $DEFAULT_DM_FILE; then
  DCONF_USER_DIR="gdm.d"
  POLICY_PATH="com/ubuntu/login-screen"
  POLICY="background-picture-uri"
else
  DCONF_USER_DIR="os2borgerpc.d"
  POLICY_PATH="com/canonical/unity-greeter"
  POLICY="background"
fi

POLICY_FILE="/etc/dconf/db/$DCONF_USER_DIR/06-login-screen-bg-image"
POLICY_LOCK_FILE="/etc/dconf/db/$DCONF_USER_DIR/locks/06-login-screen-bg-image"

if [ "$ACTIVATE" = "True" ]; then

  mv "$IMAGE_UPLOAD" "/usr/share/backgrounds/"

	if grep --quiet gdm3 $DEFAULT_DM_FILE; then
		cat > "$POLICY_FILE" <<-EOF
			[$POLICY_PATH]
			background-size='contain'
			$POLICY='file://$POLICY_VALUE'
		EOF
  else
		cat > "$POLICY_FILE" <<-EOF
			[$POLICY_PATH]
			draw-user-backgrounds=false
			$POLICY='$POLICY_VALUE'
		EOF
  fi

  # Tell the system that the values of the dconf keys we've just set can no
  # longer be overridden by the user
	cat > "$POLICY_LOCK_FILE" <<-EOF
		/$POLICY_PATH/$POLICY
	EOF
else
  # Leaving the image file there
  rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"
fi

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
