#!/bin/sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch

UBUNTU_VERSION=$(lsb_release --release --short)
DEFAULT_DM_FILE="/etc/X11/default-display-manager"

pulseaudio_initial_setup() {
    # Hacky workaround to be able to run pactl as root
    # https://stackoverflow.com/a/64932897/1172409
    # Access to pulseaudio will fail if not in the right group
    # note: still has an exit status of 0 if root is already in the group
    adduser --quiet root pulse-access
    # Running a systemwide pulseaudio instance, for pactl
    pulseaudio --system=true 2>/dev/null &
    PID=$!

    # Give the pulseaudio server a bit of time to start
    sleep 5

    # Circumvent a permissions error since it's owned by the pulse user and we
    # can't su to that service user
    chown root:root /var/run/pulse
}

run_pulseaudio_command() {
    # The pulseaudio command to run, force the language output to be in English for e.g. grepping
    XDG_RUNTIME_DIR=/var/run LANG=c $1
}

pulseaudio_cleanup() {
    # Cleanup: Stop the process again, though leave the user in the group
    kill $PID   # This is defined by pulseaudio_initial_setup
    # gpasswd -d root pulse-access
    # Cleanup: Restore permissions to what they were
    chown pulse:pulse /var/run/pulse
}

header() {
    MSG=$1
    printf "\n\n\n%s\n\n\n" "### $MSG ###"
}

text() {
    MSG=$1
    printf "\n%s\n" "### $MSG ###"
}

# TODO: Make this script work on the login screen. At least it's broken in GDM.
if ! get_os2borgerpc_config os2_product | grep --quiet kiosk && [ "$UBUNTU_VERSION" != "20.04" ] && [ "$UBUNTU_VERSION" != "22.04" ]; then # 24.04 and newer
    # Determine the running user
    RUNNING_USERS=$(who)
    if echo "$RUNNING_USERS" | grep --quiet 'superuser'; then
        U="superuser"
    elif echo "$RUNNING_USERS" | grep --quiet 'user'; then
        U="user"
    elif grep --quiet gdm3 $DEFAULT_DM_FILE; then
        U="gdm"
        echo "This script currently does not work on the login screen. Ensure that either Borger (user) or superuser is logged in while it's running."
        exit 1
    elif echo "$RUNNING_USERS" | grep --quiet 'lightdm'; then
        U="lightdm"
        echo "This script currently does not work on the login screen. Ensure that either Borger (user) or superuser is logged in while it's running."
        exit 1
    else
        echo "Failed to identify the current user. Exiting"
        exit 1
    fi

    USER_ID=$(id -u $U)

    text "List of sinks"
    XDG_RUNTIME_DIR=/run/user/$USER_ID pw-cli info all 2>/dev/null | grep 'node.name =' | grep --invert-match 'Dummy\|Freewheel\|Midi' | cut --delimiter='=' --fields 2

    text "Current default output (sink) and input (source) and their current volumes"
    # shellcheck disable=SC2063  # It's no glob
    XDG_RUNTIME_DIR=/run/user/$USER_ID wpctl status --name | sed --quiet '/^Audio/,/^Video/p' | grep '*'

else # Legacy support: pulseaudio without pipewire
    pulseaudio_initial_setup  # To be run before any pulseaudio commands are executed

    text "List of cards"
    run_pulseaudio_command "pactl list cards short" | tr "\t" " "  # Currently the client removes tabs from the log-output, so this is a workaround

    text "Overview of sinks and their volumes and mute status"
    run_pulseaudio_command "pactl list sinks" | grep -E "Sink|State|Name|Description|Mute|Volume"

    text "Default sink"
    # This one works in newer versions of pactl, but not in the one in Ubuntu 20.04 necessarily
    # run_pulseaudio_command "pactl get-default-sink"
    # ...so this is another way:
    run_pulseaudio_command "pactl info" | tail --lines 6

    header "INFO ON BORGERPC AUDIO CONFIG AND PULSEAUDIO CONFIG FILES"

    text "Print contents of current borgerpc pulseaudio config file"
    cat /etc/pulse/default.pa.d/os2borgerpc.pa

    text "Print contents of the previous borgerpc pulseaudio config file"
    cat /etc/pulse/profile.pa.d/os2borgerpc.pa

    text "Print the last lines of the main pulseaudio config file"
    # This file should include a line that makes it load all files from the dir /etc/pulse/profile.pa.d/
    tail --lines 3 /etc/pulse/default.pa

    header "DETAILED INFO"

    text "Detailed info on cards and their profiles and ports"
    run_pulseaudio_command "pactl list cards"

    # Not sure if these are specifically the sinks for the current profile or not?
    text "Detailed info on sinks and their ports (incl. volume, mute status etc.)"
    run_pulseaudio_command "pactl list sinks"

    pulseaudio_cleanup  # To be run after any pulseaudio commands are executed (to cleanup changes by pulseaudio_initial_setup)
fi
