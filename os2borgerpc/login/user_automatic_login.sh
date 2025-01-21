#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2013 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch
#
#   Arguments - both booleans:
#     1. True will enable automatic login while an unchecked one will disable it.
#     2. If the first argument is True, this determines if OUR_USER is required to type in their password or not.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

LIGHTDM_CONFIG="/etc/lightdm/lightdm.conf"
OUR_USER="user"
DEFAULT_DM_FILE="/etc/X11/default-display-manager"
GDM_CONFIG="/etc/gdm3/custom.conf"
POST_SESSION_FILE="/etc/gdm3/PostSession/Default"
GDM_AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/gdm-automatic-login.sh"

ACTIVATE="$1"
REQUIRE_PASSWORD="$2"

adduser $OUR_USER nopasswdlogin

if [ "$ACTIVATE" = "False" ]; then
  if [ "$REQUIRE_PASSWORD" = "True" ]; then
    # Require password for User
    if id --name --groups $OUR_USER | grep --quiet --word-regexp nopasswdlogin; then
      # Remove the user from nopasswdlogin group
      deluser $OUR_USER nopasswdlogin
    fi
  fi
    # Disable automatic login
    sed --in-place "/autologin-user/d" $LIGHTDM_CONFIG
    sed --in-place "/AutomaticLogin/d" $GDM_CONFIG
    sed --in-place "\@$GDM_AUTOLOGIN_SCRIPT@d" $POST_SESSION_FILE
    rm --force $GDM_AUTOLOGIN_SCRIPT
else # Enable automatic login incl. not requiring password from user on manual login before the timeout
  if grep --quiet gdm3 $DEFAULT_DM_FILE; then
    # Idempotency check
    if ! grep --quiet -- "AutomaticLogin=$OUR_USER" $GDM_CONFIG; then
      cat << EOF > $GDM_AUTOLOGIN_SCRIPT
#!/usr/bin/env bash

sleep 10
if [ -z \$(users) ]; then
  systemctl restart gdm
fi
EOF

      chmod 700 $GDM_AUTOLOGIN_SCRIPT

      sed --in-place "/exit 0/i $GDM_AUTOLOGIN_SCRIPT &" $POST_SESSION_FILE
      sed --in-place "/daemon/a AutomaticLoginEnable=true\nAutomaticLogin=$OUR_USER" $GDM_CONFIG
    fi
  else
    # Idempotency check
    if ! grep --quiet -- "autologin-user=$OUR_USER" $LIGHTDM_CONFIG; then
			cat <<- EOF >> $LIGHTDM_CONFIG
				autologin-user-timeout=10
				autologin-user=$OUR_USER
			EOF
    fi
  fi
fi
