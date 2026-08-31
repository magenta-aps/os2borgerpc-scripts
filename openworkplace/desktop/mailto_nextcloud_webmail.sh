#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# Script arguments
INSTALL=$1
NEXTCLOUD_SERVER=$2

export DEBIAN_FRONTEND=noninteractive

DESCRIPTION=$(cat <<EOF
Konfigurer global 'mailto:' handler for Nextcloud Webmail

Skriptet sætter en desktop entry for Nextcloud Webmail, og konfigurerer den globale 'mailto:'
handler til at bruge denne Nextcloud Webmail desktop entry.

Alle applikationer, der respekterer systemes MIME konfigurationer, vil åbne 'mailto:' URI's med den
valgte Nextcloud Webmail server.

Scriptet virker i en desktop environment som GNOME, KDE, eller XFCE.

Nogle gange er browsere manuel konfigureret anderledes, og det vil kræve lidt tilpasning for at få
det korrekte 'mailto:' til at virke. Fremgangsmåden ved Firefox og Chrome eller Chromium er følgende:

Firefox:
 - åben 'about:config'
 - sæt 'network.protocol-handler.expose.mailto' -> 'false' (Firefox vil nu bruge system default)
 - klik et 'mailto:' link og vælg 'Nextcloud Webmail' som handler

Chrome/Chromium:
 - åben 'chrome://settings/handlers'
 - sæt 'Allow sites to ask to become default handlers for protocols' -> 'enabled'
 - klik et 'mailto:' link og vælg 'Nextcloud Webmail' som handler

Parametre:

  INSTALL = True | False
  NEXTCLOUD_SERVER = <your.nextcloud.server>

Eksempel:

  mailto_nextcloud_webmail.sh True <your.nextcloud.server>
  mailto_nextcloud_webmail.sh False

EOF
           )

APPLICATIONS_DESKTOP_DIR='/usr/share/applications'
NEXTCLOUD_WEBMAIL_DESKTOP='nextcloud-webmail.desktop'
NEXTCLOUD_WEBMAIL_DESKTOP_PATH="${APPLICATIONS_DESKTOP_DIR}/${NEXTCLOUD_WEBMAIL_DESKTOP}"
NEXTCLOUD_WEBMAIL_URI="https://$NEXTCLOUD_SERVER/apps/mail/compose?uri=%u"

NEXTCLOUD_WEBMAIL_DESKTOP_INI=$(cat <<EOF
[Desktop Entry]
Name=Nextcloud Webmail
Categories=Network;Email;
GenericName=Mail Client
Exec=xdg-open "${NEXTCLOUD_WEBMAIL_URI}"
Terminal=false
Type=Application
MimeType=x-scheme-handler/mailto;
NoDisplay=true
EOF
)

SYS_MIMEAPPS_LIST='/etc/xdg/mimeapps.list'
SYS_MIMEINFO_CACHE='/usr/share/applications/mimeinfo.cache'

add_mimeapps_list_mailto_nextcloud() {
    mkdir -p "$(dirname "$SYS_MIMEAPPS_LIST")"

    # no mimeapps list file exists
    if [ ! -f "$SYS_MIMEAPPS_LIST" ]; then
        printf '[Default Applications]\nx-scheme-handler/mailto=%s\n' "$NEXTCLOUD_WEBMAIL_DESKTOP" \
               > "$SYS_MIMEAPPS_LIST"

    # mimeapps list file exists and has 'Default applications' section
    elif grep -q '^\[Default Applications\]' "$SYS_MIMEAPPS_LIST"; then
        if grep -q '^x-scheme-handler/mailto=' "$SYS_MIMEAPPS_LIST"; then
            sed -i "s|^x-scheme-handler/mailto=.*|x-scheme-handler/mailto=$NEXTCLOUD_WEBMAIL_DESKTOP|" \
                "$SYS_MIMEAPPS_LIST"
        else
            sed -i "/^\[Default Applications\]/a x-scheme-handler/mailto=$NEXTCLOUD_WEBMAIL_DESKTOP" \
                "$SYS_MIMEAPPS_LIST"
        fi

    # mimeapps list file exists and has no 'Default applications' section
    else
        printf '\n[Default Applications]\nx-scheme-handler/mailto=%s\n' "$NEXTCLOUD_WEBMAIL_DESKTOP" \
               >> "$SYS_MIMEAPPS_LIST"
    fi
}

