#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marc Cromme

# Script arguments
INSTALL=$1
PASSPHRASE=$2


export DEBIAN_FRONTEND=noninteractive

DESCRIPTION=$(cat <<EOF
TPM chip baseret åbning af LUKS full-disk kryptering

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

I dette tilfælde har vi block-device '/dev/nvme0n1p3' med en partition der indeholder et crypto_LUKS
filsystem.

Ændringer i TPM og clevis baseret LUKS dekryptering foretaget ved dette script kræver følgende:

 - Ubuntu før 25.10 med 'update-initramfs' som iniramfs utility - eller
 - Ubuntu efter eller lige med 25.10 med 'dracut' som iniramfs utility
 - TPM 2.0 chippen findes i PC'en, og er slået til i BIOS/UEFI boot konfigurationen.
 - Der er præcis èn partition der indeholder et crypto_LUKS filsystem.
 - LUKS PASSPHRASE er angivet korrekt, denne bliver brugt til verificering af operationen.

Bemærk:

 - Ubuntu systemet SKAL være installeret med LUKS full-disk kryptering ( kun en root partition ) og skal
   have kendt passphrase.
 - TPM chippen låser disken op ved boot, hvis hardware konfiguration ikke har ændret sig.
 - Administrator passphrasen bør være forskellig fra PC til PC, og skal opbevares særligt i organisationens
   sikre systemer, så der er mulighed for at genåbne en PC's disk, når/hvis TPM chippen fejler grundet
   ændrede hardware specifikationer eller firmware opdateringer.
 - Der er kun plads til maksimalt 8 passphraser i LUKS version 1, og 32 i LUKS version 2. Scriptet fejler, hvis
   der ikke er en ledig slot.
 - Ønsker man en mere sikker dekrypteringsprocess end TPM alene, skal man bruge en pre-boot LUKS passphrase
   i stedet for, eller TPM sammen med en lokal Tang netværksserver.
 - Efter install og re-boot bliver der vist en LUKS passphrase box; ignorerer man denne og venter lidt,
   bliver disken låst op af TPM 2.0 chippen.
 - Opdateringer af firmware til TPM 2.0 chippen kan medføre tab af den automatiske dekryptering.

Parametre:

  INSTALL = True | False
  PASSPHRASE = <password>

Eksempel:

  luks_tpm_decrypt.sh True PASSPHRASE
  luks_tpm_decrypt.sh False PASSPHRASE

Konfigurationer i adminportalen:

 - security_luks luks_device : tom eller navn på LUKS device, som er sat op under installation.
 - security_luks luks_slots : [0-8/32] antal af LUKS passphrase slots der er brugt.
 - security_luks luks_version : tom (ingen cryptsetup), 1 eller 2.
 - security_luks tpm_version : tom (TPM 2.0 chip ikke fundet ) eller tallet 2 (TPM 2.0 chip fundet).
 - security_luks tpm_slot : tom eller [0-8/32] det specifikke LUKS slot der indeholder TPM 2.0 koden.

Mere info:

  - https://ubuntu.com/server/docs/how-to/security/tpm-backed-luks-decryption-with-clevis/
  - https://manpages.ubuntu.com/manpages/focal/man1/clevis.1.html

EOF
)

if [ ! "${INSTALL}" = "True" ] && [ ! "${INSTALL}" = "False" ]; then
    echo "$DESCRIPTION"
    exit 1
fi

set_env_luks() {
    LUKS_SLOTS="$(cryptsetup  --dump-json-metadata luksDump "${LUKS_DEVICE}" |  jq '.keyslots | length')"
    LUKS_VERSION="$(cryptsetup luksDump "${LUKS_DEVICE}" | awk '/Version:/ {print $2}')"
    LUKS_TPM_SLOTS="$(clevis luks list -d "${LUKS_DEVICE}" | grep -c tpm2 )"
    TPM_SLOT="$(clevis luks list -d "${LUKS_DEVICE}" | grep tpm2 | cut -d ':' -f1)"
}

set_and_send_config_security_luks() {
    # get all 'security_luks' config json items if exist
    JSON_STRING=$( get_os2borgerpc_config security_luks )
    if [ -z "${JSON_STRING}" ]; then
        JSON_STRING=$( jq -c --null-input \
            --arg luks-device '' \
            --arg luks-slots '' \
            --arg luks-version '' \
            --arg tpm-slot '' \
            --arg tpm-version '' \
            '$ARGS.named')
    fi
    # update all 5 luks variables
    JSON_STRING=$( echo "${JSON_STRING}" \
            | jq -c '."luks-device"='"\"${LUKS_DEVICE}\"" \
            | jq -c '."luks-slots"='"\"${LUKS_SLOTS}\"" \
            | jq -c '."luks-version"='"\"${LUKS_VERSION}\"" \
            | jq -c '."tpm-slot"='"\"${TPM_SLOT}\"" \
            | jq -c '."tpm-version"='"\"${TPM_VERSION}\"" )
    set_os2borgerpc_config security_luks "${JSON_STRING}"
    os2borgerpc_push_config_keys --read-only security_luks
}

if ! which cryptsetup > /dev/null; then
    echo "ERROR: OS is not set up with cryptsetup LUKS block device"
    exit 1
fi

TPM_VERSION="$(cat /sys/class/tpm/tpm0/tpm_version_major)"

