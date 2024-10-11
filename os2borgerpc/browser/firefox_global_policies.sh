#!/usr/bin/env bash

: << 'COMMENT'
Policy-script developed by Magenta ApS for Aarhus Municipal.

Learn more about Firefox "Policy Names" here:
https://github.com/mozilla/policy-templates/blob/master/README.md

It's only possible to have ONE policy-file. In the future this script
should have to evolve to be a more dynamic solution if we want to be
able to, e.g. use the same script across machines and handpick which
Policies we want to use. Until then there will be set some default static
Policies with OS2borgerPC in mind.

Author: Heini L. Ovason
COMMENT

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be used on a kiosk machine."
  exit 1
fi

STARTPAGE="$1"
ADDITIONAL_PAGES="$2"

POLICY_DIR="/etc/firefox/policies"
POLICY_FILE="$POLICY_DIR/policies.json"

if [ -z "$STARTPAGE" ]; then
  echo "WARNING: Missing <URL> argument. Not able to set Firefox startpage."
  exit 1
fi

mkdir --parents "$POLICY_DIR"

PAGES_STRING=""
if [ -n "$ADDITIONAL_PAGES" ]; then
  IFS='|' read -ra PAGES_ARRAY <<< "$ADDITIONAL_PAGES"

  PAGES_STRING="\"Additional\": [" # start array-string
  for PAGE in "${PAGES_ARRAY[@]}"; do
    PAGES_STRING+="\"$PAGE\","
  done
  PAGES_STRING=${PAGES_STRING::-1} # remove comma at end of list
  PAGES_STRING+="]," # finish array-string
fi

cat << EOF > "$POLICY_FILE"
{
  "policies": {
    "Homepage": {
      "URL": "$STARTPAGE",
      "Locked": true,
      $PAGES_STRING
      "StartPage": "homepage"
    },
    "DisableFirefoxAccounts": true,
    "InstallAddonsPermission": {
      "Default": false
    },
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "Preferences": {
      "datareporting.policy.dataSubmissionPolicyBypassNotification": true
    },
    "BlockAboutAddons": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "DownloadDirectory": "/home/user/Hentet",
    "PromptForDownloadLocation": false,
    "DisableFirefoxAccounts": true,
    "DisableFormHistory": true,
    "DisableProfileImport": true,
    "OfferToSaveLogins": false,
    "OfferToSaveLoginsDefault": false,
    "PasswordManagerEnabled": false,
    "SanitizeOnShutdown": {
      "Cache": true,
      "Cookies": true,
      "Downloads": false,
      "FormData": true,
      "History": true,
      "Sessions": true,
      "SiteSettings": true,
      "OfflineApps": true,
      "Locked": true
    },
    "SearchEngines": {
      "PreventInstalls": true
    },
    "EnableTrackingProtection": {
      "Value": true,
      "Locked": true,
      "Cryptomining": true,
      "Fingerprinting": true
    },
    "DisableDeveloperTools": true
  }
}
EOF

# Attempting to remove policy from former standard location.
rm --force /usr/lib/firefox/distribution/policies.json
