#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    os2borgerpc_lts_upgrade_in_place_to_24_step_4.sh
#
# DESCRIPTION
#    Step four of the upgrade from 22.04 to 24.04.
#    Designed for regular OS2borgerPC machines

set -ex

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a Kiosk device."
  exit 1
fi

PREVIOUS_STEP_DONE="/etc/os2borgerpc/third_24_upgrade_step_done"
if [ ! -f "$PREVIOUS_STEP_DONE" ]; then
  echo "24.04 opgradering - Opgradering til Ubuntu 24.04 trin 3 has not been run."
  exit 1
fi

REBOOT_REQUIRED_FILE="/var/run/reboot-required"
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
  echo "The computer must be rebooted before running this script. Reboot the computer and run this script again."
  exit 1
fi

# Make double sure that the crontab has been emptied
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
if [ -f "$TMP_ROOTCRON" ]; then
  crontab -r || true
fi

# Reset jobmanager timeout to default value
set_os2borgerpc_config job_timeout 900

os2borgerpc_push_config_keys job_timeout

# Change the release-upgrade prompt back to never.
# This should prevent future popups regarding updates
release_upgrades_file=/etc/update-manager/release-upgrades
sed -i "s/Prompt=.*/Prompt=never/" $release_upgrades_file

# Remove the old client
NEW_CLIENT="/root/.local/share/pipx/venvs/os2borgerpc-client/lib/python3.12/site-packages/os2borgerpc/client/jobmanager.py"
if [ -f $NEW_CLIENT ]; then
  rm -rf /usr/local/lib/python3.10/
fi

# Convert polkit files to the new format
# Shutdown polkit policy
SHUTDOWN_POLKIT_POLICY_LEGACY="/etc/polkit-1/localauthority/90-mandatory.d/10-os2borgerpc-no-user-shutdown.pkla"
SHUTDOWN_POLKIT_POLICY="/etc/polkit-1/rules.d/10-os2borgerpc-no-user-shutdown.rules"
if [ -f "$SHUTDOWN_POLKIT_POLICY_LEGACY" ]; then
  if grep --quiet "power-off" $SHUTDOWN_POLKIT_POLICY_LEGACY; then
    ACTIONS='["org.freedesktop.login1.hibernate", "org.freedesktop.login1.power-off", "org.freedesktop.login1.reboot", "org.freedesktop.login1.suspend", "org.freedesktop.login1.lock-sessions", "org.freedesktop.login1.set-reboot"]'
  else
    ACTIONS='["org.freedesktop.login1.hibernate", "org.freedesktop.login1.suspend", "org.freedesktop.login1.lock-sessions"]'
  fi
  cat << EOF > $SHUTDOWN_POLKIT_POLICY
polkit.addRule(function(action, subject) {
    var users = ["user", "gdm", "lightdm"]
    var actions = $ACTIONS

    if (users.indexOf(subject.user) >= 0) {
      for (var i = 0; i < actions.length; i++) {
        if (action.id.includes(actions[i])) return polkit.Result.NO
      }
    }
})
EOF
  rm --force $SHUTDOWN_POLKIT_POLICY_LEGACY
fi

# Network manager polkit policy
NETWORK_MANAGER_CONF=/etc/NetworkManager/NetworkManager.conf
NM_POLKIT_OLD=/var/lib/polkit-1/localauthority/50-local.d/networkmanager.pkla
NM_POLKIT_LEGACY=/etc/polkit-1/localauthority/50-local.d/networkmanager.pkla
NM_POLKIT=/etc/polkit-1/rules.d/10-networkmanager.rules

if [ -f $NM_POLKIT_OLD ]; then
  NM_POLKIT_LEGACY=$NM_POLKIT_OLD
fi

if [ -f "$NM_POLKIT_LEGACY" ]; then
  if grep --quiet "auth-polkit=false" $NETWORK_MANAGER_CONF; then
    USERS='["gdm", "lightdm"]'
  else
    USERS='["user", "gdm", "lightdm"]'
  fi
  cat << EOF > $NM_POLKIT