# Trusted Platform Module 2.0 (TPM2) exists and is enabled in BIOS/UEFI ?
if [ "2" != "${TPM_VERSION}" ] ; then
    echo "ERROR: Trusted Platform Module 2.0 (TPM2) chip is not enabled"
    echo "       Please check the BIOS/UEFI configuration"
    exit 1
fi

# Check that passphrase argument is not empty
if [ -z "${PASSPHRASE}" ]; then
    echo "ERROR: PASSPHRASE is empty"
    exit 1
fi

# check LUKS setup of computer
LUKS_CRYPTO_PARTITIONS="$(lsblk -o NAME,FSTYPE,UUID --list | grep 'crypto_LUKS')"
LUKS_CRYPTO_COUNT="$(echo "${LUKS_CRYPTO_PARTITIONS}" | grep -c crypto_LUKS)"

if [ "$LUKS_CRYPTO_COUNT" != "1" ]; then
    echo "ERROR: Expected exactly one crypto_LUKS partition, but found ${LUKS_CRYPTO_COUNT}"
    echo "${LUKS_CRYPTO_PARTITIONS}"
    exit 1
fi

# Notice varying amount of whitespaces and tabs in output of 'lsblk'
# 'nvme0n1p3         crypto_LUKS 41b75257-eab6-4e9e-bd97-46fc1eea44a2'
LUKS_DEVICE="/dev/$(echo "${LUKS_CRYPTO_PARTITIONS}" | awk '{print $1}')"

set_env_luks

# Needed packages: Ubuntu 2024.04 uses 'update-initramfs', and Ubuntu 2026.04 uses 'dracut' by default
if ! which clevis > /dev/null; then
    apt-get update > /dev/null
    apt-get install --assume-yes clevis clevis-tpm2 clevis-luks tpm2-tools
    if which dracut > /dev/null; then
        apt-get install --assume-yes clevis-dracut
    elif which update-initramfs > /dev/null; then
        apt-get install --assume-yes clevis-initramfs
    else
        echo "ERROR: did not find either 'dracut' or 'update-initramfs' for update of initramfs"
        cat /etc/os-release
        exit 1
    fi
fi

# Need jq for json LUKS dump parsing
if ! jq --version > /dev/null; then
    apt-get update > /dev/null
    apt-get install --assume-yes jq
fi

# Trusted Platform Module 2.0 (TPM2) chip is functional ?
if ! tpm2_getrandom --hex 16 > /dev/null; then
    echo "ERROR: Trusted Platform Module 2.0 (TPM2) chip is not working"
    echo "       Please check the BIOS/UEFI configuration"
    exit 1
fi

if ! echo "${PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
    echo "ERROR: PASSPHRASE does not open LUKS device ${LUKS_DEVICE}"
    exit 1
fi

if [ "${INSTALL}" = "True" ]; then

    if [ "0" != "${LUKS_TPM_SLOTS}" ]; then
        echo "TPM 2.0 is already enabled in LUKS"
        set_and_send_config_security_luks
        exit 0
    fi

    echo "LUKS ${LUKS_VERSION} passphrase TPM  ${TPM_VERSION} chip opdatering '$INSTALL' device ${LUKS_DEVICE}"
    if echo "${PASSPHRASE}" | clevis luks bind -d "${LUKS_DEVICE}" tpm2 '{"pcr_bank":"sha256", "pcr_ids": "7"}'; then
        echo "Bind against Platform Configuration Register (PCR) 7"
        echo "PCR 7: Tracks Secure Boot state and platform integrity policies"
    else
        echo "ERROR: Bind against Platform Configuration Register (PCR) 7 failed"
        exit 1
    fi

    # Update initial ramdisc with these clevis modules and print info
    if which dracut > /dev/null; then
        # build dracut image, notice  --hostonly option does not work on generic images
        if ! dracut --force; then
            echo "ERROR: Clevis update of iniramfs for device ${LUKS_DEVICE} failed"
            exit 1
        fi
    elif which update-initramfs > /dev/null; then
        # build initramfs image
        if ! update-initramfs -u -k all; then
            echo "ERROR: update-initramfs for device ${LUKS_DEVICE} failed"
            exit 1
        fi
    fi

    set_env_luks
    set_and_send_config_security_luks

    if [ "1" = "${LUKS_TPM_SLOTS}" ]; then
        exit 0
    else
        echo "ERROR: TPM 2.0 decryption binding for LUKS failed"
        exit 1
    fi

elif [ "$INSTALL" = "False" ]; then
    if [ "0" = "${LUKS_TPM_SLOTS}" ]; then
        echo "TPM 2.0 is not configured in LUKS."
        set_and_send_config_security_luks
        exit 0
    fi

    if [ "1" = "${LUKS_SLOTS}" ]; then
        echo "ERROR: refuse to remove the last LUKS slot on device ${LUKS_DEVICE}"
        exit 1
    fi

    echo "Fjerner TPM 2.0 LUKS slot ${TPM_SLOT} fra device ${LUKS_DEVICE}"
    # unbind the specific slot
    clevis luks unbind -f -d "${LUKS_DEVICE}" -s "${TPM_SLOT}"
    set_env_luks
    set_and_send_config_security_luks

    if [ "0" != "${LUKS_TPM_SLOTS}" ]; then
        echo "ERROR: TPM 2.0 is still configured. Try re-running this script."
        exit 1
    fi
fi
