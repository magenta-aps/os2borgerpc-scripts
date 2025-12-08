#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2025 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen
#
# Install Splashtop Streamer

set -x

DEB_FILE=$1
GATEWAY=$2
DEPLOY_CODE=$3

apt-get update
# Remove possible old versions of splashtop-streamer
apt-get remove --assume-yes splashtop-streamer || true
# Install Splashtop Streamer via apt-get
apt-get install --assume-yes "$DEB_FILE"

# Configure Splashtop Streamer
splashtop-streamer config -sec_opt=0

# Deploy with the supplied gateway and code
splashtop-streamer deploy "$GATEWAY" "$DEPLOY_CODE"
