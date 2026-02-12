#!/usr/bin/env sh
#
# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Marcus Funch
#
# Based on:
# https://documentation.ubuntu.com/server/how-to/security/install-a-root-ca-certificate-in-the-trust-store/
#
# Note from the above link:
# > It is important that the certificate file has the .crt extension, otherwise it will not be processed.

# Removes the argument number that we currently add in front of file names
restore_original_filename() {
  basename "$1" | sed "s/[^_]*_//"
}

set -x

# Check that all files passed are CRT files
for F in "$@"; do
  if [ -n "$F" ]; then
    if ! echo "$F" | grep --ignore-case --fixed-strings ".crt"; then
      echo "Certificate must be a .crt file. Exiting."
      exit 1
    fi
  fi
done

# Copy your certificates to the local CA certificates directory
for F in "$@"; do
  if [ -n "$F" ]; then
    cp "$F" "/usr/local/share/ca-certificates/$(restore_original_filename "$F")"
  fi
done

# Add the certificate to your trust store
update-ca-certificates

# Verify that your certificates are in PEM format (that they were added successfully)
for F in "$@"; do
  if [ -n "$F" ]; then
    FILE="$(restore_original_filename "$F")"
    find /etc/ssl/certs/ -iname "${FILE%.*}*" # Removing the extension dynamically
  fi
done