polkit.addRule(function(action, subject) {
    var users = $USERS
    var actions = ["org.freedesktop.NetworkManager.network-control", "org.freedesktop.NetworkManager.enable-disable-network", "org.freedesktop.NetworkManager.enable-disable-wifi"]

    if (users.indexOf(subject.user) >= 0) {
      for (var i = 0; i < actions.length; i++) {
        if (action.id.includes(actions[i])) return polkit.Result.NO
      }
    }
})
EOF
  rm --force $NM_POLKIT_LEGACY
fi

# Network printer search polkit policy
PRINTER_POLKIT_POLICY_LEGACY="/etc/polkit-1/localauthority/10-vendor.d/01-os2borgerpc-deny-user-managing-units.pkla"
PRINTER_POLKIT_POLICY="/etc/polkit-1/rules.d/01-os2borgerpc-deny-user-managing-units.rules"
if [ -f $PRINTER_POLKIT_POLICY_LEGACY ]; then
  cat << EOF > $PRINTER_POLKIT_POLICY
polkit.addRule(function(action, subject) {
    var users = ["user"]
    var actions = ["org.freedesktop.systemd1.manage-units"]

    if (users.indexOf(subject.user) >= 0) {
      for (var i = 0; i < actions.length; i++) {
        if (action.id.includes(actions[i])) return polkit.Result.NO
      }
    }
})
EOF
  rm --force $PRINTER_POLKIT_POLICY_LEGACY
fi

# Use the dconf policy for enabling numlock for user
OLD_NUMLOCK_SCRIPT="/etc/xdg/autostart/os2borgerpc-numlock.desktop"
NUMLOCK_POLICY="/etc/dconf/db/os2borgerpc.d/00-numlock"
NUMLOCK_POLICY_LOCK="/etc/dconf/db/os2borgerpc.d/locks/00-numlock"
if [ -f "$OLD_NUMLOCK_SCRIPT" ]; then
  cat << EOF > $NUMLOCK_POLICY
[org/gnome/desktop/peripherals/keyboard]
numlock-state=true
EOF

  cat << EOF > $NUMLOCK_POLICY_LOCK
/org/gnome/desktop/peripherals/keyboard/numlock-state
EOF

  rm --force $OLD_NUMLOCK_SCRIPT
fi

# Fix /etc/xdg/mimeapps.list
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"
OLD_DEFAULTS_LIST="/usr/share/applications/defaults.list"
PDF_TYPE_1=application/pdf
PDF_TYPE_2=application/x-bzpdf
PDF_TYPE_3=application/x-gzpdf
PDF_TYPE_4=application/x-lzpdf
PDF_TYPE_5=application/x-xzpdf
if apt list --installed | grep --quiet okular; then
  DESKTOP_FILE=okularApplication_kimgio.desktop
else
  DESKTOP_FILE=org.gnome.Evince.desktop
fi
if [ -f "$OLD_DEFAULTS_LIST" ]; then
  if ! grep --quiet "text/html" $OLD_DEFAULTS_LIST; then
    DEFAULT_BROWSER="firefox_firefox.desktop"
  else
    DEFAULT_BROWSER=$(grep "text/html" $OLD_DEFAULTS_LIST | cut --delimiter "=" --fields 2 | cut --delimiter "." --fields 1)
    DEFAULT_BROWSER="$DEFAULT_BROWSER.desktop"
  fi
else
  DEFAULT_BROWSER="firefox_firefox.desktop"
fi
if [ ! -f "$GLOBAL_MIME_FILE" ]; then
  cat << EOF > $GLOBAL_MIME_FILE
