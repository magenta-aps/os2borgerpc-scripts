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

 - Ubuntu 26.04 med 'dracut' som iniramfs utility - sciptet fejler på alle Ubunu yngre end 25.10
 - TPM 2.0 chippen findes i PC'en, og er slået til i BIOS/UEFI boot konfigurationen
 - der er precis èn partition der indeholder et crypto_LUKS filsystem
 - LUKS PASSPHRASE er angivet korrekt, denne bliver brugt til verificering af operationen

Vigtig:

 - Ubuntu 26.04 systemet SKAL være installeret med LUKS full-disk kryptering ( kun en root partition )
   og skal have kendt passphrase - valg 'Encrypt with a passphrase': 'You will need to enter a passphrase
   every time you turn on your computer' under installationen
 - Alternativ til dette script bør man under installation vælge 'Use hardware-backed encryption':
   'The disc will unlock automatically during startup', så behøver man ikke at køre dette script
 - TPM chippen låser disken op ved boot, hvis hardware konfiguration ikke har ændret sig
 - Dette script installer altså IKKE to-faktor authentificering af brugeren før dekryptering af disken
 - Admin PASSPHRASE bør være forskellig fra PC til PC, og skal opbevares særligt i organisationens
   sikre systemer for at have muligheden for at genåbne en PC's disk, når/hvis TPM chippen fejler grundet
   ændrede hardware specifikationer
 - Der er kun plads til maksimal 8 passphraser i LUKS system, scriptet fejler hvis der ikke er en ledig slot
 - Ønsker man en mere sikker dekrypteringsprocess end TPM alene, skal man bruge en pre-boot LUKS passphrase
   i stedet for, eller sammen med TPM oplåsning
 - Efter install og re-boot bliver der vist en LUKS passphrase box; ignorere man denne og venter lidt,
   bliver disken låst op af TPM 2.0 chippen.

Parametre:

  INSTALL = True | False
  PASSPHRASE = <string> (ASCII-7 printable)

Eksempel:

  luks_tpm_decrypt.sh True PASSPHRASE
  luks_tpm_decrypt.sh False PASSPHRASE

Mere info:

  - https://ubuntu.com/server/docs/how-to/security/tpm-backed-luks-decryption-with-clevis/
  - https://manpages.ubuntu.com/manpages/focal/man1/clevis.1.html

EOF
)

if [ ! "${INSTALL}" = "True" ] && [ ! "${INSTALL}" = "False" ]; then
    echo "$DESCRIPTION"
    exit 1
fi

if grep 'Ubuntu 26\.04' /etc/os-release ; then
    echo "Fundet Ubuntu 26.04, fortsætter ..."
else
    echo "ERROR: Ubuntu 26.04 system kræves for dette script kan køre, stopper nu"
    exit 1
fi

# Trusted Platform Module 2.0 (TPM2) chip er tilstede ?
if [ "2" != "$(cat /sys/class/tpm/tpm0/tpm_version_major)" ] ; then
    echo "ERROR: Trusted Platform Module 2.0 (TPM2) chip er IKKE tilstede"
    echo "Check gerne BIOS/UEFI konfigurationen"
    exit 1
fi

# Check that passphrase argument is not empty
if [ -z  "${PASSPHRASE}" ]; then
    echo "ERROR: PASSPHRASE er tom"
    exit 1
fi

# Needed packages
if ! which clevis ; then
    apt-get update
    apt-get install --assume-yes clevis clevis-tpm2 clevis-dracut clevis-luks open-iscsi tpm2-tools
fi
# Need jq for json LUKS dump parsing
if ! jq --version ; then
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

# Double-check that we got the correct LUKS device
if ! cryptsetup isLuks "${LUKS_DEVICE}"; then
    echo "ERROR: ikke fundet LUKS device ${LUKS_DEVICE}"
    exit 1
fi

if [ "${INSTALL}" = "True" ]; then


    if echo "${PASSPHRASE}" | cryptsetup -v luksOpen --test-passphrase --timeout 10  --tries 1 "${LUKS_DEVICE}"; then
        echo "PASSPHRASE åbner LUKS device ${LUKS_DEVICE}"
    else
        echo "ERROR: PASSPHRASE åbner ikke LUKS device ${LUKS_DEVICE}"
        exit 1
    fi

    if [ "0" != "$(clevis luks list -d "${LUKS_DEVICE}" | grep -c tpm2 )" ]; then
        echo "ERROR: TPM 2.0 er allerede konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Måske skal TPM 2.0 fjernes med dette script før scriptet køres igen ??"
        exit 1
    fi

    echo "LUKS passphrase TPM chip opdatering '$INSTALL' device ${LUKS_DEVICE}"
    if echo "${PASSPHRASE}" | clevis luks bind -d "${LUKS_DEVICE}" tpm2 '{"pcr_ids": "7"}'; then
        echo "Bind against Platform Configuration Register (PCR) 7"
        echo "PCR 7: Tracks Secure Boot state and platform integrity policies"
    else
        echo "ERROR: Bind against Platform Configuration Register (PCR) 7 failed"
        exit 1
    fi

    # Update initial ramdisc with these clevis modules and print info
    # build image, notice  --hostonly option does not work on generic images
    if dracut --force ; then
        echo "Iniramfs for den kørende kernel er opgraderet med clevis moduler for device ${LUKS_DEVICE}"
        uname -a
        lsinitrd | grep '^clevis'
        clevis luks list -d "${LUKS_DEVICE}"
    else
        echo "ERROR: Iniramfs opgradering med clevis moduler fejlede for device ${LUKS_DEVICE}"
        exit 1
    fi

    if [ "1" = "$(clevis luks list -d "${LUKS_DEVICE}" | grep -c tpm2 )" ]; then
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
    if [ "0" = "$(clevis luks list -d "${LUKS_DEVICE}" | grep -c tpm2 )" ]; then
        echo "TPM 2.0 er ikke konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Stopper nu"
        exit 0
    fi

    REMAINING_SLOTS="$(cryptsetup  --dump-json-metadata luksDump "${LUKS_DEVICE}" |  jq '.keyslots | length')"
    if [ "${REMAINING_SLOTS}" = "1" ] ; then
        echo "ERROR: nægter at slette den sidste LUKS slot på device ${LUKS_DEVICE}"
        echo "ERROR: det efterlader device ${LUKS_DEVICE} permanent krypteret med data tab til følge"
        exit 1
    fi

    LUKS_SLOT="$(clevis luks list -d "${LUKS_DEVICE}" | cut -d ':' -f1)"
    echo "Fjerner TPM 2.0 LUKS slot ${LUKS_SLOT} fra device ${LUKS_DEVICE}"
    # unbind the specific slot
    clevis luks unbind -f -d "${LUKS_DEVICE}" -s "${LUKS_SLOT}"
    if [ "0" != "$(clevis luks list -d "${LUKS_DEVICE}" | grep -c tpm2 )" ]; then
        echo "ERROR: TPM 2.0 er stadigvæk konfigureret i LUKS"
        clevis luks list -d "${LUKS_DEVICE}"
        echo ""
        echo "Måske skal TPM 2.0 fjernes endnu en gang med dette script ??"
        exit 1
    fi
fi
