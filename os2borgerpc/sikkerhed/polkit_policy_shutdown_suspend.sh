#!/usr/bin/env bash

#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    polkit_policy_shutdown.sh [ENFORCE]
#%
#% DESCRIPTION
#%    This script installs a mandatory PolicyKit policy that either prevents
#%    the "user" or "lightdm" users from suspending the system or
#%    prevents the "user" or "lightdm" users from suspending, restarting or shutting down
#%    the system.
#%
#%    It takes two optional parameters: whether to prevent suspending the system
#%    and whether to also prevent restart/shutdown.
#%    1. Use a boolean to decide whether or not to prevent the "user" from
#%       suspending the system. A checked box prevents suspend and an
#%       unchecked box allows it
#%    2. Use a boolean to decide whether or not to also prevent the "user" from
#%       restarting/shutting down the system. A checked box prevents
#%       restart/shutdown and an unchecked box allows it.
#%       Has no effect if input 1 is unchecked
#%
#================================================================
#- IMPLEMENTATION
#-    version         polkit_policy_shutdown.sh (magenta.dk) 1.0.0
#-    author          Alexander Faithfull
#-    modified by     Andreas Poulsen
#-    copyright       Copyright 2019, 2020 Magenta ApS
#-    license         GNU General Public License
#-    email           af@magenta.dk
#-
#================================================================
#  HISTORY
#     2019/09/25 : af : dconf_policy_shutdown.sh created
#     2020/01/27 : af : This script created based on dconf_policy_shutdown.sh
#     2022/11/01 : ap : This script modified to always disable hibernating/sleeping
#     2022/12/12 : ap : This script modified to allow separately
#                       disabling restart/shutdown or hibernating/sleeping
#
#================================================================
# END_OF_HEADER
#================================================================

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

DISABLE_SUSPEND=$1
DISABLE_POWEROFF_RESTART=$2

POLICY="/etc/polkit-1/rules.d/10-os2borgerpc-no-user-shutdown.rules"
POLICY_LEGACY="/etc/polkit-1/localauthority/90-mandatory.d/10-os2borgerpc-no-user-shutdown.pkla"
RELEASE=$(lsb_release --release --short)

mkdir --parents "$(dirname "$POLICY")" "$(dirname "$POLICY_LEGACY")"

if [ "$DISABLE_SUSPEND" = "False" ]; then
  rm --force "$POLICY" "$POLICY_LEGACY"
elif [ "$DISABLE_SUSPEND" = "True" ] && [ "$DISABLE_POWEROFF_RESTART" = "False" ]; then
  ACTIONS_22_04='org.freedesktop.login1.hibernate*;org.freedesktop.login1.suspend*;org.freedesktop.login1.lock-sessions'
  ACTIONS_24_04='["org.freedesktop.login1.hibernate", "org.freedesktop.login1.suspend", "org.freedesktop.login1.lock-sessions"]'
else
  ACTIONS_22_04='org.freedesktop.login1.hibernate*;org.freedesktop.login1.power-off*;org.freedesktop.login1.reboot*;org.freedesktop.login1.suspend*;org.freedesktop.login1.lock-sessions;org.freedesktop.login1.set-reboot*'
  ACTIONS_24_04='["org.freedesktop.login1.hibernate", "org.freedesktop.login1.power-off", "org.freedesktop.login1.reboot", "org.freedesktop.login1.suspend", "org.freedesktop.login1.lock-sessions", "org.freedesktop.login1.set-reboot"]'
fi

if [ "$DISABLE_SUSPEND" = "True" ]; then

  if [ "$RELEASE" = "22.04" ] || [ "$RELEASE" = "20.04" ]; then  # 20.04 and 22.04 support
  cat > "$POLICY_LEGACY" <<END
[Restrict system shutdown]
Identity=unix-user:user;unix-user:lightdm
Action=$ACTIONS_22_04
ResultAny=no
ResultActive=no
ResultInactive=no
END
  else  # 24.04 support
cat > "$POLICY" <<END
polkit.addRule(function(action, subject) {
    var users = ["user", "gdm", "lightdm"]
    var actions = $ACTIONS_24_04

    if (users.indexOf(subject.user) >= 0) {
      for (var i = 0; i < actions.length; i++) {
        if (action.id.includes(actions[i])) return polkit.Result.NO
      }
    }
    return polkit.Result.YES
})
END

  rm --force $POLICY_LEGACY
  fi
 fi

# Polkit successfully updates its rules when the files are changed in 24.04.
# For 22.04 and earlier it should do that too, but err on the side of caution:
if [ "$RELEASE" = "20.04" ] || [ "$RELEASE" = "22.04" ]; then
  systemctl restart polkit.service polkitd.service || true  # NOTE: polkitd does not exist on 22.04 or later
fi
