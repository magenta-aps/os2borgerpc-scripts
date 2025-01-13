#!/usr/bin/env sh

set -ex

pip3 install --upgrade --index-url https://test.pypi.org/simple/ --extra-index-url https://pypi.org/simple/ os2borgerpc-client
