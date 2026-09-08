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

Scriptet forudsætter at installationen er foretaget med en og nøjagtig en cryptosetup LUKS
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
 - NEW_PASSPHRASE er angivet hvis den skal tilføjes, eller første skal ændres til anden.

Bemærk:

 - Standard administrator passphrase fra installationen skal udskiftes omgående med organisationens egne
   passphraser, standard passphrasen er ikke sikker at bruge.
 - Administrator passphrasen bør være forskellig fra PC til PC, og skal opbevares separat i organisationens
   sikre systemer, så der er mulighed for at genåbne en PC's disk, når/hvis brugeren glemmer sin
   egen passphrase.
 - Gamle, ubrugte passphraser skal fjernes fra LUKS, da de fortsat kan åbne krypteringen.
 - Der er kun garanteret 8 slots til passphraser i LUKS version 1, og 32 slots i LUKS version 2.
 - Fjerner man OLD passphrase, skal man passe på ikke at fjerne den sidste kendte passphrase. Gør man det,
   så bliver disken permanent ulæselig, alle data går tabt, og operativsystemet skal geninstalleres.
 - Er TPM 2.0 chip baseret dekodning slået til, så tager det et ekstra slot, og man skal stoppe med at fjerne
   passphraser når der er 2 tilbage. Er der kun TPM chip'ens passphrase tilbage, har man ingen mulighed
   for at ændre og tilføje passphraser mere.
 - Passphraser må kun bruge 7-bit ASCII printable characters (character code 32-126).
   See https://en.wikipedia.org/wiki/ASCII#Printable_characters.
 - For at undgå problemer med forkert keyboard setup anbefales der at holde sig til følgende tegn:
   a-z, A-Z, 0-9, mellemrum og bindestreg.
 - Passphraser bør være mindst 20 tegn lange, og må gerne bestå af flere adskilte ord.

Parametre:

  ACTION = luksAddKey | luksChangeKey | luksRemoveKey
  OLD_PASSPHRASE = <password>
  NEW_PASSPHRASE = <password>

Eksempel:

  luks_passphrase.sh luksAddKey OLD_PASSPHRASE NEW_PASSPHRASE
  luks_passphrase.sh luksChangeKey OLD_PASSPHRASE NEW_PASSPHRASE
  luks_passphrase.sh luksRemoveKey OLD_PASSPHRASE

Konfigurationer i adminportalen:

 - security_luks luks_device : tom eller navn på LUKS device, som er sat op under installation.
 - security_luks luks_slots : antal af LUKS passphrase slots der er brugt.
 - security_luks luks_version : tom (ingen cryptsetup), 1 eller 2.

Mere info:

  - https://gitlab.com/cryptsetup/cryptsetup/-/blob/main/FAQ.md Frequently Asked Questions Cryptsetup/LUKS
  - https://man7.org/linux/man-pages/man8/cryptsetup.8.html cryptsetup(8) — Linux manual page

EOF
           )

# Need jq for json LUKS dump parsing
if ! jq --version > /dev/null; then
    apt-get -qq update
    apt-get -qq --assume-yes install jq
fi

set_env_luks_slots() {
    LUKS_SLOTS="$(cryptsetup --dump-json-metadata luksDump "${LUKS_DEVICE}" | jq '.keyslots | length')"
}

set_and_send_config_security_luks() {
    # get all 'security_luks' config json items if exist
    JSON_STRING=$( get_os2borgerpc_config security_luks )
    if [ -z "${JSON_STRING}" ]; then
        JSON_STRING=$( jq -c --null-input \
            --arg luks-device '' \
            --arg luks-slots '' \
            --arg luks-version '' \
            '$ARGS.named')
    fi
    # update only 'luks-version', 'luks-device' and 'luks-slots', keep TPM fields alive
    JSON_STRING=$( echo "${JSON_STRING}" \
            | jq -c '."luks-device"='"\"${LUKS_DEVICE}\"" \
            | jq -c '."luks-slots"='"\"${LUKS_SLOTS}\"" \
            | jq -c '."luks-version"='"\"${LUKS_VERSION}\""
               )
    set_os2borgerpc_config security_luks "${JSON_STRING}"
    os2borgerpc_push_config_keys --read-only security_luks
}

