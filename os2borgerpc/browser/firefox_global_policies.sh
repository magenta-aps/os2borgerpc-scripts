#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason, Marcus Funch
#
# Policy-script developed by Magenta ApS for Aarhus Municipality.
# 
# Learn more about Firefox "Policy Names" here:
# https://github.com/mozilla/policy-templates/blob/master/README.md
# 
# It's only possible to have ONE policy-file. In the future this script
# should have to evolve to be a more dynamic solution if we want to be
# able to, e.g. use the same script across machines and handpick which
# Policies we want to use. Until then there will be set some default static
# Policies with OS2borgerPC in mind.

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script has not been designed to run on a Kiosk-machine. Exiting."
  exit 1
fi

STARTPAGE="$1"
ADDITIONAL_PAGES="$2"
DEFAULT_SEARCH_ENGINE="$3"

POLICY_DIR="/etc/firefox/policies"
POLICY_FILE="$POLICY_DIR/policies.json"
GLOBAL_MIME_FILE="/etc/xdg/mimeapps.list"

PDF_TYPE_1=application/pdf
PDF_TYPE_2=application/x-bzpdf
PDF_TYPE_3=application/x-gzpdf
PDF_TYPE_4=application/x-lzpdf
PDF_TYPE_5=application/x-xzpdf
PROGRAMS_TO_REMOVE="libreoffice-draw.desktop;com.google.Chrome.desktop;google-chrome.desktop;microsoft-edge.desktop;chromium_chromium.desktop;firefox_firefox.desktop"

if [ -z "$STARTPAGE" ]; then
  echo "WARNING: Missing <URL> argument. Unable to set Firefox startpage."
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

# Determine locale
LOCALE=$(grep LANG= /etc/default/locale | cut --delimiter '=' --fields 2 | tr --delete '"' | cut --delimiter '_' --fields 1)

# Set search engine
if [ "$DEFAULT_SEARCH_ENGINE" = "google" ]; then
SEARCH_ENGINE_TEXT="$(cat << EOF
    "SearchEngines": {
      "PreventInstalls": true
    }
EOF
)"
elif [ "$DEFAULT_SEARCH_ENGINE" = "ecosia" ]; then
SEARCH_ENGINE_TEXT="$(cat << EOF
    "SearchEngines": {
      "Add": [
        {
          "Name": "Ecosia",
          "URLTemplate": "https://www.ecosia.org/search?q={searchTerms}&addon=firefoxgpo",
          "Method": "GET",
          "IconURL": "https://cdn-static.ecosia.org/static/icons/favicon.ico",
          "Description": "Ecosia search engine",
          "SuggestURLTemplate": "https://ac.ecosia.org/autocomplete?q={searchTerms}&type=list"
        }
      ],
      "Default": "Ecosia",
      "PreventInstalls": true
    }
EOF
)"
# Would've added an IconURL here as well - not important though - but it seems the path to their favicon changes
elif [ "$DEFAULT_SEARCH_ENGINE" = "qwant" ]; then
SEARCH_ENGINE_TEXT="$(cat << EOF
    "SearchEngines": {
      "Add": [
        {
          "Name": "Qwant",
          "URLTemplate": "https://www.qwant.com/?q={searchTerms}",
          "Method": "GET",
          "Description": "Qwant search engine",
          "SuggestURLTemplate": "https://api.qwant.com/api/suggest/?q={searchTerms}&type=web"
        }
      ],
      "Default": "Qwant",
      "PreventInstalls": true
    }
EOF
)"
elif [ "$DEFAULT_SEARCH_ENGINE" = "startpage" ]; then
SEARCH_ENGINE_TEXT="$(cat << EOF
    "SearchEngines": {
      "Add": [
        {
          "Name": "StartPage",
          "URLTemplate": "https://www.startpage.com/sp/search?query={searchTerms}&cat=web&pl=chrome",
          "Method": "GET",
          "IconURL": "https://cdn.startpage.com/sp/cdn/favicons/favicon-96x96.png",
          "Description": "StartPage search engine",
          "SuggestURLTemplate": "https://www.startpage.com/osuggestions?q=%s"
        }
      ],
      "Default": "StartPage",
      "PreventInstalls": true
    }