remove_mimeapps_list_mailto_nextcloud() {
    [ -f "$SYS_MIMEAPPS_LIST" ] || return 0

    # no mailto entry pointing to nextcloud
    if ! grep -q "^x-scheme-handler/mailto=${NEXTCLOUD_WEBMAIL_DESKTOP}\$" "$SYS_MIMEAPPS_LIST"; then
        return 0
    fi

    # delete line with mailto entry pointing to nextcloud
    # this does _not_ re-install the possible mailto handler that did exist before this script was used
    # to add nextcloud web mail
    sed -i '/^x-scheme-handler\/mailto=/d' "$SYS_MIMEAPPS_LIST"

    # drop [Default Applications] header if empty block
    section_body=$(sed -n '/^\[Default Applications\]/,/^\[/{ /^\[Default Applications\]/d; /^\[/d; p }' \
                          "$SYS_MIMEAPPS_LIST")
    if [ -z "$(printf '%s' "$section_body" | tr -d '[:space:]')" ]; then
        sed -i '/^\[Default Applications\]/d' "$SYS_MIMEAPPS_LIST"
    fi

    # drop entire file if empty now
    if [ -z "$(tr -d '[:space:]' < "$SYS_MIMEAPPS_LIST")" ]; then
        rm -f "$SYS_MIMEAPPS_LIST"
    fi
}


if [ "$INSTALL" = "True" ]; then

    # Create a desktop entry for Nextcloud Webmail
    echo "${NEXTCLOUD_WEBMAIL_DESKTOP_INI}" > "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"

    if ! grep -q "${NEXTCLOUD_WEBMAIL_URI}" "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}" ;
    then
        echo "ERROR: expected to find ${NEXTCLOUD_WEBMAIL_URI} in ${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"
        exit 1
    fi

    update-desktop-database "${APPLICATIONS_DESKTOP_DIR}"

    if ! grep -q "${NEXTCLOUD_WEBMAIL_DESKTOP}" "${SYS_MIMEINFO_CACHE}"; then
        echo "ERROR: expected to find ${NEXTCLOUD_WEBMAIL_DESKTOP} in ${SYS_MIMEINFO_CACHE}"
        exit 1
    fi

    # Set Nextcloud Webmail as the global default mailto handler for all users
    add_mimeapps_list_mailto_nextcloud

    if ! grep -q "${NEXTCLOUD_WEBMAIL_DESKTOP}" "${SYS_MIMEAPPS_LIST}"; then
        echo "ERROR: expected to find ${NEXTCLOUD_WEBMAIL_DESKTOP} in ${SYS_MIMEAPPS_LIST}"
        exit 1
    fi

    exit 0

elif [ "$INSTALL" = "False" ]; then
    # Remove desktop entry for Nextcloud Webmail
    rm -f "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"

    update-desktop-database "${APPLICATIONS_DESKTOP_DIR}"

    if grep -q "${NEXTCLOUD_WEBMAIL_DESKTOP}" "${SYS_MIMEINFO_CACHE}"; then
        echo "ERROR: expected NOT to find ${NEXTCLOUD_WEBMAIL_DESKTOP} in ${SYS_MIMEINFO_CACHE}"
        exit 1
    fi

    # Remove Nextcloud Webmail as the global default mailto handler
    remove_mimeapps_list_mailto_nextcloud

    if grep -q "${NEXTCLOUD_WEBMAIL_DESKTOP}" "${SYS_MIMEAPPS_LIST}"; then
        echo "ERROR: expected NOT to find ${NEXTCLOUD_WEBMAIL_DESKTOP} in ${SYS_MIMEAPPS_LIST}"
        exit 1
    fi

    exit 0

else
    echo "ERROR: unexpected parameter '$INSTALL'=${INSTALL}"
    echo ""
    echo "${DESCRIPTION}"
    exit 1
fi