[Default Applications]
EOF
fi
if ! grep --quiet "text/html" $GLOBAL_MIME_FILE; then
  sed --in-place "/Default Applications/a \
application/xhtml+xml=$DEFAULT_BROWSER\n\
text/html=$DEFAULT_BROWSER\n\
x-scheme-handler/http=$DEFAULT_BROWSER\n\
x-scheme-handler/https=$DEFAULT_BROWSER" $GLOBAL_MIME_FILE
fi
if ! grep --quiet "$DESKTOP_FILE" $GLOBAL_MIME_FILE; then
  sed --in-place "/Default Applications/a \
$PDF_TYPE_1=$DESKTOP_FILE\n\
$PDF_TYPE_2=$DESKTOP_FILE\n\
$PDF_TYPE_3=$DESKTOP_FILE\n\
$PDF_TYPE_4=$DESKTOP_FILE\n\
$PDF_TYPE_5=$DESKTOP_FILE" "$GLOBAL_MIME_FILE"
fi
if ! grep --quiet "Removed Associations" $GLOBAL_MIME_FILE; then
  PROGRAMS_TO_REMOVE="libreoffice-draw.desktop;com.google.Chrome.desktop;google-chrome.desktop;microsoft-edge.desktop;chromium_chromium.desktop;firefox_firefox.desktop"
  cat << EOF >> $GLOBAL_MIME_FILE
[Removed Associations]
$PDF_TYPE_1=$PROGRAMS_TO_REMOVE
$PDF_TYPE_2=$PROGRAMS_TO_REMOVE
$PDF_TYPE_3=$PROGRAMS_TO_REMOVE
$PDF_TYPE_4=$PROGRAMS_TO_REMOVE
$PDF_TYPE_5=$PROGRAMS_TO_REMOVE
EOF
fi

# Ensure that the inactivity/suspend script continues working and clean up unnecessary logs
INACTIVITY_SCRIPT="/usr/share/os2borgerpc/bin/inactive_logout.sh"
LIGHTDM_SUSPEND_SCRIPT="/etc/lightdm/greeter-setup-scripts/suspend_after_time.sh"
if [ -f "$INACTIVITY_SCRIPT" ] && grep --quiet "XAUTHORITY" $INACTIVITY_SCRIPT; then
  OUR_USER="user"
  TIMES=$(grep -- "-ge" $INACTIVITY_SCRIPT)
  # shellcheck disable=SC2086 # We need word splitting for this to work correctly
  LOGOUT_TIME_MS=$(echo $TIMES | cut --delimiter " " --fields 5)
  # shellcheck disable=SC2086 # We need word splitting for this to work correctly
  DIALOG_TIME_MS=$(echo $TIMES | cut --delimiter " " --fields 12)
  DIALOG_TEXT=$(grep "zenity --warning" $INACTIVITY_SCRIPT | cut --delimiter '"' --fields 2)
  BUTTON_TEXT=$(grep "zenity --warning" $INACTIVITY_SCRIPT | cut --delimiter '"' --fields 4)
  if grep --quiet "systemctl suspend" $INACTIVITY_SCRIPT; then
    cat << EOF > $INACTIVITY_SCRIPT
#!/usr/bin/env bash

# If the user is inactive for too long, a dialog will appear, warning the user that the session will end.
# If the user do not touch the mouse or press any keyboard key the session will end.
# Only have one dialog at a time, so remove preexisting ones.
# Create a new message every time, in case someone didn't close it but
# just put e.g. a browser in front, to ensure they or someone else gets a
# new warning when/if inactivity is reached again

export DISPLAY=\$(who | grep -w '$OUR_USER' | sed -rn 's/.*\((:[0-9]*)\).*/\1/p')

# Used by xprintidle
su $OUR_USER -c "xhost si:localuser:root"

# If the pc has a time plan, don't use systemctl suspend, but instead rtcwake -m mem,
# which is functionally the same and allows the machine to wake up in time to be shut down
# by the time plan

