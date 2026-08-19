#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# Script arguments
ACTION=$1
OLD_PASSPHRASE=$2
NEW_PASSPHRASE=$3


export DEBIAN_FRONTEND=noninteractive

DESCRIPTION=$(cat <<EOF
Opdater cryptsetup LUKS passphraser

Scriptet forudsætter at installationen er fortaget med en og nøjagtig en cryptosetup LUKS
partition af FSTYPE = crypto_LUKS og TYPE = part, for eksempel af formen

lsblk -o NAME,FSTYPE,TYPE

NAME                          FSTYPE      TYPE
nvme0n1                                   disk
├─nvme0n1p1                   vfat        part
├─nvme0n1p2                   ext4        part
└─nvme0n1p3                   crypto_LUKS part
  └─dm_crypt-0                LVM2_member crypt
    └─ubuntu--vg-ubuntu--lv   ext4        lvm


I dette tilfælde har vi block-device 'dev/nvme0n1p3' med en partition der indeholder et crypto_LUKS
filsystem. Navnet på block-device'n afhænger naturligvis af den anvendte hardware.

Ændringer i LUKS passphraser fortaget ved dette script kræver følgende

 - Der er eksakt èn partition som indeholder et crypto_LUKS filsystem.
 - OLD_PASSPHRASE er angivet korrekt, denne bliver brugt til verificering af operationen.
 - NEW_PASSPHRASE er angivet korrekt, den bliver tilføjet, slettet, eller første bliver ændret til anden.

Vigtig:

 - Standard administrator passphrase fra installationen skal udskiftes omgående med organisationen egne
   passphraser, standard passphrasen er ikke sikker at bruge.
 - Administrator passphrasen bør være forskellig fra PC til PC, og skal opbevares seperat i organisationens
   sikre systemer, så der er mulighed for at genåbne en PC's disk, når/hvis brugeren glemmer sin
   egen passphrase
 - Gamle, ubrugte passphraser - deriblandt standard admin passphrasen - skal fjernes fra LUKS, da de
   fortsat kan åbne krypteringen.
 - Der er kun plads til maksimal 8 passphraser i LUKS systemet - endnu en god grund til at fjerne ubrugte.
 - Tilføjer man samme passphrase flere gange med luksAddKey eller luksChangeKey, så optager den flere slots.
 - Byttes der rundt på FIRST og SECOND passphrase, så bliver den forkere manipuleret, hvilket potentiel
   ødelægger muligheden for disk recovery med administrator passphrasen.
 - Fjerner man FIRST passphrase, skal man passe på ikke at fjerne den sidste slots passphrase. Gør man det,
   så bliver disken permanent ulæselig, alle data går tabt, og operativsystemet skal geninstalleres.
 - Passphraser må kun bruge 7-bit ASCII printable characters (character code 32-126).
   See https://en.wikipedia.org/wiki/ASCII#Printable_characters.
 - For at undgå problemer med forkert keyboard setup anbefales der at holde sig til følgende tegn:
   a-z, A-Z, 0-9, mellemrum og bindestreg.
 - Passphraser bør være mindst 20 tegn lange, og må gerne bestå af flere ord adskilt af mellemrum eller
   bindestreg.

Parametre:

  ACTION = help | luksAddKey | luksChangeKey | luksDump | luksRemoveKey ( Vælg 'Valgmuligheder' )
  OLD_PASSPHRASE = <password> ( Vælg 'Adgangskode', brug kun ASCII-7 printable )
  NEW_PASSPHRASE = <password> ( Vælg 'Adgangskode', brug kun ASCII-7 printable )

Eksempel:

  luks_passphrase.sh help
  luks_passphrase.sh luksDump
  luks_passphrase.sh luksAddKey OLD_PASSPHRASE NEW_PASSPHRASE
  luks_passphrase.sh luksChangeKey OLD_PASSPHRASE NEW_PASSPHRASE
  luks_passphrase.sh luksRemoveKey OLD_PASSPHRASE

Konfigurationer i adminportalen:

 - security_luks luks_device : tom eller navn på LUKS device, som er sat op under installation.
 - security_luks luks_slots : [0-8] antal af LUKS passphrase slots der er brugt.

Mere info:

  - https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/FAQ.md Frequently Asked Questions Cryptsetup/LUKS
  - https://man7.org/linux/man-pages/man8/cryptsetup.8.html cryptsetup(8) — Linux manual page

EOF
           )

if [ "$ACTION" = "help" ]; then
    echo "$DESCRIPTION"
    exit 0
fi

# Need jq for json LUKS dump parsing
if ! jq --version ; then
    apt-get update
    apt-get install --assume-yes jq
fi

set_env_luks_slots() {
    LUKS_SLOTS="$(cryptsetup  --dump-json-metadata luksDump "${LUKS_DEVICE}" |  jq '.keyslots | length')"
}

