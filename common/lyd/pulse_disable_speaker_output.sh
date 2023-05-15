#! /usr/bin/env sh

# Attempt at disabling speaker output, so only headphones can be used
# Log out after running it

ACTIVATE=$1

if [ "$ACTIVATE" = 'True' ]; then
  # Renaming the speaker configuration to anything to make the speaker inaccessible
  # https://askubuntu.com/questions/715016/disable-port-in-pulseaudio
  mv /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf.backup
else
  mv /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf.backup /usr/share/pulseaudio/alsa-mixer/paths/analog-output-speaker.conf
fi