if [ \$(xprintidle) -ge $LOGOUT_TIME_MS ]; then
  pkill -KILL -u $OUR_USER
  # If the pc has a time plan, don't use systemctl suspend, but instead rtcwake -m mem,
  # which is functionally the same and allows the machine to wake up in time to be shut down
  # by the time plan
  re="([0-9]+) ([0-9]+) ([0-9]+) ([0-9]+) .+"
  if [[ \$(crontab -l | grep scheduled_off) =~ \$re ]]; then
    MINUTES=\${BASH_REMATCH[1]}
    HOURS=\${BASH_REMATCH[2]}
    DAY=\${BASH_REMATCH[3]}
    MONTH=\${BASH_REMATCH[4]}
    YEAR=\$(date +%Y)
    # wake up 1 minute before shut down
    MINM1P60=\$(( \$(( MINUTES - 1)) + 60))
    # Rounding minutes
    MINS=\$(( MINM1P60 % 60))
    HRCORR=\$(( 1 - \$(( MINM1P60 / 60))))
    HRS=\$(( HOURS - HRCORR))
    HRS=\$(( \$(( HRS + 24)) % 24))
    # When run from the crontab, rtcwake needs the full path for some reason or it won't work
    /usr/sbin/rtcwake -m mem --date "\$YEAR-\$MONTH-\$DAY \$HRS:\$MINS"
  else
    systemctl suspend
  fi
  exit 0
fi
# if idle time is past the dialog time: show the dialog
if [ \$(xprintidle) -ge $DIALOG_TIME_MS ]; then
  # Do spare the poor lives of potential other zenity windows.
  PID_ZENITY="\$(pgrep --full 'Inaktivitet')"
  if [ -n "\$PID_ZENITY" ]; then
    kill \$PID_ZENITY
  fi
  # We use the --title to match against above
  runuser -u $OUR_USER -- zenity --warning --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT" --no-wrap --title "Inaktivitet"
fi
EOF
  else
    cat << EOF > $INACTIVITY_SCRIPT
#!/usr/bin/env sh

# If the user is inactive for too long, a dialog will appear, warning the user that the session will end.
# If the user do not touch the mouse or press any keyboard key the session will end.
# Only have one dialog at a time, so remove preexisting ones.
# Create a new message every time, in case someone didn't close it but
# just put e.g. a browser in front, to ensure they or someone else gets a
# new warning when/if inactivity is reached again

export DISPLAY=\$(who | grep -w '$OUR_USER' | sed -rn 's/.*\((:[0-9]*)\).*/\1/p')

# Used by xprintidle
su $OUR_USER -c "xhost si:localuser:root"

if [ \$(xprintidle) -ge $LOGOUT_TIME_MS ]; then
	pkill -KILL -u $OUR_USER
	exit 0
fi
# if idle time is past the dialog time: show the dialog
if [ \$(xprintidle) -ge $DIALOG_TIME_MS ]; then
  # Do spare the poor lives of potential other zenity windows.
  PID_ZENITY="\$(pgrep --full 'Inaktivitet')"
  if [ -n "\$PID_ZENITY" ]; then
    kill \$PID_ZENITY
  fi
  # We use the --title to match against above
  runuser -u $OUR_USER -- zenity --warning --text="$DIALOG_TEXT" --ok-label="$BUTTON_TEXT" --no-wrap --title "Inaktivitet"
fi
EOF
  fi
  chmod 700 $INACTIVITY_SCRIPT
fi
if [ -f "$LIGHTDM_SUSPEND_SCRIPT" ]; then
  sed --in-place "/LOG/d" $LIGHTDM_SUSPEND_SCRIPT
fi
rm --force "/usr/share/os2borgerpc/bin/inactive_logout.log" "/etc/lightdm/scriptlogs/suspend_after_time.log"

# Add new Firefox policies and remove the download directory policy
FIREFOX_POLICIES="/etc/firefox/policies/policies.json"
if ! grep "DisableBuiltinPDFViewer" $FIREFOX_POLICIES; then
  sed --in-place '/BlockAboutAddons/a \
    "DisableBuiltinPDFViewer": true,\
    "FirefoxHome": {\
      "SponsoredTopSites": false,\
      "Pocket": false,\
      "SponsoredPocket": false,\
      "Locked": true\
    },\
    "Handlers": {\
      "extensions": {\
        "pdf": {\
          "action": "useSystemDefault",\
          "ask": false\
        }\
      }\
    },' $FIREFOX_POLICIES
