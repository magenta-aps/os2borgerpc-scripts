#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    kiosk_lts_upgrade_in_place_to_24_step_4.sh
#
# DESCRIPTION
#    Step four of the upgrade from 22.04 to 24.04.
#    Designed for Kiosk machines

set -ex

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a regular OS2borgerPC device."
  exit 1
fi

PREVIOUS_STEP_DONE="/etc/os2borgerpc/third_24_upgrade_step_done"
if [ ! -f "$PREVIOUS_STEP_DONE" ]; then
  echo "24.04 opgradering - Kiosk Opgradering til Ubuntu 24.04 trin 3 has not been run."
  exit 1
fi

# Make double sure that the crontab has been emptied
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
if [ -f "$TMP_ROOTCRON" ]; then
  crontab -r || true
fi

# Remove the old client and the remainder of the old version of python
NEW_CLIENT="/root/.local/share/pipx/venvs/os2borgerpc-client/lib/python3.12/site-packages/os2borgerpc/client/jobmanager.py"
if [ -f $NEW_CLIENT ]; then
  rm -rf /usr/local/lib/python3.10/
  apt-get --assume-yes remove --purge python3.10-minimal || true
fi

# Remove any dependencies of the old version of python that are no longer used
apt-get --assume-yes autoremove

# Set danish timezone and language
timedatectl set-timezone Europe/Copenhagen
dpkg-reconfigure -f noninteractive tzdata
sed --in-place 's/# \(da_DK.UTF-8 UTF-8\)/\1/'  /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales
update-locale LANG=da_DK.UTF-8

# Update the time accordingly
export DEBIAN_FRONTEND=noninteractive
apt-get install --assume-yes ntpdate
# It's not a big deal if the time sync fails, which it sometimes does for no apparent reason
ntpdate pool.ntp.org || true

# Setup the new autologin approach if they are not already using it
AUTOLOGIN_SCRIPT="/usr/share/os2borgerpc/bin/autologin.sh"
if [ ! -f "$AUTOLOGIN_SCRIPT" ]; then
  CUSER="chrome"
  AUTOLOGIN_COUNTER="/etc/os2borgerpc/login_counter.txt"
  COUNTER_RESET_SERVICE="/etc/systemd/system/reset_login_counter.service"
  REBOOT_SCRIPT="/usr/share/os2borgerpc/bin/chromium_error_reboot.sh"
  PROFILE="/home/chrome/.profile"
  MAXIMUM_CONSECUTIVE_AUTOLOGINS=3

  if ! grep --quiet -- 'exit' $PROFILE; then # Ensure idempotency
    # This first line cleans up after previous versions of the script
    sed --in-place --expression "/startx/d" --expression "/for i in/d" --expression "/sleep/d" \
      --expression "/done/d" --expression "/chromium_error_reboot/d" $PROFILE
    cat << EOF >> $PROFILE
startx
exit
EOF
  fi

  # Note: The empty ExecStart is not insignificant!
  # By default the value is appended, so the empty line changes it to an override
  cat << EOF > /etc/systemd/system/getty@tty1.service.d/override.conf
[Service]
ExecStart=
ExecStart=-/sbin/agetty --noissue --login-program $AUTOLOGIN_SCRIPT --autologin $USER %I $TERM
Type=idle
EOF

  # Create the autologin script

  # Ensure that the folder exists
  mkdir --parents "$(dirname $AUTOLOGIN_SCRIPT)"

  cat << EOF > $AUTOLOGIN_SCRIPT
#!/usr/bin/env bash
COUNTER=\$(cat $AUTOLOGIN_COUNTER)
COUNTER=\$((COUNTER+1))
echo \$COUNTER > $AUTOLOGIN_COUNTER
if [ \$COUNTER -le $MAXIMUM_CONSECUTIVE_AUTOLOGINS ]; then
  if [ \$COUNTER -gt 1 ]; then
    # Sleep before autologin attempts other than the first
    sleep 10
  fi
  # Autologin as $CUSER
  /bin/login -f $CUSER
else
  # Regular login prompt
  /bin/login
fi
EOF

  # To maintain the functionality of the error reboot script
  if [ -f "$REBOOT_SCRIPT" ]; then
    sed --in-place --expression "\@else@{ n; n; s@/bin/login@$REBOOT_SCRIPT@ }" \
        --expression "s/Regular login prompt/Reboot the computer/" $AUTOLOGIN_SCRIPT
  fi

  chmod 700 $AUTOLOGIN_SCRIPT

  # Create login counter
  echo "0" > $AUTOLOGIN_COUNTER

  cat << EOF > $COUNTER_RESET_SERVICE
[Unit]
Description=Reset the autologin counter when the computer starts

[Service]
Type=oneshot
ExecStart=sh -c 'echo "0" > $AUTOLOGIN_COUNTER'

[Install]
WantedBy=multi-user.target
EOF

  systemctl enable --now "$(basename $COUNTER_RESET_SERVICE)"
fi

# Reset jobmanager timeout to default value
set_os2borgerpc_config job_timeout 900

os2borgerpc_push_config_keys job_timeout

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
if [ -f "$TMP_ROOTCRON" ]; then
  crontab $TMP_ROOTCRON
  rm -f $TMP_ROOTCRON
fi
if [ -f /etc/os2borgerpc/plan.json ]; then
  systemctl enable --now os2borgerpc-set_on-off_schedule.service
fi

rm --force $PREVIOUS_STEP_DONE
