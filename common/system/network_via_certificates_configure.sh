#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

WIFI_NAME="$1"
ETHERNET_NAME="$2"
WIFI_IFNAME="$3"
ETHERNET_IFNAME="$4"
SSID="$5"
KEYMGMT="$6"
EAP="$7"
IDENTITY="$8"
ROOT_CERT_NAME="$9"
CLIENT_CERT_NAME="${10}"
CERT_KEY_NAME="${11}"
CERT_KEY_PASSWORD="${12}"
CONNECT="${13}"

ROOT_CERT_DIR="/etc/ssl/certs"
NETWORK_CERT_DIR="/etc/networkmanagement"

# Ensure that the certificate names have the correct file ending
ROOT_CERT_PATH="$ROOT_CERT_DIR/$(echo "$ROOT_CERT_NAME" | cut --delimiter "." --fields 1).pem"
CLIENT_CERT_PATH="$NETWORK_CERT_DIR/$(echo "$CLIENT_CERT_NAME" | cut --delimiter "." --fields 1).crt"
CERT_KEY_PATH="$NETWORK_CERT_DIR/$(echo "$CERT_KEY_NAME" | cut --delimiter "." --fields 1).key"

if [ ! -f "$ROOT_CERT_PATH" ]; then
  echo "The specified root certificate could not be found. Exiting."
  exit 1
fi
if [ ! -f "$CLIENT_CERT_PATH" ]; then
  echo "The specified client certificate could not be found. Exiting."
  exit 1
fi
if [ ! -f "$CERT_KEY_PATH" ]; then
  echo "The specified certificate key could not be found. Exiting."
  exit 1
fi

set -x

# Cleanup earlier connection attempts
nmcli connection delete "$WIFI_NAME" 2> /dev/null

# Add the wifi connection
nmcli connection add type wifi \
      con-name "$WIFI_NAME" \
      ifname "$WIFI_IFNAME" \
      ssid "$SSID" \
      wifi-sec.key-mgmt "$KEYMGMT" \
      802-1x.eap "$EAP" \
      802-1x.identity "$IDENTITY" \
      802-1x.ca-cert "$ROOT_CERT_PATH" \
      802-1x.client-cert "$CLIENT_CERT_PATH" \
      802-1x.private-key "$CERT_KEY_PATH" \
      802-1x.private-key-password "$CERT_KEY_PASSWORD"

# Configure the ethernet if they specified a name
if [ -n "$ETHERNET_NAME" ]; then
  # Cleanup earlier connection attempts
  nmcli connection delete "$ETHERNET_NAME" 2> /dev/null

  # Add the ethernet connection
  nmcli connection add type ethernet \
        con-name "$ETHERNET_NAME" \
        ifname "$ETHERNET_IFNAME" \
        802-1x.eap "$EAP" \
        802-1x.identity "$IDENTITY" \
        802-1x.ca-cert "$ROOT_CERT_PATH" \
        802-1x.client-cert "$CLIENT_CERT_PATH" \
        802-1x.private-key "$CERT_KEY_PATH" \
        802-1x.private-key-password "$CERT_KEY_PASSWORD"
fi

if [ "$CONNECT" = "True" ]; then
  # Connect to the wireless network
  nmcli connection up "$WIFI_NAME"
fi