fi
sed --in-place --expression "/DownloadDirectory/d" \
  --expression "/PromptForDownloadLocation/d" $FIREFOX_POLICIES

# Ensure that our login integrations continue working correctly
CICERO_PAM_FILE="/usr/lib/x86_64-linux-gnu/security/os2borgerpc-cicero-pam-module.py"
CICERO_INTERFACE="/usr/share/os2borgerpc/bin/cicero_interface_python3.py"
CICERO_LOGOUT="/etc/lightdm/greeter-setup-scripts/cicero_logout.py"
SWE_PAM_FILE="/usr/lib/x86_64-linux-gnu/security/os2borgerpc-custom-login-pam-module.py"
SWE_LOGOUT="/etc/lightdm/greeter-setup-scripts/general_citizen_logout.py"
QURIA_INTERFACE="/usr/share/os2borgerpc/bin/quria_login_interface_python3.py"
SMS_INTERFACE="/usr/share/os2borgerpc/bin/sms_login_interface_python3.py"
SMS_FINALIZE="/usr/share/os2borgerpc/bin/sms_login_finalize_python3.py"
if [ -f "$CICERO_PAM_FILE" ]; then
  sed --in-place --expression "s/\[1:-1\]$/\[1:-1\].replace('\"','').replace(\"'\",\"\")/" \
  --expression "s/logout-timer@/logout-timer-24-04@/" $CICERO_PAM_FILE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $CICERO_INTERFACE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $CICERO_LOGOUT
fi
if [ -f "$QURIA_INTERFACE" ]; then
  sed --in-place --expression "s/\[1:-1\]$/\[1:-1\].replace('\"','').replace(\"'\",\"\")/" \
  --expression 's/str(log_id\[:-1\])/log_id\[:-1\].decode("ascii")/' \
  --expression "s/logout-timer@/logout-timer-24-04@/" $SWE_PAM_FILE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $QURIA_INTERFACE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $SWE_LOGOUT
fi
if [ -f "$SMS_INTERFACE" ]; then
  if ! grep --quiet "decode" $SWE_PAM_FILE; then
    sed --in-place --expression "s/\[1:-1\]$/\[1:-1\].replace('\"','').replace(\"'\",\"\")/" \
    --expression "s/logout-timer@/logout-timer-24-04@/" \
    --expression '/if log_id/i \            log_id = log_id.decode("ascii")' $SWE_PAM_FILE
  fi
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $SMS_INTERFACE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $SMS_FINALIZE
  sed --in-place "s@/usr/bin/env python3@/root/.local/share/pipx/venvs/os2borgerpc-client/bin/python3@" $SWE_LOGOUT
fi

