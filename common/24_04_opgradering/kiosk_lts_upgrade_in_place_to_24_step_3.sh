#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# SYNOPSIS
#    kiosk_lts_upgrade_in_place_to_24_step_3.sh
#
# DESCRIPTION
#    Step three of the upgrade from 22.04 to 24.04.
#    Designed for Kiosk machines

set -ex

if ! get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "This script is not designed to be run on a regular OS2borgerPC device."
  exit 1
fi

PREVIOUS_STEP_DONE="/etc/os2borgerpc/second_24_upgrade_step_done"
if [ ! -f "$PREVIOUS_STEP_DONE" ]; then
  echo "24.04 opgradering - Opgradering til Ubuntu 24.04 trin 2 has not been run."
  exit 1
fi

REBOOT_REQUIRED_FILE="/var/run/reboot-required"
if [ -f "$REBOOT_REQUIRED_FILE" ]; then
  echo "The computer must be rebooted before running this script. Reboot the computer and run this script again."
  exit 1
fi

# Make double sure that the crontab has been emptied
TMP_ROOTCRON=/etc/os2borgerpc/tmp_rootcronfile
if [ -f "$TMP_ROOTCRON" ]; then
  crontab -r || true
fi

# Prevent the upgrade from removing python while we are using it to run jobmanager
apt-mark hold python3.10

# Make sure release-upgrade prompt is not never so that the upgrade can run
# Also set the prompt to lts so that the upgrader will only look for lts releases
release_upgrades_file=/etc/update-manager/release-upgrades

sed --in-place "s/Prompt=.*/Prompt=lts/" $release_upgrades_file

# Perform the actual upgrade with some error handling
if lsb_release -d | grep --quiet 22; then
  do-release-upgrade -f DistUpgradeViewNonInteractive >  /var/log/os2borgerpc_upgrade_1.log || true
fi

apt-get --assume-yes --fix-broken install || true
apt-get --assume-yes install --upgrade python3-pip || true
apt-get --assume-yes autoremove || true
apt-get --assume-yes clean || true

# Make sure that jobmanager can still find the client

# Install the client via pipx
apt-get --assume-yes install pipx || true
# Take a backup of jobmanager before overwriting it, just in case
cp "/usr/local/bin/jobmanager" "/etc/os2borgerpc/"
PIPX_ERRORS="False"
PIPX_BIN_DIR="/usr/local/bin" PIPX_HOME="/root/.local/share/pipx" pipx install --force os2borgerpc-client || PIPX_ERRORS="True"

if [ "$PIPX_ERRORS" = "True" ]; then
  mkdir --parents /usr/local/lib/python3.12
  cp --recursive /usr/local/lib/python3.10/dist-packages/ /usr/local/lib/python3.12/
  # Revert to the backup of jobmanager, which uses the client installed via pip
  cp "/etc/os2borgerpc/jobmanager" "/usr/local/bin/"
  echo "A problem occurred during the switch to pipx. Try rebooting and running this script again."
  echo "If the problem persists, contact support."
  exit 1
else
  rm "/etc/os2borgerpc/jobmanager"
fi

if ! lsb_release -d | grep --quiet 24; then
  echo "Opgraderingen er ikke blevet gennemført. Prøv at genstarte computeren og køre dette script igen."
  exit 1
fi

# If they were using an onboard keyboard, maintain our custom settings
if [ -f /usr/share/onboard/layouts/Compact_orig.onboard ]; then
  cat << EOF > /usr/share/onboard/layouts/Compact.onboard
<?xml version="1.0" ?>
<!-- OS2borgerPC Kiosk: Comment out Control, Alt, Quit and Settings buttons -->

<!--
Copyright © 2013 Francesco Fumanti <francesco.fumanti@gmx.net>
Copyright © 2011-2014 marmuta <marmvta@gmail.com>

This file is part of Onboard.

Onboard is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 3 of the License, or
(at your option) any later version.

Onboard is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program. If not, see <http://www.gnu.org/licenses/>.
-->

