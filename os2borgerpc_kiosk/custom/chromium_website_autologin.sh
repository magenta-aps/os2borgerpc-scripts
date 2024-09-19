#! /usr/bin/env sh

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a a regular OS2borgerPC machine."
  exit 1
fi

ACTIVATE="$1"
USERNAME="$2"
PASSWORD="$3"
REMEMBER_LOGIN="$4"
BROWSER_START_LOAD_DELAY_SECONDS="$5"

export DEBIAN_FRONTEND=noninteractive
AUTO_LOGIN_SCRIPT="/usr/share/os2borgerpc/bin/website_autologin.sh"
START_CHROMIUM_SCRIPT="/usr/share/os2borgerpc/bin/start_chromium.sh"

if [ "$ACTIVATE" = "True" ]; then

  apt-get update
  apt-get install --assume-yes xdotool

  cat << EOF > $AUTO_LOGIN_SCRIPT
#! /usr/bin/env sh

REMEMBER_LOGIN="$REMEMBER_LOGIN"

# Give the browser and page some time to load
sleep $BROWSER_START_LOAD_DELAY_SECONDS

# Login to website - can't handle JS interactions
# Adjust this based on the structure of the form
xdotool type --clearmodifiers --delay 100 "${USERNAME}	${PASSWORD}"

[ \$REMEMBER_LOGIN = "True" ] && xdotool key Tab space

xdotool key Return
EOF

chmod a+x $AUTO_LOGIN_SCRIPT

  # Idempotency check
  if ! grep --quiet  "$AUTO_LOGIN_SCRIPT" $START_CHROMIUM_SCRIPT; then
    sed --in-place "/KIOSK=/a $AUTO_LOGIN_SCRIPT &" $START_CHROMIUM_SCRIPT
  fi

else
  # Leaving xdotool installed
  sed --in-place "\@$AUTO_LOGIN_SCRIPT@d" $START_CHROMIUM_SCRIPT
  rm --force $AUTO_LOGIN_SCRIPT
fi

