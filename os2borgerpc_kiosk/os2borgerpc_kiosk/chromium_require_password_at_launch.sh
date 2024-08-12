#! /usr/bin/env sh

# The only Chromium-specific logic is that we overwrite the startpage set in start_chromium.sh - otherwise it could work with any browser.

ACTIVATE="$1"
PASSWORD="$2"

# NOTE: Ideally this would not be owned by chrome and in a dir not owned by chrome, but Chromium seems unable to read it from e.g. /usr/share/os2borgerpc,
# getting file not found - and without ownership of the file, it gets "permission denied".
# Maybe it's a snap/apparmor issue?
#LOCAL_LOGIN_HTML_FILE="/usr/share/os2borgerpc/login.html"
LOCAL_LOGIN_HTML_FILE="/home/chrome/login.html"
START_CHROMIUM_SCRIPT="/usr/share/os2borgerpc/bin/start_chromium.sh"

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en regulær OS2borgerPC-maskine."
  exit 1
fi

set -x

replace_start_page() {
    sed --in-place "s@IURL=.*@IURL=\"$1\"@" $START_CHROMIUM_SCRIPT
}

# If START_CHROMIUM_SCRIPT points to the login.html file we obtain the real startpage from the login.html file.
# This is so that this script picks up the new start page, if chromium autostart has been rerun before rerunning this.
if grep --quiet "$LOCAL_LOGIN_HTML_FILE" $START_CHROMIUM_SCRIPT; then
  REAL_STARTPAGE=$(grep "const redirect_url" $LOCAL_LOGIN_HTML_FILE | cut --delimiter '"' --fields 2)
else
  REAL_STARTPAGE=$(grep "^IURL" $START_CHROMIUM_SCRIPT | cut --delimiter '"' --fields 2)
fi

if [ "$ACTIVATE" = "True" ]; then

  TARGET_START_PAGE="file://$LOCAL_LOGIN_HTML_FILE"
  replace_start_page $TARGET_START_PAGE

  cat << EOF > $LOCAL_LOGIN_HTML_FILE
<!DOCTYPE html>
<html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width">
    <title>Login</title>
    <style>
      * {
        text-align: center;
      }
      main {
        margin-top: 100px;
      }
    </style>
  </head>
  <body>
    <main>
      <h1>Login</h1>
      <p id="error-text-container" style="color: red;"></p>
      <input id="pw" type="password" autofocus placeholder="Indtast kodeord" />
    </main>
  </body>
  <script>
    const password = "$PASSWORD"
    const redirect_url = "$REAL_STARTPAGE"

    const error_text_container = document.getElementById("error-text-container")

    function check_pw(e) {
      let typed_pw = e.target.value
      if (typed_pw == password) {
        window.location.replace(redirect_url)
      }
      else {
        error_text_container.innerHTML = "Forkert kodeord. Prøv et andet."
      }
    }
    const el = document.getElementById("pw")
    el.addEventListener("keyup", check_pw)
  </script>
</html>
EOF

  chown chrome:chrome $LOCAL_LOGIN_HTML_FILE
else
  rm --force $LOCAL_LOGIN_HTML_FILE
  replace_start_page "$REAL_STARTPAGE"
fi
