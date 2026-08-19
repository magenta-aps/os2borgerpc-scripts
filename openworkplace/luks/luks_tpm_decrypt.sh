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

I dette tilfælde har vi block-device '/dev/nvme0n1p3' med en partition der indeholder et crypto_LUKS
filsystem.

Ændringer i TPM og clevis baseret LUKS dekryptering fortaget ved dette script kræver følgende

 - Ubuntu 24.04 med 'update-initramfs' som iniramfs utility - eller
 - Ubuntu 26.04 med 'dracut' som iniramfs utility - indført med Ubuntu 25.10
 - TPM 2.0 chippen findes i PC'en, og er slået til i BIOS/UEFI boot konfigurationen
 - der er precis èn partition der indeholder et crypto_LUKS filsystem
 - LUKS PASSPHRASE er angivet korrekt, denne bliver brugt til verificering af operationen

Vigtig:

 - Ubuntu 24.04 eller 26.04 systemet SKAL være installeret med LUKS full-disk kryptering ( kun en root partition )
   og skal have kendt passphrase - valg 'Encrypt with a passphrase': 'You will need to enter a passphrase
   every time you turn on your computer' under installationen.
 - Alternativ til dette script kan man under installation af Ubuntu 2026.0.4 vælge 'Use hardware-backed encryption':
   'The disc will unlock automatically during startup', så behøver man ikke at køre dette script.
 - TPM chippen låser disken op ved boot, hvis hardware konfiguration ikke har ændret sig.
 - Dette script installer altså IKKE to-faktor authentificering af brugeren før dekryptering af disken.
 - Administrator passphrasen bør være forskellig fra PC til PC, og skal opbevares særligt i organisationens
   sikre systemer, så der er mulighed for at genåbne en PC's disk, når/hvis TPM chippen fejler grundet
   ændrede hardware specifikationer eller firmware opdateringer.
 - Der er kun plads til maksimal 8 passphraser i LUKS system, scriptet fejler hvis der ikke er en ledig slot.
 - Ønsker man en mere sikker dekrypteringsprocess end TPM alene, skal man bruge en pre-boot LUKS passphrase
   i stedet for, eller TPM sammen med en lokal Tang netværksserver.
 - Efter install og re-boot bliver der vist en LUKS passphrase box; ignorere man denne og venter lidt,
   bliver disken låst op af TPM 2.0 chippen.
 - Hvis man efter installering af TPM 2.0 chip dekryptering kører en firmware update, der rører firmware til
   TPM 2.0 chippen, så taber man automatisk dekryptering derefter !!!

Parametre:

  INSTALL = True | False ( Vælg 'Afkrydsningsfelt' )
  PASSPHRASE = <password> ( Vælg 'Adgangskode', brug kun ASCII-7 printable )

Eksempel:

  luks_tpm_decrypt.sh True PASSPHRASE
  luks_tpm_decrypt.sh False PASSPHRASE

Konfigurationer i adminportalen:

 - security_luks_device : tom eller navn på LUKS device, som er sat op under installation.
 - security_luks_slots : [0-8] antal af LUKS passphrase slots der er brugt.
 - security_tpm_version : tom (TPM 2.0 chip ikke fundet ) eller tallet 2 (TPM 2.0 chip fundet).
 - security_luks_tpm_slot : tom eller [0-8] det specifikke LUKS slot der indeholder TPM 2.0 koden.

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
            --arg tpm-slot '' \
            --arg tpm-version '' \
            '$ARGS.named')
    fi
    # update only 'luks-device' and 'luks-slots', keep possibly other existing alive
    JSON_STRING=$( echo "${JSON_STRING}" \
            | jq -c '."luks-device"='"\"${LUKS_DEVICE}\"" \
            | jq -c '."luks-slots"='"\"${LUKS_SLOTS}\"" \
            | jq -c '."tpm-slot"='"\"${TPM_SLOT}\"" \
            | jq -c '."tpm-version"='"\"${TPM_VERSION}\"" )
    set_os2borgerpc_config security_luks "${JSON_STRING}"
    os2borgerpc_push_config_keys --read-only security_luks
}

TPM_VERSION="$(cat /sys/class/tpm/tpm0/tpm_version_major)"

# Trusted Platform Module 2.0 (TPM2) chip er tilstede ?
if [ "2" != "${TPM_VERSION}" ] ; then
    echo "ERROR: Trusted Platform Module 2.0 (TPM2) chip er IKKE tilstede"
    echo "Check gerne BIOS/UEFI konfigurationen"
    exit 1
fi

# Check that passphrase argument is not empty
if [ -z  "${PASSPHRASE}" ]; then
    echo "ERROR: PASSPHRASE er tom"
    exit 1
fi

# Needed packages: Ubuntu 2024.04 uses 'update-initramfs', and Ubuntu 2026.04 uses 'dracut' by default
if ! which clevis ; then
    apt-get update
    apt-get install --assume-yes clevis clevis-tpm2 clevis-luks tpm2-tools
    if which dracut ; then
        apt-get install --assume-yes clevis-dracut
    elif which update-initramfs ; then
        apt-get install --assume-yes clevis-initramfs
    else
        echo "ERROR: Bruges der 'dracut' eller 'update-initramfs' på dette system ??"
        cat /etc/os-release
        exit 1
    fi
fi

# Need jq for json LUKS dump parsing
if ! jq --version ; then
    apt-get update
    apt-get install --assume-yes jq
fi

# Trusted Platform Module 2.0 (TPM2) chip virker ?
if ! tpm2_getrandom --hex 16 ; then
    echo "ERROR: Trusted Platform Module 2.0 (TPM2) chip virker IKKE"
    echo "Check gerne BIOS/UEFI konfigurationen"
    exit 1
