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
