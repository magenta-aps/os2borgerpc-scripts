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
Konfigurer global mailto handler for Nextcloud Webmail

Skriptet sætter en desktop entry for Nextcloud Webmail, og konfigurerer den globale mailto
handler til at bruge denne Nextcloud Webmail desctop entry.

Dette sørger for at alle applikationer der respekterer systemes MIME konfigurationer, vil åbne
mailto: URI's med den valgte Nextcloud Webmail server.

Burde virke i en desktop environment som GNOME, KDE, eller XFCE. Nogle gange er browsere konfigurert
specifik anderledes, og det vil kræve lidt tilpasning for at få den korrekte mailto: til at virke.

Firefox:
 - åben 'about:config'
 - sæt 'network.protocol-handler.expose.mailto' -> 'false' (Firefox vil nu bruge system default)
 - klik et mailto: link og vælg 'Nextcloud Webmail' som handler

Chrome/Chromium:
 - åben 'chrome://settings/handlers'
 - sæt 'Allow sites to ask to become default handlers for protocols' -> 'enabled'
 - klik et mailto: link og vælg 'Nextcloud Webmail' som handler

Parametre:

  INSTALL = True | False
  NEXTCLOUD_SERVER = <your.nextcloud.server>

Eksempel:

  mailto_nextcloud_webmail.sh True <your.nextcloud.server>
  mailto_nextcloud_webmail.sh False

Mere info:

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


if [ "$INSTALL" = "True" ]; then

    # Create a desktop entry for Nextcloud Webmail
    echo "${NEXTCLOUD_WEBMAIL_DESKTOP_INI}" > "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"
    update-desktop-database

    # Set Nextcloud Webmail as the default mailto handler
    xdg-mime default "${NEXTCLOUD_WEBMAIL_DESKTOP}" x-scheme-handler/mailto

    # check system default mailto handler
    CURRENT_MAILTO_HANDLER=$(xdg-mime query default x-scheme-handler/mailto)
    if [ "${CURRENT_MAILTO_HANDLER}" != "${NEXTCLOUD_WEBMAIL_DESKTOP}" ]  ;
    then
        echo "ERROR: Expected Xdg-mime default x-schema handler mailto: ${NEXTCLOUD_WEBMAIL_DESKTOP}"
        echo "       But got '${CURRENT_MAILTO_HANDLER}'"
        exit 1
    fi

    if ! grep -q "${NEXTCLOUD_WEBMAIL_URI}" "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}" ;
    then
        echo "ERROR: expected to find ${NEXTCLOUD_WEBMAIL_URI} in ${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"
        exit 1
    fi

    echo "Xdg-mime default x-schema handler mailto: is now '${CURRENT_MAILTO_HANDLER}'"
    exit 0

elif [ "$INSTALL" = "False" ]; then
    # Remove desktop entry for Nextcloud Webmail
    rm -f "${NEXTCLOUD_WEBMAIL_DESKTOP_PATH}"
    update-desktop-database

    # Remove Nextcloud Webmail as the default mailto handler
    # insert the first alternative we find
    MAILTO_DESKTOP_FILE="$(grep -rl mailto /usr/share/applications/*.desktop | sort | head -n 1)"
    DEFAULT_MAILTO="$(basename "$MAILTO_DESKTOP_FILE")"
    xdg-mime default "${DEFAULT_MAILTO}" x-scheme-handler/mailto

    # check system default mailto handler
    CURRENT_MAILTO_HANDLER=$(xdg-mime query default x-scheme-handler/mailto)

    if [ "${CURRENT_MAILTO_HANDLER}" = "${NEXTCLOUD_WEBMAIL_DESKTOP}" ] ;
    then
        echo "ERROR: expected different default mailto handler than ${NEXTCLOUD_WEBMAIL_DESKTOP}"
        exit 1
    fi
    echo "Xdg-mime default x-schema handler mailto: is now '${CURRENT_MAILTO_HANDLER}'"
    exit 0

else
    echo "ERROR: uventet parameter '$INSTALL'=${INSTALL}"
    echo ""
    echo "${DESCRIPTION}"
    exit 1
fi
