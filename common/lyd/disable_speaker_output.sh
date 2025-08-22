#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# Attempt at disabling speaker output, so only headphones can be used
# Log out after running it

ACTIVATE=$1
SINK_NAME=$2  # Only used/required on 24.04 and later

# Used for the 24.04 solution:
PULSEAUDIO_CONFIG_DIR="/etc/pulse/default.pa.d"
OS2BORGERPC_PULSEAUDIO_CONFIG="$PULSEAUDIO_CONFIG_DIR/os2borgerpc.pa"
SKEL=".skjult"
STARTUP_DIR=/home/$SKEL/.config/autostart/
OS2BORGERPC_24_04_AUDIO_STARTUP_FILE=$STARTUP_DIR/audio_startup.desktop
OS2BORGERPC_24_04_AUDIO_STARTUP_SCRIPT=/usr/share/os2borgerpc/bin/audio_startup.sh
UBUNTU_VERSION="$(lsb_release --release --short)"

if [ "$UBUNTU_VERSION" != "20.04" ] && [ "$UBUNTU_VERSION" != "22.04" ]; then # 24.04 and newer

  if [ "$ACTIVATE" = "True" ]; then

    [ -z "$SINK_NAME" ] && printf "%s\n" "Specifying sink name is required in 24.04. Exiting." && exit 1

    mkdir --parents $PULSEAUDIO_CONFIG_DIR

    # TODO: Test if this solution also works on 22.04 (so only the startup script is 24.04 specific)
    if [ ! -f $OS2BORGERPC_PULSEAUDIO_CONFIG ] || ! grep --quiet analog-output-speaker $OS2BORGERPC_PULSEAUDIO_CONFIG; then  # Idempotency
      cat <<- EOF >> $OS2BORGERPC_PULSEAUDIO_CONFIG
				set-sink-port $SINK_NAME analog-output-speaker
				set-sink-mute $SINK_NAME 1 # analog-output-speaker
EOF
    fi
    # SHARED BLOCK FOR SOUND SCRIPTS IN 24.04 - CURRENTLY NOT KIOSK AS IT CURRENTLY DOES NOT USE PIPEWIRE
    # Run all $OS2BORGERPC_PULSEAUDIO_CONFIG commands at user login with pactl
    mkdir --parents $STARTUP_DIR
    cat <<- EOF > $OS2BORGERPC_24_04_AUDIO_STARTUP_FILE
			[Desktop Entry]
			Type=Application
			Exec=$OS2BORGERPC_24_04_AUDIO_STARTUP_SCRIPT
EOF
    cat <<- EOF > $OS2BORGERPC_24_04_AUDIO_STARTUP_SCRIPT
			#!/usr/bin/env sh

			while IFS= read -r line; do
			  # remove comments as they break xargs
			  echo "\$line" | sed "s/#.*//" | xargs pactl
			done < $OS2BORGERPC_PULSEAUDIO_CONFIG
EOF
    chmod +x $OS2BORGERPC_24_04_AUDIO_STARTUP_FILE $OS2BORGERPC_24_04_AUDIO_STARTUP_SCRIPT
    # END SHARED BLOCK FOR SOUND SCRIPTS IN 24.04
  else # Stop disabling speakers
    if [ -f $OS2BORGERPC_PULSEAUDIO_CONFIG ]; then
      sed --in-place --expression "/analog-output-speaker/d" $OS2BORGERPC_PULSEAUDIO_CONFIG
    fi
  fi
else  # Legacy support: pulseaudio without pipewire
  if [ "$ACTIVATE" = "True" ]; then
    # Renaming the speaker configuration to anything to make the speaker inaccessible
    # https://askubuntu.com/questions/715016/disable-port-in-pulseaudio
    mv /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf.backup
  else
    mv /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf.backup /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf
  fi
fi