# Ensure that the visual countdown timer continues working
LOGOUT_TIMER_CONF_OLD="/usr/share/gnome-shell/extensions/logout-timer@os2borgerpc.magenta.dk/config.json"
LOGOUT_TIMER_CONF_NEW="/usr/share/gnome-shell/extensions/logout-timer-24-04@os2borgerpc.magenta.dk/config.json"
NEW_EXTENSION_NAME="logout-timer-24-04@os2borgerpc.magenta.dk"
LOGOUT_TIMER_ACTUAL="/usr/share/os2borgerpc/bin/logout_timer_actual.sh"
LOGOUT_TIMER_SESSION_CLEANUP_FILE="/usr/share/os2borgerpc/bin/user-cleanup-logout-timer.bash"
EXTENSION_ACTIVATION_DESKTOP_FILE="/home/.skjult/.config/autostart/logout-timer-user.desktop"
EXTENSION_GIT_URL="https://github.com/magenta-aps/os2borgerpc-gnome-extensions/archive/refs/heads/main.zip"
if [ -f "$LOGOUT_TIMER_CONF_OLD" ]; then
  HEADS_UP_MESSAGE=$(grep "headsUpMessage" $LOGOUT_TIMER_CONF_OLD | cut --delimiter '"' --fields 4)
  PRE_TIMER_TEXT=$(grep "preTimerText" $LOGOUT_TIMER_CONF_OLD | cut --delimiter '"' --fields 4)
  MINUTES_TO_LOGOUT=$(grep "timeMinutes" $LOGOUT_TIMER_CONF_OLD | cut --delimiter " " --fields 4 | cut --delimiter "," --fields 1)
  HEADS_UP_SECONDS_LEFT=$(grep "headsUpSecondsLeft" $LOGOUT_TIMER_CONF_OLD | cut --delimiter " " --fields 4 | cut --delimiter "," --fields 1)
  rm --recursive "$(dirname $LOGOUT_TIMER_CONF_OLD)"
  sed --in-place "s/logout-timer@/logout-timer-24-04@/" $LOGOUT_TIMER_ACTUAL
  sed --in-place "s/logout-timer@/logout-timer-24-04@/" $LOGOUT_TIMER_SESSION_CLEANUP_FILE
  sed --in-place "s/logout-timer@/logout-timer-24-04@/" $EXTENSION_ACTIVATION_DESKTOP_FILE
  wget $EXTENSION_GIT_URL
  unzip main.zip
  os2borgerpc-gnome-extensions-main/install.sh whatever $NEW_EXTENSION_NAME true true true
  rm --recursive main.zip os2borgerpc-gnome-extensions-main
  cat << EOF > $LOGOUT_TIMER_CONF_NEW
{
  "timeMinutes": $MINUTES_TO_LOGOUT,
  "preTimerText": "$PRE_TIMER_TEXT",
  "headsUpSecondsLeft": $HEADS_UP_SECONDS_LEFT,
  "headsUpMessage": "$HEADS_UP_MESSAGE"
}
EOF
fi

# Ensure that get_daily_login_count continues working correctly, if they are using it
LOGIN_COUNT_SCRIPT="/usr/local/lib/os2borgerpc/count_daily_logins.sh"
if [ -f "$LOGIN_COUNT_SCRIPT" ] && ! grep --quiet "lsb_release" $LOGIN_COUNT_SCRIPT; then
  sed --in-place "s/LAST_ON_DATE=.*/LAST_ON_DATE=\$LAST_ON_DATE_FULL/" $LOGIN_COUNT_SCRIPT
  sed --in-place "s/New session c/New session c\\\?/" $LOGIN_COUNT_SCRIPT
  LOGIN_COUNT_SERVICE="/etc/systemd/system/os2borgerpc-count_daily_logins.service"
  systemctl disable "$(basename $LOGIN_COUNT_SERVICE)" || true
  rm --force $LOGIN_COUNT_SERVICE
fi

# Hide some irrelevant shortcuts for user
PTH="/home/.skjult/.local/share/applications"
mkdir --parents $PTH
PROGRAMS="update-manager.desktop usb-creator-gtk.desktop software-properties-drivers.desktop software-properties-gtk.desktop software-properties-livepatch.desktop org.gnome.font-viewer.desktop org.gnome.SystemMonitor.desktop gnome-system-monitor-kde.desktop org.gnome.PowerStats.desktop org.gnome.DiskUtility.desktop nm-connection-editor.desktop org.gnome.seahorse.Application.desktop org.gnome.Logs.desktop org.gnome.baobab.desktop gnome-session-properties.desktop gnome-language-selector.desktop app-center.desktop snap-store_snap-store.desktop firmware-updater_firmware-updater-app.desktop firmware-updater_firmware-updater.desktop snap-store_ubuntu-software.desktop system-config-printer.desktop"
for program in $PROGRAMS; do
  touch "$PTH/$program"
  chmod a-rwx "$PTH/$program"
done

# Run security-related scripts

