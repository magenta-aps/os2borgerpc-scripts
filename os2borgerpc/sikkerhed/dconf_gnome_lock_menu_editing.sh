#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

ACTIVATE=$1

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

POLICY_LOCK_FILE=/etc/dconf/db/os2borgerpc.d/locks/02-launcher-favorites

# Locks the menu so it can't be edited (adding/removing/moving items in the menu)
if [ "$ACTIVATE" = "True" ]; then
	cat <<- EOF > $POLICY_LOCK_FILE
		/org/gnome/shell/favorite-apps
	EOF
else
	rm $POLICY_LOCK_FILE
fi

dconf update
