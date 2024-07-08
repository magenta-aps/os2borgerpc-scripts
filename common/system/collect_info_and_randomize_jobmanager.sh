#!/usr/bin/env bash

set -x

CHECKIN_SCRIPT="/usr/share/os2borgerpc/bin/check-in.sh"
CRON_PATH="/etc/cron.d/os2borgerpc-jobmanager"
CONF="/etc/os2borgerpc/os2borgerpc.conf"

# Upgrade client version if the client is older than 2.x.x
CLIENT_VERSION_MAJOR="$(pip list | grep os2borgerpc | cut --delimiter " " --fields 2- | cut --delimiter "." --fields 1)"
if [ "$CLIENT_VERSION_MAJOR" -ne 2 ]; then
  pip install --upgrade os2borgerpc-client
fi

# Block gnome-remote-desktop on 22.04
if lsb_release -d | grep --quiet 22; then
  DCONF_FILE="/etc/dconf/db/os2borgerpc.d/00-remote-desktop"
  LOCK_FILE="/etc/dconf/db/os2borgerpc.d/locks/00-remote-desktop"

  mkdir --parents "$(dirname $DCONF_FILE)" "$(dirname $LOCK_FILE)"

  cat << EOF > "/etc/dconf/profile/user"
user-db:user
system-db:os2borgerpc
EOF

  cat << EOF > $DCONF_FILE
[org/gnome/desktop/remote-desktop/rdp]
enable=false
view-only=true
[org/gnome/desktop/remote-desktop/vnc]
enable=false
view-only=true
EOF

  cat << EOF > $LOCK_FILE
/org/gnome/desktop/remote-desktop/rdp/enable
/org/gnome/desktop/remote-desktop/vnc/enable
/org/gnome/desktop/remote-desktop/rdp/view-only
/org/gnome/desktop/remote-desktop/vnc/view-only
EOF

  dconf update
fi

# Generate a pseudo-random number between 0 and 59
DELAY_IN_SECONDS=$((RANDOM%60))

# Make sure the folder for the check-in script exists
mkdir --parents "$(dirname "$CHECKIN_SCRIPT")"

cat <<EOF > "$CHECKIN_SCRIPT"
#!/usr/bin/env sh

sleep $DELAY_IN_SECONDS

/usr/local/bin/jobmanager
EOF

chmod 700 "$CHECKIN_SCRIPT"

sed --in-place "s/local\/bin\/jobmanager/share\/os2borgerpc\/bin\/check-in.sh/" $CRON_PATH

# Computers installed from image 3.1.1 still check in at 5,10,15,etc.
# Make sure that such computers are also randomized on minutes
# shellcheck disable=SC2063  # It's a literal *, not a glob
if grep -q "*/5" $CRON_PATH; then
  INTERVAL=5
  RANDOM_NUMBER=$((RANDOM%INTERVAL+0))
  CRON_COMMAND="$RANDOM_NUMBER,"
  while [ $((RANDOM_NUMBER+INTERVAL)) -lt 60 ]
  do
    RANDOM_NUMBER=$((RANDOM_NUMBER+INTERVAL))
    if [ $((RANDOM_NUMBER+INTERVAL)) -ge 60 ]
    then
      CRON_COMMAND="$CRON_COMMAND$RANDOM_NUMBER * * * * root $CHECKIN_SCRIPT"
    else
      CRON_COMMAND="$CRON_COMMAND$RANDOM_NUMBER,"
    fi
  done
  cat <<EOF > "$CRON_PATH"
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
$CRON_COMMAND
EOF
fi

# Send info on PC Model, Manufacturer, CPUS and RAM

if ! grep --quiet "pc_model" $CONF; then
  PC_MODEL=$(dmidecode --type system | grep Product | cut --delimiter : --fields 2)
  [ -z "$PC_MODEL" ] && PC_MODEL="Identification failed"
  set_os2borgerpc_config pc_model "$PC_MODEL"
fi

if ! grep --quiet "pc_manufacturer" $CONF; then
  PC_MANUFACTURER=$(dmidecode --type system | grep Manufacturer | cut --delimiter : --fields 2)
  [ -z "$PC_MANUFACTURER" ] && PC_MANUFACTURER="Identification failed"
  set_os2borgerpc_config pc_manufacturer "$PC_MANUFACTURER"
fi

if ! grep --quiet "pc_cpus" $CONF; then
  # xargs is there to remove the leading space
  CPUS_BASE_INFO="$(dmidecode -t processor | grep Version | cut --delimiter : --fields 2 | xargs)"
  CPU_CORES="$(grep ^"core id" /proc/cpuinfo | sort -u | wc -l)"
  CPUS="$CPUS_BASE_INFO - $CPU_CORES physical cores"
  [ -z "$CPUS" ] && CPUS="Identification failed"
  set_os2borgerpc_config pc_cpus "$CPUS"
fi

if ! grep --quiet "pc_ram" $CONF; then
  RAM="$(LANG=c lsmem | grep "Total online" | cut --delimiter : --fields 2 | xargs)"
  [ -z "$RAM" ] && RAM="Identification failed"
  set_os2borgerpc_config pc_ram "$RAM"
fi

os2borgerpc_push_config_keys pc_model pc_manufacturer pc_cpus pc_ram