# Block gnome-remote-desktop
# This is already blocked in newer 22.04 images or upgraded 20.04 machines,
# but we repeat it here just for good measure
GRD_POLICY_FILE="/etc/dconf/db/os2borgerpc.d/00-remote-desktop"
GRD_POLICY_LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/00-remote-desktop"
cat << EOF > $GRD_POLICY_FILE
[org/gnome/desktop/remote-desktop/rdp]
enable=false
view-only=true
[org/gnome/desktop/remote-desktop/vnc]
enable=false
view-only=true
EOF
cat << EOF > $GRD_POLICY_LOCK_FILE
/org/gnome/desktop/remote-desktop/rdp/enable
/org/gnome/desktop/remote-desktop/vnc/enable
/org/gnome/desktop/remote-desktop/rdp/view-only
/org/gnome/desktop/remote-desktop/vnc/view-only
EOF

# Ensure that user-cleanup will work correctly if they swap to gdm
USER_CLEANUP="/usr/share/os2borgerpc/bin/user-cleanup.bash"
if ! grep --quiet "PATH=" $USER_CLEANUP; then
  sed --in-place "2 a \
# We need to set PATH to ensure that the script works correctly when run by gdm\n\
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/snap/bin\n" $USER_CLEANUP
fi

# Also ensure that user-cleanup resets airplane mode
if ! grep --quiet "nmcli" $USER_CLEANUP; then
  cat << EOF >> $USER_CLEANUP

# Disable airplane mode unless they're using ethernet
if ! nmcli c show --active | grep --quiet "ethernet" && nmcli r wifi | grep --quiet "disabled"; then
  nmcli r all on
fi
EOF
fi

# Remove thunderbird, don't stop if it fails (it might not be installed)
snap remove thunderbird || true

# Install the snap version of pinta if they previously had the apt version.
# The apt version is not available in 24.04.
if [ -f "/etc/os2borgerpc/pinta_installed" ]; then
  snap install pinta
  # Fix potential pinta shortcuts
  sed --in-place "s/pinta/pinta_pinta/" /etc/dconf/db/os2borgerpc.d/02-launcher-favorites
  export "$(grep LANG= /etc/default/locale | tr -d '"')"
  runuser -u user xdg-user-dirs-update
  DESKTOP=$(basename "$(runuser -u user xdg-user-dir DESKTOP)")
  SHADOW_DESKTOP="/home/.skjult/$DESKTOP"
  OLD_DESKTOP_FILE="$SHADOW_DESKTOP/pinta.desktop"
  if [ -f "$OLD_DESKTOP_FILE" ]; then
    OLD_LOCAL_COPY="/home/.skjult/.local/share/applications/pinta.desktop"
    NEW_LOCAL_COPY="/home/.skjult/.local/share/applications/pinta_pinta.desktop"
    rm --force "$OLD_LOCAL_COPY" "$OLD_DESKTOP_FILE"
    mkdir --parents "$(dirname $NEW_LOCAL_COPY)"
    cp "/var/lib/snapd/desktop/applications/pinta_pinta.desktop" $NEW_LOCAL_COPY
    ln --symbolic --force "$NEW_LOCAL_COPY" "$SHADOW_DESKTOP/pinta_pinta.desktop"
  fi
  rm /etc/os2borgerpc/pinta_installed
fi

dconf update

# Fix dpkg settings
cat << EOF > /etc/apt/apt.conf.d/local
Dpkg::Options {
   "--force-confdef";
   "--force-confold";
};
Dpkg::Lock {Timeout "300";};
Dpkg {ConfigurePending "true";};
Apt:Get {Fix-Broken "true";};
EOF

# Restore crontab and reenable potential wake plans
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
USERCRON=/etc/os2borgerpc/usercron
if [ -f "$TMP_ROOTCRON" ]; then
  crontab $TMP_ROOTCRON
  crontab -u user $USERCRON
  rm -f $TMP_ROOTCRON
fi
if [ -f /etc/os2borgerpc/plan.json ]; then
  systemctl enable --now os2borgerpc-set_on-off_schedule.service
fi

rm --force $PREVIOUS_STEP_DONE
