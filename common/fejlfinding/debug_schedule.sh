#!/usr/bin/env bash

set -x

printf "Check that the date and time on the computer makes sense\n"
date

printf "Check crontab for root\n"
crontab -l

printf "\nCheck crontab for user\n"
crontab -u user -l

printf "\nCheck the contents of /etc/os2borgerpc/plan.json\n"
cat "/etc/os2borgerpc/plan.json"

printf "\n\nCheck the contents of the schedule service file\n"
cat "/etc/systemd/system/os2borgerpc-set_on-off_schedule.service"

printf "\nCheck the contents of /usr/local/lib/os2borgerpc/set_on-off_schedule.py\n"
cat "/usr/local/lib/os2borgerpc/set_on-off_schedule.py"

printf "\nCheck the contents of /usr/local/lib/os2borgerpc/scheduled_off.sh\n"
cat "/usr/local/lib/os2borgerpc/scheduled_off.sh"

printf "\nCheck the status of the schedule service\n"
systemctl status os2borgerpc-set_on-off_schedule | cat

printf "\nCheck next planned wakeup\n"
rtcwake -m show

printf "\nCheck that rtcwake is in the expected location\n"
which rtcwake

printf "\nCheck rtcwake version\n"
rtcwake --version

printf "\nList supported suspend methods (shallow = standby (S1), deep = suspend to RAM (MEM, S3))\n"
printf "The current default suspend method is shown in [brackets]\n"
cat /sys/power/mem_sleep

printf "\nCheck systemd version\n"
systemctl --version

printf "\nCheck the contents of /etc/systemd/sleep.conf. It specifies the defaults, and if things aren't working this might be worth experimenting with changes.\n"
cat /etc/systemd/sleep.conf

printf "See last logins via wtmp:"
last -x | grep reboot | head --lines 100  # Alternately grep for shutdown to see when it's been off

printf "See current uptime, in case wtmp has been rotated"
uptime
