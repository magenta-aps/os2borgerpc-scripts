#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# Script arguments
ACTION=$1
FIRST_PASSPHRASE=$2
SECOND_PASSPHRASE=$3


export DEBIAN_FRONTEND=noninteractive

DESCRIPTION=$(cat <<EOF
Opdater cryptsetup LUKS passfraser

Scriptet forudsætter at installationen er fortaget med en og nøjagtig en cryptosetup LUKS
partition af FSTYPE = crypto_LUKS og TYPE = part, for eksempel af formen

lsblk -o NAME,FSTYPE,TYPE

NAME                    FSTYPE      TYPE
nvme0n1                             disk
├─nvme0n1p1             vfat        part
├─nvme0n1p2             ext4        part
└─nvme0n1p3             crypto_LUKS part
  └─nvme0n1p3_crypt     LVM2_member crypt
    ├─jennie--vg-root   ext4        lvm
    └─jennie--vg-swap_1 swap        lvm

I dette tilfælde har vi block-device 'dev/nvme0n1p3' med en partition der indeholder et crypto_LUKS
filsystem.

Ændringer i LUKS passfraser fortaget ved dette script kræver følgende

 - der er eksakt èn partition der indeholder et crypto_LUKS filsystem
 - FIRST_PASSPHRASE er angivet korrekt, denne bliver brugt til verificering af operationen
 - SECOND_PASSPHRASE er angivet korrekt, den bliver tilføjet, slettet, eller første bliver ændret til anden

Vigtig:

 - Standard ADMIN PASSPHRASE fra installatione skal udskiftes omgående med organisationen egene
   passfraser, standard passfrasen er ikke sikker at bruge
 - ADMIN PASSPHRASE bør være forskellig fra PC til PC, og skal opbevares seperat i organisationens
   sikre systemer fo at have muligheden for at gen-åbne en PC's disk, når/hvis brugeren glemmer sin
   egen passfrase
 - Gamle, nu ubrugte passfraser - deriblandt standard admin passfrasen - skal fjernes fra LUKS, disse
   kan fortsat åbne krypteringen indtil de er fjenet.
 - Der er kun plads til maksimal 8 passfraser i LUKS system, endnu en god grund til at fjerne ubruge
 - Tilføjer man samme passfrase flere gange med luksAddKey eller luksChangeKey, så bliver den tilføjet flere gange
   og samme passfrase optager flere slots
 - Byttes der rundt på FIRST og SECOND passfrase, så bliver den forkere manipuleret, hvilket potentiel
   ødelægger muligheden for disk recovery med ADMIN passfrasen
 - Fjerner man FIRST passfrase, skal man passe på ikke at fjerne den sidste slots passfrase, sket det,
   så bliver disken permanent ulæselig, alle data går tabt, og operativsystemet skal gen-installeres
 - Passfraser må kun bruge 7-bit ASCII printable characters (character code 32-126)
   See https://en.wikipedia.org/wiki/ASCII#Printable_characters
 - For at undgå problemer med forkert keyboard setup anbefales der at man yderlige holder sig til
   chars: mellemrum, a-z, A-Z, og 0-9
 - Passfrase bør være mindst 20 bogstaver lang, og må gerne bestå af flere ord adskilt af mellemrum

Parametre:

  ACTION = help | luksAddKey | luksChangeKey | luksDump | luksRemoveKey
  FIRST_PASSFRASE = <string> (ASCII-7 printable)
  SECOND_PASSFRASE = <string> (ASCII-7 printable)

Eksempel:

  luks_passphrase.sh help
  luks_passphrase.sh luksDump
  luks_passphrase.sh luksAddKey FIRST_PASSPHRASE SECOND_PASSPHRASE
  luks_passphrase.sh luksChangeKey FIRST_PASSPHRASE SECOND_PASSPHRASE
  luks_passphrase.sh luksRemoveKey FIRST_PASSPHRASE

Mere info:

  - https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/FAQ.md Frequently Asked Questions Cryptsetup/LUKS
  - https://man7.org/linux/man-pages/man8/cryptsetup.8.html cryptsetup(8) — Linux manual page

EOF
           )

if [ "$ACTION" = "help" ]; then
    echo "$DESCRIPTION"
    exit 0
fi

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
LUKS_UUID="$(echo "${LUKS_CRYPTO_PARTITIONS}" | tr -s '[:blank:]' | cut -d ' ' -f3)"
echo "LUKS_DEVICE=${LUKS_DEVICE}"
echo "LUKS_UUID=${LUKS_UUID}"

# Double-check that we got the correct LUKS device
if ! cryptsetup isLuks "${LUKS_DEVICE}"; then
    echo "ERROR: ikke fundet LUKS device ${LUKS_DEVICE}"
    exit 1
fi

if [ "$ACTION" = "luksDump" ]; then
    echo "LUKS passfrase slots inspecting '$ACTION' device ${LUKS_DEVICE}"
    cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    exit 0
fi

# Check that first passphrase argument is valid and does open device
if [ -z  "${FIRST_PASSPHRASE}" ]; then
    echo "ERROR: FIRST_PASSPHRASE er tom"
    exit 1
fi

if echo "${FIRST_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
    echo "FIRST_PASSPHRASE åbner LUKS device ${LUKS_DEVICE}"
else
    echo "ERROR: FIRST_PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
    exit 1
fi

echo "LUKS passfrase opdatering '$ACTION' device ${LUKS_DEVICE}"

if [ "$ACTION" = "luksAddKey" ] || [ "$ACTION" = "luksChangeKey" ]; then
    # Check that second passphrase argument is valid
    if [ -z "${SECOND_PASSPHRASE}" ]; then
        echo "ERROR: SECOND_PASSPHRASE er tom"
        exit 1
    fi
    printf '%s\n%s' "${FIRST_PASSPHRASE}" "${SECOND_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    if ! echo "${SECOND_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "ERROR: SECOND_PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
        exit 1
    fi

elif [ "$ACTION" = "luksRemoveKey" ]; then
    echo "${FIRST_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    if echo "${FIRST_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "ERROR: FIRST_PASSPHRASE åbner stadigvæk LUKS device ${LUKS_DEVICE}"
        echo "Måske var FIRST_PASSPHRASE tilføjet flere gange ?"
        echo "Undersøg hvor mange slots der er med instruks 'luksDump' før du prøver at fjerne den endnu en gang !"
        exit 1
    fi

else
    echo "ERROR: uventet LUKS passfrase opdatering '$ACTION'"
    echo ""
    exit 1
fi
