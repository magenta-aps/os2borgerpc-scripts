#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2017 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Danni Als, Andreas Poulsen

set -ex

if [ -d "/root/.local/share/pipx/venvs/os2borgerpc-client" ]; then
  pipx upgrade os2borgerpc-client
else
  pip3 install --upgrade os2borgerpc-client
fi
