#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2024 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch, Andreas Poulsen

OVERRIDE_KERNEL_VERSION="$1"
REQUESTED_KERNEL_VERSION="$2"  # E.g.: 5.15.0-84-generic

[ "$OVERRIDE_KERNEL_VERSION" = "True" ] && [ -z "$REQUESTED_KERNEL_VERSION" ] && echo "A kernel version must be specified. Exiting." && exit 1

export DEBIAN_FRONTEND=noninteractive
GRUB_DEFAULTS="/etc/default/grub"
GRUB_CONFIG="/boot/grub/grub.cfg"
GRUB_CONFIG_ENTRIES="/etc/grub.d/10_linux"
# NOTE: Question: Should we also install and pin linux-modules (not extra)? If it's a dependency it shouldn't be necessary
PKGS="linux-image-$REQUESTED_KERNEL_VERSION linux-modules-extra-$REQUESTED_KERNEL_VERSION linux-headers-$REQUESTED_KERNEL_VERSION"

set -x

echo "The currently active kernel is:"
uname -r

echo "Listing installed kernels:"

dpkg -l | grep ^ii | grep --invert-match linux-image-generic | grep linux-image

echo "Show relevant setting before changing it:"
grep "GRUB_DEFAULT=" $GRUB_DEFAULTS

if [ "$OVERRIDE_KERNEL_VERSION" = "False" ]; then
  echo "Reset the auto-selected kernel to be the system default (ie. the one most recent version available)."
  sed --in-place "s/GRUB_DEFAULT=.*/GRUB_DEFAULT=0/" $GRUB_DEFAULTS
  echo "No longer ensure that the specified kernel $OVERRIDE_KERNEL_VERSION is kept installed:"
  # shellcheck disable=SC2086  # We want word-splitting
  apt-mark unhold $PKGS
  # Restore restrictions on selecting anything but the default kernel, by removing "--unrestricted" from the entries
  # Restrict "Advanced options"
  sed --in-place --regexp-extended 's/(echo "submenu.*) --unrestricted \{"/\1 \{"/' $GRUB_CONFIG_ENTRIES
  # Restrict entries within advanced options
  # shellcheck disable=SC2016 # We don't want the $ expanded
  sed --in-place --regexp-extended 's/(menuentry '\''\$\(echo "\$title.*) --unrestricted (\{.*)/\1 \2/' $GRUB_CONFIG_ENTRIES
else

  # If the kernel version isn't already installed: Attempt to install it
  if ! dpkg -l | grep ^ii | grep --quiet "$REQUESTED_KERNEL_VERSION"; then
    # Install the kernel version
    apt-get update
    # shellcheck disable=SC2086  # We want word-splitting
    if ! apt-get install --assume-yes $PKGS; then
      echo "Failed to install the specified kernel. Exiting."
      exit 1
    fi
  fi

  # Ensure the chosen kernel version can be selected without a password prompt, by appending "--unrestricted" to the entries

  # Unrestrict "Advanced options"
  # Line to match: echo "submenu '$(gettext_printf "Advanced options for %s" "${OS}" | grub_quote)' \$menuentry_id_option 'gnulinux-advanced-$boot_device_id' {"
  if ! grep --quiet 'echo "submenu.* --unrestricted' $GRUB_CONFIG_ENTRIES; then  # Idempotency check
    sed --in-place --regexp-extended 's/(echo "submenu.*) \{"/\1 --unrestricted \{"/' $GRUB_CONFIG_ENTRIES
  fi

  # Unrestrict entries within Advanced options
  # Line to match: echo "menuentry '$(echo "$title" | grub_quote)' ${CLASS} \$menuentry_id_option 'gnulinux-$version-$type-$boot_device_id' {" | sed "s/^/$submenu_indentation/"
  # shellcheck disable=SC2016 # We don't want the $ expanded
  if ! grep --quiet 'menuentry '\''\$(echo "\$title.* --unrestricted' $GRUB_CONFIG_ENTRIES; then  # Idempotency check
    sed --in-place --regexp-extended 's/(menuentry '\''\$\(echo "\$title.*) (\{".*)/\1 --unrestricted \2/' $GRUB_CONFIG_ENTRIES
  fi

  # This 1 below assumes "Advanced options" is the second item in the list (it's zero indexed)
  # The default language of our GRUB appears to be Danish in 20.04 and English in 22.04, and this affects what the
  # menu entries are called, so using indexes works regardless of locale
  # Unfortunately index can't be used in the advanced submenu because the index depends on whether there are newer or older versions of the kernel and how many there are
  # Additionally indexes here may change as old kernels are removed and new ones are added
  if grep --quiet "med Linux" $GRUB_CONFIG; then
    sed --in-place "s/GRUB_DEFAULT=.*/GRUB_DEFAULT=\"1>Ubuntu, med Linux $REQUESTED_KERNEL_VERSION\"/" $GRUB_DEFAULTS
  else
    sed --in-place "s/GRUB_DEFAULT=.*/GRUB_DEFAULT=\"1>Ubuntu, with Linux $REQUESTED_KERNEL_VERSION\"/" $GRUB_DEFAULTS
  fi

  # Also make apt hold the relevant packages for the kernel so they arent't automatically deleted during future updates
  # shellcheck disable=SC2086  # We want word-splitting
  apt-mark hold $PKGS
fi

# Now update GRUB with the new settings
update-grub

echo "Show full GRUB config after:"
cat $GRUB_DEFAULTS
