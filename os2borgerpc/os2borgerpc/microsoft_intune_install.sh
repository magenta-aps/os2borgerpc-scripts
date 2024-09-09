#! /usr/bin/env sh

# This script is written based off the following guide:
# https://learn.microsoft.com/en-us/mem/intune/user-help/microsoft-intune-app-linux

# Because it adds a repo it's currently hardcoded to specific Ubuntu versions!: 22.04 and 24.04

export DEBIAN_FRONTEND=noninteractive

PKG="intune-portal"
UBUNTU_VERSION=$(lsb_release --release --short)

ACTIVATE="$1"

if [ "$ACTIVATE" = "True" ]; then

    curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.gpg
    install -o root -g root -m 644 microsoft.gpg /usr/share/keyrings/
    if [ "$UBUNTU_VERSION" = "22.04" ]; then
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/22.04/prod jammy main" > /etc/apt/sources.list.d/microsoft-ubuntu-jammy-prod.list
    elif [ "$UBUNTU_VERSION" = "24.04" ]; then
        echo "Warning: As of 2024-09-05 intune-portal hasn't yet been made available for 24.04 (check the link in the comment above), so this might fail."
        echo "deb [arch=amd64 signed-by=/usr/share/keyrings/microsoft.gpg] https://packages.microsoft.com/ubuntu/24.04/prod noble main" > /etc/apt/sources.list.d/microsoft-ubuntu-noble-prod.list
    else
        echo "The Ubuntu version you're running isn't currently supported. Exiting."
        exit 1
    fi
    rm microsoft.gpg
    apt-get update
    apt-get install --assume-yes $PKG
else
    # Not currently deleting the added source repo
    apt-get remove --assume-yes $PKG
    rm /usr/share/keyrings/microsoft.gpg
fi