EOF
)"
elif [ "$DEFAULT_SEARCH_ENGINE" = "duckduckgo" ]; then
SEARCH_ENGINE_TEXT="$(cat << EOF
    "SearchEngines": {
      "Add": [
        {
          "Name": "DuckDuckGo",
          "URLTemplate": "https://duckduckgo.com/?q={searchTerms}",
          "Method": "GET",
          "IconURL": "https://duckduckgo.com/favicon.ico",
          "Description": "DuckDuckGo search engine",
          "SuggestURLTemplate": "https://duckduckgo.com/ac/?q={searchTerms}&type=list"
        }
      ],
      "Default": "DuckDuckGo",
      "PreventInstalls": true
    }
EOF
)"
else
  printf "%s\n" "Invalid default search engine selected. Exiting." && exit 1
fi


# Disabling the builtin PDF viewer since Princh report it results in bad colours when printing
# The rest is generally to lock down settings, disable data persistence and remove ads/sponsorships
# TODO: Add some additional background for why we have each policy
cat << EOF > "$POLICY_FILE"
{
  "policies": {
    "BlockAboutAddons": true,
    "BlockAboutConfig": true,
    "BlockAboutProfiles": true,
    "BlockAboutSupport": true,
    "DisableBuiltinPDFViewer": true,
    "DisableDeveloperTools": true,
    "DisableFirefoxAccounts": true,
    "DisableFormHistory": true,
    "DisableProfileImport": true,
    "EnableTrackingProtection": {
      "Cryptomining": true,
      "Fingerprinting": true,
      "Locked": true,
      "Value": true
    },
    "FirefoxHome": {
      "SponsoredTopSites": false,
      "Pocket": false,
      "SponsoredPocket": false,
      "Locked": true
    },
    "Handlers": {
      "extensions": {
         "pdf": {
            "action": "useSystemDefault",
            "ask": false
        }
      }
    },
    "Homepage": {
      "URL": "$STARTPAGE",
      "Locked": true,
      $PAGES_STRING
      "StartPage": "homepage"
    },
    "InstallAddonsPermission": {
      "Default": false
    },
    "OfferToSaveLogins": false,
    "OfferToSaveLoginsDefault": false,
    "OverrideFirstRunPage": "",
    "OverridePostUpdatePage": "",
    "PasswordManagerEnabled": false,
    "Preferences": {
      "datareporting.policy.dataSubmissionPolicyBypassNotification": true
    },
    "RequestedLocales": "$LOCALE",
    "SanitizeOnShutdown": true,
$SEARCH_ENGINE_TEXT
  }
}
EOF

# Make sure the mime file exists
if [ ! -f $GLOBAL_MIME_FILE ]; then
	cat <<- EOF > $GLOBAL_MIME_FILE
[Default Applications]
EOF
fi

# Force Okular OR Evince to be the only PDF applications listed for the PDF filetypes,
# to prevent programs like firefox from making gnome-desktop-portal prompt for which application to open the PDF with, when Firefox is set to use the external PDF reader
# The contents of this section is shared by the firefox and okular scripts
if ! grep "Removed Associations" $GLOBAL_MIME_FILE; then
	cat <<- EOF >> "$GLOBAL_MIME_FILE"
		[Removed Associations]
	EOF
fi
# Delete everything after "[Removed Associations] for idempotency
sed --in-place "/Removed Associations/q" $GLOBAL_MIME_FILE

cat <<- EOF >> "$GLOBAL_MIME_FILE"
$PDF_TYPE_1=$PROGRAMS_TO_REMOVE
$PDF_TYPE_2=$PROGRAMS_TO_REMOVE
$PDF_TYPE_3=$PROGRAMS_TO_REMOVE
$PDF_TYPE_4=$PROGRAMS_TO_REMOVE
$PDF_TYPE_5=$PROGRAMS_TO_REMOVE
EOF

# Remove the policy from its former standard location if present.
rm --force /usr/lib/firefox/distribution/policies.json
