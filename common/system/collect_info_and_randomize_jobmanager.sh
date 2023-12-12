#!/usr/bin/env bash

set -x

CHECKIN_SCRIPT="/usr/share/os2borgerpc/bin/check-in.sh"
CRON_PATH="/etc/cron.d/os2borgerpc-jobmanager"
CONF="/etc/os2borgerpc/os2borgerpc.conf"

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

if ! grep --quiet "pc_model" $CONF; then
  PC_MODEL=$(dmidecode --type system | grep Product | cut --delimiter : --fields 2)
  [ -z "$PC_MODEL" ] && PC_MODEL="Identification failed"
  set_os2borgerpc_config pc_model "$PC_MODEL"
fi

if ! grep --quiet "manufacturer" $CONF; then
  MANUFACTURER=$(dmidecode --type system | grep Manufacturer | cut --delimiter : --fields 2)
  [ -z "$MANUFACTURER" ] && MANUFACTURER="Identification failed"
  set_os2borgerpc_config manufacturer "$MANUFACTURER"
fi

os2borgerpc_push_config_keys pc_model manufacturer
