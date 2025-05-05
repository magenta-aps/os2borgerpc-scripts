#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

WAYLAND_FORCE="$1"

DEFAULT_DM_FILE="/etc/X11/default-display-manager"
DISABLE_WAYLAND_FILE="/etc/lightdm/lightdm.conf.d/10-disable-wayland.conf"
DISABLE_XORG_FILE="/etc/lightdm/lightdm.conf.d/10-disable-xorg.conf"
LIGHTDM_CONF="/etc/lightdm/lightdm.conf"
GDM_CONF="/etc/gdm3/custom.conf"

if [ "$WAYLAND_FORCE" = "True" ]; then
  if grep --quiet gdm3 $DEFAULT_DM_FILE; then
    sed --in-place "s/WaylandEnable=false/WaylandEnable=true/" $GDM_CONF
  else
    rm --force $DISABLE_WAYLAND_FILE

  # Remove the option to launch Xorg from LightDM
    cat << EOF > $DISABLE_XORG_FILE
# No /usr/share/xsessions please
[LightDM]
sessions-directory=/usr/share/wayland-sessions:/usr/share/lightdm/sessions
EOF

    # Stop launching Xorg-specific display-setup-script
    if [ -f "/usr/share/os2borgerpc/bin/xset.sh" ]; then
      sed --in-place "\@/usr/share/os2borgerpc/bin/xset.sh@d" $LIGHTDM_CONF
    fi
  fi
else
  if grep --quiet gdm3 $DEFAULT_DM_FILE; then
    sed --in-place "s/WaylandEnable=true/WaylandEnable=false/" $GDM_CONF
  else
    rm --force $DISABLE_XORG_FILE

    # Remove the option to launch Wayland from LightDM
    cat << EOF > $DISABLE_WAYLAND_FILE
# No /usr/share/wayland-sessions please
[LightDM]
sessions-directory=/usr/share/xsessions:/usr/share/lightdm/sessions
EOF
  fi
fi