if ! which cryptsetup > /dev/null; then
    echo "ERROR: OS is not set up with cryptsetup LUKS block device"
    exit 1
fi

LUKS_CRYPTO_PARTITIONS="$(lsblk -o NAME,FSTYPE,UUID --list | grep 'crypto_LUKS')"
LUKS_CRYPTO_COUNT="$(echo "${LUKS_CRYPTO_PARTITIONS}" | grep -c crypto_LUKS)"

if [ "$LUKS_CRYPTO_COUNT" != "1" ]; then
    echo "ERROR: expected exactly one crypto_LUKS partition, but got ${LUKS_CRYPTO_COUNT}"
    lsblk -o NAME,FSTYPE,UUID
    exit 1
fi

# Notice varying amount of whitespaces and tabs in output of 'lsblk' needs squeezing of blanks
# 'nvme0n1p3         crypto_LUKS 41b75257-eab6-4e9e-bd97-46fc1eea44a2'
LUKS_DEVICE="/dev/$(echo "${LUKS_CRYPTO_PARTITIONS}" | awk '{print $1}')"

if ! cryptsetup isLuks "${LUKS_DEVICE}"; then
    echo "ERROR: LUKS device '${LUKS_DEVICE}' not found"
    exit 1
fi

LUKS_VERSION="$(cryptsetup luksDump "${LUKS_DEVICE}" | awk '/Version:/ {print $2}')"
set_env_luks_slots

echo "LUKS ${LUKS_VERSION} passphrase '$ACTION' device ${LUKS_DEVICE} slots ${LUKS_SLOTS}"

# Check that first passphrase argument is valid and does open device
if [ -z  "${OLD_PASSPHRASE}" ]; then
    echo "ERROR: OLD_PASSPHRASE is empty"
    exit 1
fi

if ! echo "${OLD_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}";
then
    echo "ERROR: OLD_PASSPHRASE does not open LUKS device ${LUKS_DEVICE}"
    exit 1
fi

if [ "$ACTION" = "luksAddKey" ] || [ "$ACTION" = "luksChangeKey" ]; then
    # Check that second passphrase argument is valid
    if [ -z "${NEW_PASSPHRASE}" ]; then
        echo "ERROR: NEW_PASSPHRASE is empty"
        exit 1
    fi

    # Prevent adding same passphrase multiple times
    if echo "${NEW_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "NEW_PASSPHRASE already opens LUKS device ${LUKS_DEVICE}, will not add it a second time"
        set_and_send_config_security_luks
        exit 0
    fi

    printf '%s\n%s' "${OLD_PASSPHRASE}" "${NEW_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"
    set_env_luks_slots

    if echo "${NEW_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        set_and_send_config_security_luks
    else
        echo "ERROR: NEW_PASSPHRASE does not open LUKS device ${LUKS_DEVICE}"
        exit 1
    fi

elif [ "$ACTION" = "luksRemoveKey" ]; then
    # TODO: figure out how to test if the last slot belongs to TPM chip decryption, in which case the script
    #       should make sure that 2 slots remain
    if [ "${LUKS_SLOTS}" = "1" ] ; then
        echo "ERROR: will not remove the last LUKS PASSPHRASE slot from device ${LUKS_DEVICE}"
        echo "NOTICE: in case TPM chip decryption is enabled, the last LUKS PASSPHRASE slot belongs to TPM"
        echo "        and your last LUKS administrator passphrase slot might be lost anyhow"
        exit 1
    fi

    echo "${OLD_PASSPHRASE}" | cryptsetup "${ACTION}" --timeout 10 "${LUKS_DEVICE}"

    if echo "${OLD_PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "ERROR: OLD_PASSPHRASE still opens LUKS device ${LUKS_DEVICE}"
        echo "       Maybe OLD_PASSPHRASE had been manually added multiple times ?"
        echo "       Try to re-run to remove OLD_PASSPHRASE once more"
        set_env_luks_slots
        set_and_send_config_security_luks
        exit 1
    else
        echo "OLD_PASSPHRASE has been removed from LUKS device ${LUKS_DEVICE}"
        set_env_luks_slots
        set_and_send_config_security_luks
        exit 0
    fi

else
    echo "ERROR: unexpected LUKS passphrase updating '$ACTION'"
    echo ""
    echo "$DESCRIPTION"
    exit 1
fi
