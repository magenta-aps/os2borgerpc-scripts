#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# DESCRIPTION
#    This script installs a policy that forcefully prevents
#    notifications from popping up.
#
#    It takes one optional parameter: whether or not to enforce this policy.
#    Use a boolean to decide whether or not to enforce this policy, a checked box
#    will enable the script, an unchecked box will remove it.

set -x

USERCRON="/etc/os2borgerpc/usercron"
POLICY_PATH="org/gnome/desktop/notifications"
POLICY="show-banners"
POLICY_VALUE="false"

POLICY_FILE="/etc/dconf/db/os2borgerpc.d/00-$POLICY"
POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/00-$POLICY"

ACTIVATE=$1

# Convert any old notify-send lines in usercron to zenity
if [ -f "$USERCRON" ]; then
  sed --in-place "s@XDG_RUNTIME_DIR=.*notify-send@DISPLAY=\$(who | grep -w 'user' | sed -rn 's/.*\\\((:[0-9]*)\\\).*/\\\1/p') /usr/bin/zenity --warning --text@" $USERCRON
  crontab -u "user" $USERCRON
fi

if [ "$ACTIVATE" = "True" ]; then
	cat > "$POLICY_FILE" <<- END
		[$POLICY_PATH]
		$POLICY=$POLICY_VALUE
	END
	# Tell the system that the values of the dconf keys we've just set can no
	# longer be overridden by the user
	cat > "$POLICY_LOCK_FILE" <<- END
		/$POLICY_PATH/$POLICY
	END
else
	rm --force "$POLICY_FILE" "$POLICY_LOCK_FILE"
fi

# Incorporate all of the text files we've just created into the system's dconf databases
dconf update