set_and_send_config_security_luks() {
    # get all 'security_luks' config json items if exist
    JSON_STRING=$( get_os2borgerpc_config security_luks )
    if [ -z "${JSON_STRING}" ]; then
        JSON_STRING=$( jq -c --null-input \
            --arg luks-device '' \
            --arg luks-slots '' \
            '$ARGS.named')
    fi
    # update only 'luks-device' and 'luks-slots', keep possibly other existing alive
    JSON_STRING=$( echo "${JSON_STRING}" \
            | jq -c '."luks-device"='"\"${LUKS_DEVICE}\"" \
            | jq -c '."luks-slots"='"\"${LUKS_SLOTS}\"" )
    set_os2borgerpc_config security_luks "${JSON_STRING}"
    os2borgerpc_push_config_keys --read-only security_luks
}

LUKS_CRYPTO_PARTITIONS="$(export IFS=""; lsblk -o NAME,FSTYPE,UUID --list | grep 'crypto_LUKS')"
LUKS_CRYPTO_COUNT="$(export IFS=""; echo "${LUKS_CRYPTO_PARTITIONS}" | grep -c crypto_LUKS)"

if [ "$LUKS_CRYPTO_COUNT" != "1" ]; then
    echo "ERROR: Scriptet forventer eksakt èn crypto_LUKS partition, men fandt ${LUKS_CRYPTO_COUNT}"
    lsblk -o NAME,FSTYPE,UUID
    exit 1
fi

echo "Der er ${LUKS_CRYPTO_COUNT} crypto_LUKS partition"
echo "${LUKS_CRYPTO_PARTITIONS}"

# Notice varying amount of whitespaces and tabs in output of 'lsblk' needs squeezing of blanks
# 'nvme0n1p3         crypto_LUKS 41b75257-eab6-4e9e-bd97-46fc1eea44a2'
LUKS_DEVICE="/dev/$(echo "${LUKS_CRYPTO_PARTITIONS}" | tr -s '[:blank:]' | cut -d ' ' -f1)"

if ! cryptsetup isLuks "${LUKS_DEVICE}"; then
    echo "ERROR: ikke fundet LUKS device ${LUKS_DEVICE}"
    exit 1
fi

LUKS_UUID="$(echo "${LUKS_CRYPTO_PARTITIONS}" | tr -s '[:blank:]' | cut -d ' ' -f3)"
echo "LUKS_DEVICE=${LUKS_DEVICE}"
echo "LUKS_UUID=${LUKS_UUID}"
LUKS_SLOTS=""
set_env_luks_slots

if [ "$ACTION" = "luksDump" ]; then
    echo "LUKS passphrase slots inspecting '$ACTION' device ${LUKS_DEVICE}"
    cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    set_and_send_config_security_luks
    exit 0
fi

# Check that first passphrase argument is valid and does open device
if [ -z  "${OLD_PASSPHRASE}" ]; then
    echo "ERROR: OLD_PASSPHRASE er tom"
    set_and_send_config_security_luks
    exit 1
fi

if echo "${OLD_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
    echo "OLD_PASSPHRASE åbner LUKS device ${LUKS_DEVICE}"
else
    echo "ERROR: OLD_PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
    set_and_send_config_security_luks
    exit 1
fi

echo "LUKS passphrase opdatering '$ACTION' device ${LUKS_DEVICE}"

if [ "$ACTION" = "luksAddKey" ] || [ "$ACTION" = "luksChangeKey" ]; then
    # Check that second passphrase argument is valid
    if [ -z "${NEW_PASSPHRASE}" ]; then
        echo "ERROR: NEW_PASSPHRASE er tom"
        set_and_send_config_security_luks
        exit 1
    fi
    printf '%s\n%s' "${OLD_PASSPHRASE}" "${NEW_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    set_env_luks_slots
    if echo "${NEW_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "NEW_PASSPHRASE åbner LUKS device ${LUKS_DEVICE}"
        set_and_send_config_security_luks
    else
        echo "ERROR: NEW_PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
        set_and_send_config_security_luks
        exit 1
    fi

elif [ "$ACTION" = "luksRemoveKey" ]; then
    if [ "${LUKS_SLOTS}" = "1" ] ; then
        echo "ERROR: nægter at slette den sidste LUKS slot på device ${LUKS_DEVICE}"
        echo "ERROR: det efterlader device ${LUKS_DEVICE} permanent krypteret med data tab til følge"
        set_and_send_config_security_luks
        exit 1
    fi
    echo "${OLD_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    if echo "${OLD_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "ERROR: OLD_PASSPHRASE åbner stadigvæk LUKS device ${LUKS_DEVICE}"
        echo "Måske var OLD_PASSPHRASE tilføjet flere gange ?"
        echo "Undersøg hvor mange slots der er med instruks 'luksDump' før du prøver at fjerne den endnu en gang !"
        set_env_luks_slots
        set_and_send_config_security_luks
        exit 1
    else
        echo "OLD_PASSPHRASE er fjernet fra LUKS device ${LUKS_DEVICE}"
        set_env_luks_slots
        set_and_send_config_security_luks
    fi

else
    echo "ERROR: uventet LUKS passphrase opdatering '$ACTION'"
    echo ""
    exit 1
fi