fi

LUKS_CRYPTO_PARTITIONS="$(export IFS=""; lsblk -o NAME,FSTYPE,UUID --list | grep 'crypto_LUKS')"
LUKS_CRYPTO_COUNT="$(export IFS=""; echo "${LUKS_CRYPTO_PARTITIONS}" | grep -c crypto_LUKS)"

if [ "$LUKS_CRYPTO_COUNT" != "1" ]; then
    echo "ERROR: Scriptet forventer eksakt èn crypto_LUKS partition, men fandt ${LUKS_CRYPTO_COUNT}"
    echo "${LUKS_CRYPTO_PARTITIONS}"
    exit 1
fi

echo ""
echo "Der er ${LUKS_CRYPTO_COUNT} crypto_LUKS partition"
echo "${LUKS_CRYPTO_PARTITIONS}"

# Notice varying amount of whitespaces and tabs in output of 'lsblk' needs squeezing of blanks
# 'nvme0n1p3         crypto_LUKS 41b75257-eab6-4e9e-bd97-46fc1eea44a2'
LUKS_DEVICE="/dev/$(echo "${LUKS_CRYPTO_PARTITIONS}" | tr -s '[:blank:]' | cut -d ' ' -f1)"
LUKS_UUID="$(echo "${LUKS_CRYPTO_PARTITIONS}" | tr -s '[:blank:]' | cut -d ' ' -f3)"
echo "LUKS_DEVICE=${LUKS_DEVICE}"
echo "LUKS_UUID=${LUKS_UUID}"
LUKS_SLOTS=""
LUKS_TPM_SLOTS=""
TPM_SLOT=""

set_env_luks

if [ "${INSTALL}" = "True" ]; then

    if echo "${PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "PASSPHRASE åbner LUKS device ${LUKS_DEVICE}"
    else
        echo "ERROR: PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
        set_and_send_config_security_luks
        exit 1
    fi

    if [ "0" != "${LUKS_TPM_SLOTS}" ]; then
        echo "ERROR: TPM 2.0 er allerede konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Måske skal TPM 2.0 fjernes med dette script før scriptet køres igen ??"
        set_and_send_config_security_luks
        exit 1
    fi

    echo "LUKS passphrase TPM chip opdatering '$INSTALL' device ${LUKS_DEVICE}"
    if echo "${PASSPHRASE}" | clevis luks bind -d "${LUKS_DEVICE}" tpm2 '{"pcr_ids": "7"}'; then
        echo "Bind against Platform Configuration Register (PCR) 7"
        echo "PCR 7: Tracks Secure Boot state and platform integrity policies"
        set_env_luks
        set_and_send_config_security_luks
    else
        echo "ERROR: Bind against Platform Configuration Register (PCR) 7 failed"
        set_env_luks
        set_and_send_config_security_luks
        exit 1
    fi

    # Update initial ramdisc with these clevis modules and print info
    if which dracut ; then
        # build dracut image, notice  --hostonly option does not work on generic images
        if dracut --force ; then
            echo "Iniramfs for den kørende kernel er opgraderet med clevis moduler for device ${LUKS_DEVICE}"
            uname -a
            lsinitrd | grep '^clevis' # from dracut-core
            clevis luks list -d "${LUKS_DEVICE}"
        else
            echo "ERROR: Iniramfs opgradering med clevis moduler fejlede for device ${LUKS_DEVICE}"
            exit 1
        fi
    elif which update-initramfs ; then
        # build initramfs image
        if update-initramfs -u -k all ; then
            echo "Iniramfs for den kørende kernel er opgraderet med clevis moduler for device ${LUKS_DEVICE}"
            uname -a
            lsinitramfs "/boot/initrd.img-$(uname -r)" | grep 'clevis'
            clevis luks list -d "${LUKS_DEVICE}"
        else
            echo "ERROR: Iniramfs opgradering med clevis moduler fejlede for device ${LUKS_DEVICE}"
            exit 1
        fi
    fi

    if [ "1" = "${LUKS_TPM_SLOTS}" ]; then
        echo "TPM 2.0 er med succes konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Re-boot af computeren er nødvendig for at scriptet tager effekt"
        exit 0
    else
        echo "ERROR: TPM 2.0 konfigurationen i LUKS fejlede"
        exit 1
    fi

elif [ "$INSTALL" = "False" ]; then
    if [ "0" = "${LUKS_TPM_SLOTS}" ]; then
        echo "TPM 2.0 er ikke konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Stopper nu"
        set_and_send_config_security_luks
        exit 0
    fi

    if [ "${LUKS_SLOTS}" = "1" ] ; then
        echo "ERROR: nægter at slette den sidste LUKS slot på device ${LUKS_DEVICE}"
        echo "ERROR: det efterlader device ${LUKS_DEVICE} permanent krypteret med data tab til følge"
        set_and_send_config_security_luks
        exit 1
    fi

    echo "Fjerner TPM 2.0 LUKS slot ${TPM_SLOT} fra device ${LUKS_DEVICE}"
    # unbind the specific slot
    clevis luks unbind -f -d "${LUKS_DEVICE}" -s "${TPM_SLOT}"
    set_env_luks
    set_and_send_config_security_luks

    if [ "0" != "${LUKS_TPM_SLOTS}" ]; then
        echo "ERROR: TPM 2.0 er stadigvæk konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Måske skal TPM 2.0 fjernes endnu en gang med dette script ??"
        exit 1
    fi
fi
