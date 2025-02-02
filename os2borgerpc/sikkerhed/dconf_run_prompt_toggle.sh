#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

set -x

ACTIVATE=$1

# Change these three to set a different policy to another value
POLICY_PATH="org/gnome/desktop/wm/keybindings"
POLICY="panel-run-dialog"
POLICY_VALUE_NO_BIND="@as []"
# This is the value it has when setting it back to Alt-F2, but from tests
# it seems sufficient to delete the policy file:
#POLICY_VALUE_BIND="['<Alt>F2']"

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/05-run-prompt"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/05-run-prompt"

if [ "$ACTIVATE" = "True" ]; then
	cat > "$POLICY_FILE" <<-END
		[$POLICY_PATH]
		$POLICY=$POLICY_VALUE_NO_BIND
	END
	# Tell the system that the values of the dconf keys we've just set can no
	# longer be overridden by the user
	cat > "$POLICY_LOCK_FILE" <<-END
		/$POLICY_PATH/$POLICY
	END
else
	rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"
fi

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
