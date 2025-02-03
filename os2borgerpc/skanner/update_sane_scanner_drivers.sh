#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Søren Howe Gersager, Heini Leander Ovason
#
# Updates Sane scanner drivers. http://sane-project.org/

add-apt-repository --yes ppa:sane-project/sane-release
apt-get update
apt install --assume-yes libsane
