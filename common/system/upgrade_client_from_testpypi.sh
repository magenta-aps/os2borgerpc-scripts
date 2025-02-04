#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -ex

pip3 install --upgrade --index-url https://test.pypi.org/simple/ --extra-index-url https://pypi.org/simple/ os2borgerpc-client
