#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    general_lts_upgrade_in_place_to_24_step_1.sh
#
# DESCRIPTION
#    Step one of the upgrade from 22.04 to 24.04.

set -ex

# Fail on machines that are still running Ubuntu 20.04
if lsb_release -d | grep --quiet 20; then
  echo "This computer is running Ubuntu 20.04. Upgrade to Ubuntu 22.04 before running this script."
  exit 1
fi

# Fail on machines that have already run this script or later upgrade scripts
if [ -f "/etc/os2borgerpc/first_24_upgrade_step_done" ]; then
  echo "This script has already been run on this computer."
  echo "Please run 24.04 opgradering - Opgradering til Ubuntu 24.04 trin 2 to continue the upgrade."
  exit 1
elif [ -f "/etc/os2borgerpc/second_24_upgrade_step_done" ]; then
  echo "This computer has already completed the first two steps in the upgrade."
  if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
    echo "Please run 24.04 opgradering - Opgradering til Ubuntu 24.04 trin 3 to continue the upgrade."
  else
    echo "Please run 24.04 opgradering - Kiosk Opgradering til Ubuntu 24.04 trin 3 to continue the upgrade."
  fi
  exit 1
elif [ -f "/etc/os2borgerpc/third_24_upgrade_step_done" ]; then
  echo "This computer has already completed the first three steps in the upgrade."
  if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
    echo "Please run 24.04 opgradering - Opgradering til Ubuntu 24.04 trin 4 to complete the upgrade."
  else
    echo "Please run 24.04 opgradering - Kiosk Opgradering til Ubuntu 24.04 trin 4 to complete the upgrade."
  fi
  exit 1
fi

# Fail on machines that have already been upgraded
if ! lsb_release -d | grep --quiet 22; then
  echo "This computer is not using Ubuntu 22.04."
  echo "This script is only meant for upgrading from Ubuntu 22.04 to Ubuntu 24.04."
  exit 1
fi

if ! grep --quiet "GRUB_DEFAULT=0" /etc/default/grub; then
  echo "This computer has been locked to a previous kernel."
  echo "To minimize the risk of problems, please deactivate 'System - GRUB: Skift kerneversion'"
  echo "then reboot the computer before running this script again."
  echo "If necessary, 'System - GRUB: Skift kerneversion' can be reactivated after completing the upgrade."
  exit 1
fi

# Update client
pip install --upgrade os2borgerpc-client

# Patch jobmanager and config to avoid early stoppage.
set_os2borgerpc_config job_timeout 80000
os2borgerpc_push_config_keys job_timeout

# Clear crontab and disable potential wake plans to prevent shutdown while the upgrade is running
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
USERCRON="/etc/os2borgerpc/usercron"
if [ ! -f "$TMP_ROOTCRON" ]; then
  crontab -l > $TMP_ROOTCRON || true
  crontab -r || true
fi
if [ -f "$USERCRON" ]; then
  crontab -u user -r || true
fi
if [ -f /etc/os2borgerpc/plan.json ]; then
  systemctl disable os2borgerpc-set_on-off_schedule.service
fi

touch /etc/os2borgerpc/first_24_upgrade_step_done