<keyboard
    id="Compact"
    format="3.2"
    section="system"
    summary="Medium size desktop keyboard" >

    <include file='key_defs.xml'/>

    <box border="0.5" spacing="1.5" orientation="vertical">

        <!--- word suggestions -->
        <panel filename='Compact-Alpha.svg' scan_priority='1'>
            <include file='word_suggestions.xml'/>
        </panel>

        <box spacing='1.5'>
            <box spacing='2'>
                <!--- keyboard, multiple layers -->
                <panel>
                    <panel layer="alpha" filename="Compact-Alpha.svg">
                        <key group="alphanumeric" id="AB01"/>
                        <key group="alphanumeric" id="AE02"/>
                        <key group="alphanumeric" id="AE03"/>
                        <key group="alphanumeric" id="AD09"/>
                        <key group="alphanumeric" id="AE01"/>
                        <key group="alphanumeric" id="AE06"/>
                        <key group="alphanumeric" id="AE07"/>
                        <key group="alphanumeric" id="AE04"/>
                        <key group="alphanumeric" id="AE05"/>
                        <key group="alphanumeric" id="AD03"/>
                        <key group="alphanumeric" id="AD02"/>
                        <key group="alphanumeric" id="AD01"/>
                        <key group="alphanumeric" id="AE09"/>
                        <key group="alphanumeric" id="AD07"/>
                        <key group="alphanumeric" id="AD06"/>
                        <key group="alphanumeric" id="AD05"/>
                        <key group="alphanumeric" id="AD04"/>
                        <key group="alphanumeric" id="AB10"/>
                        <key group="alphanumeric" id="AC11"/>
                        <key group="alphanumeric" id="AC10"/>
                        <key group="alphanumeric" id="TLDE"/>
                        <key group="alphanumeric" id="LSGT"/>
                        <key group="alphanumeric" id="BKSL"/>
                        <key group="alphanumeric" id="AD10"/>
                        <key group="alphanumeric" id="AD11"/>
                        <key group="alphanumeric" id="AD12"/>
                        <key group="alphanumeric" id="AB08"/>
                        <key group="alphanumeric" id="AE11"/>
                        <key group="alphanumeric" id="AE10"/>
                        <key group="alphanumeric" id="AE12"/>
                        <key group="alphanumeric" id="AC04"/>
                        <key group="alphanumeric" id="AC05"/>
                        <key group="alphanumeric" id="AC06"/>
                        <key group="alphanumeric" id="AC07"/>
                        <key group="alphanumeric" id="AB09"/>
                        <key group="alphanumeric" id="AC01"/>
                        <key group="alphanumeric" id="AC02"/>
                        <key group="alphanumeric" id="AC03"/>
                        <key group="alphanumeric" id="AB05"/>
                        <key group="alphanumeric" id="AB04"/>
                        <key group="alphanumeric" id="AE08"/>
                        <key group="alphanumeric" id="AB06"/>
                        <key group="alphanumeric" id="AC08"/>
                        <key group="alphanumeric" id="AC09"/>
                        <key group="alphanumeric" id="AB03"/>
                        <key group="alphanumeric" id="AB02"/>
                        <key group="alphanumeric" id="AD08"/>
                        <key group="alphanumeric" id="AB07"/>

                        <key group='misc'      id='CAPS'/>
                        <key group='shifts'    id='LFSH'/>
                        <key group='shifts'    id='RTSH'/>
                        <!--<key group='bottomrow' id='LCTL'/>
                        <key group='bottomrow' id='LALT'/>
                        <key group='bottomrow' id='RALT'/>
                        <key group="bottomrow" id="LWIN"/>-->

                        <key group="bottomrow" id="SPCE"/>
                        <key group="bottomrow" id="DELE.next-to-backspace"/>
                        <key group="bottomrow" id="BKSP"/>
                        <key group="misc" id="TAB"/>
                        <key group="misc" id="RTRN" label_x_align='0.65'/>
                        <key group="directions_alpha" id="LEFT"/>
                        <key group="directions_alpha" id="RGHT"/>
                        <key group="directions_alpha" id="UP"/>
                        <key group="directions_alpha" id="DOWN"/>
                    </panel>
                    <panel layer="numbers" filename="Compact-Numbers.svg" border="2">

                        <key group='keypadmisc' id='NMLK' scan_priority='2'/>
                        <key group="keypadmisc" id="KPDL" scan_priority="2"/>
                        <key group="keypadmisc" id="KPEN" scan_priority="2"/>
                        <key group="keypadnumber" id="KP0" scan_priority="2"/>
                        <key group="keypadnumber" id="KP1" scan_priority="2"/>
                        <key group="keypadnumber" id="KP2" scan_priority="2"/>
                        <key group="keypadnumber" id="KP3" scan_priority="2"/>
                        <key group="keypadnumber" id="KP4" scan_priority="2"/>
                        <key group="keypadnumber" id="KP5" scan_priority="2"/>
                        <key group="keypadnumber" id="KP6" scan_priority="2"/>
                        <key group="keypadnumber" id="KP7" scan_priority="2"/>
                        <key group="keypadnumber" id="KP8" scan_priority="2"/>
                        <key group="keypadnumber" id="KP9" scan_priority="2"/>
                        <key group="keypadoperators" id="KPSU" scan_priority="2"/>
                        <key group="keypadoperators" id="KPDV" scan_priority="2"/>
                        <key group="keypadoperators" id="KPAD" scan_priority="2"/>
                        <key group="keypadoperators" id="KPMU" scan_priority="2"/>
                        <key group="directions" id="LEFT" scan_priority="1"/>
                        <key group="directions" id="RGHT" scan_priority="1"/>
                        <key group="directions" id="UP" scan_priority="1"/>
                        <key group="directions" id="DOWN" scan_priority="1"/>
                        <key group="editing" id="INS"/>
                        <key group="editing" id="DELE"  label='Del' image=''/>
                        <key group="editing" id="HOME"/>
                        <key group="editing" id="END"/>
                        <key group="editing" id="PGUP"/>
                      <key group="editing" id="PGDN"/>

                        <key group="bottomrow" id="ESC"/>
                        <key group="fkeys" id="F1.rows_of_six"/>
                        <key group="fkeys" id="F2.rows_of_six"/>
                        <key group="fkeys" id="F3.rows_of_six"/>
                        <key group="fkeys" id="F4.rows_of_six"/>
                        <key group="fkeys" id="F5.rows_of_six"/>
                        <key group="fkeys" id="F6.rows_of_six"/>
                        <key group="fkeys" id="F7.rows_of_six"/>
                        <key group="fkeys" id="F8.rows_of_six"/>
                        <key group="fkeys" id="F9.rows_of_six"/>
                        <key group="fkeys" id="F12.rows_of_six"/>
                        <key group="fkeys" id="F10.rows_of_six"/>
                        <key group="fkeys" id="F11.rows_of_six"/>
                        <key group="editing" id="Prnt" scan_priority="1"/>
                        <key group="editing" id="Pause" scan_priority="1"/>
                        <key group="editing" id="Scroll" scan_priority="1"/>
                    </panel>
                    <!--
                    <panel layer="utils" filename="Compact-Utils.svg" border="2">
                        <key group='snippets' id='m0'/>
                        <key group='snippets' id='m1'/>
                        <key group='snippets' id='m2'/>
                        <key group='snippets' id='m3'/>
                        <key group='snippets' id='m4'/>
                        <key group='snippets' id='m5'/>
                        <key group='snippets' id='m6'/>
                        <key group='snippets' id='m7'/>
                        <key group='snippets' id='m8'/>
                        <key group='snippets' id='m9'/>
                        <key group='snippets' id='m10'/>
                        <key group='snippets' id='m11'/>
                        <key group='snippets' id='m12'/>
                        <key group='snippets' id='m13'/>
                        <key group='snippets' id='m14'/>
                        <key group='snippets' id='m15'/>
                        <key group='bottomrow' id='quit' scan_priority="1"/>
                        <key group='bottomrow' id='settings' scan_priority="1"/>
                    </panel>-->
                </panel>

            </box>

            <!--- click helpers -->
            <!--
            <panel id="click" filename="Compact-Alpha.svg" >
                <key group='click' id='middleclick'/>
                <key group='click' id='secondaryclick'/>
                <key group='click' id='doubleclick'/>
                <key group='click' id='dragclick'/>
                <key group='click' id='hoverclick.bottom-row' unlatch_layer="false"/>
            </panel>-->

            <!--- side bar -->
            <panel id="paneswitch" filename="Compact-Alpha.svg">
                <box compact="true" orientation='vertical'>
                    <panel group='nowordlist'>
                        <!-- <key group='bottomrow' id='hide'/> -->
                        <box orientation='vertical'>
                            <box orientation="horizontal" expand="false">
                              <!-- <key group="bottomrow" id="showclick"/> -->
                              <!-- <key group="bottomrow" id="move"/> -->
                            </box>
                            <!-- <key group="bottomrow" id="layer0" show_active="false" scan_priority="3"/> -->
                            <!-- <key group="bottomrow" id="layer1" scan_priority="3"/> -->
                            <!-- <key group="bottomrow" id="layer2" scan_priority="3"/> -->
                        </box>
                    </panel>
                    <panel group='wordlist'>
                        <box orientation='vertical'>
                          <!--
                            <key group='sidebar' id='move' svg_id='move.wordlist' expand='false' label_margin='2.5'/>
                            <key group='sidebar' id='showclick' svg_id='showclick.wordlist' label_margin='2' expand='false'/>
                            <key group='bottomrow' id='layer0' show_active="false" svg_id='layer0.wordlist' scan_priority='3'/>
                            <key group='bottomrow' id='layer1' svg_id='layer1.wordlist' scan_priority='3'/>
                            <key group="bottomrow" id="layer2" svg_id='layer2.wordlist' scan_priority="3"/>
                          -->
                      </box>
                    </panel>
                </box>
            </panel>

        </box>
    </box>
</keyboard>
EOF
chmod 644 /usr/share/onboard/layouts/Compact.onboard

# Ensure that the input-event-source is set to GTK as
# the onboard keyboard will not work on 24.04 otherwise
runuser -u chrome dbus-launch gsettings set org.onboard.keyboard input-event-source 'GTK'
fi

# Update the os_release config
RELEASE=$(lsb_release --release --short)
set_os2borgerpc_config _os_release "$RELEASE"
os2borgerpc_push_config_keys _os_release

rm --force $PREVIOUS_STEP_DONE

touch /etc/os2borgerpc/third_24_upgrade_step_done
