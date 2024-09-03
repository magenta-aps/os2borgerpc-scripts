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
