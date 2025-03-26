#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

# Change these three to set a different policy to another value
POLICY_PATH="org/gnome/desktop/session"
POLICY="idle-delay"
POLICY_VALUE="uint32 0"

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/00-$POLICY"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/00-$POLICY"

ACTIVATE=$1

if [ "$ACTIVATE" = 'True' ]; then

	cat > "$POLICY_FILE" <<-END
		[$POLICY_PATH]
		$POLICY=$POLICY_VALUE
	END

	# Tell the system that the values of the dconf keys we've just set can no
	# longer be overridden by the user
	cat > "$POLICY_LOCK_FILE" <<-END
		/$POLICY_PATH/$POLICY
	END
else
	rm -f "$POLICY_FILE" "$POLICY_LOCK_FILE"
fi

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
