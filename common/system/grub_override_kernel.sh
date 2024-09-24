#! /usr/bin/env sh

OVERRIDE_KERNEL_VERSION="$1"
REQUESTED_KERNEL_VERSION="$2"  # E.g.: 5.15.0-84-generic

[ "$OVERRIDE_KERNEL_VERSION" = "True" ] && [ -z "$REQUESTED_KERNEL_VERSION" ] && echo "A kernel version must be specified. Exiting." && exit 1

export DEBIAN_FRONTEND=noninteractive
GRUB_DEFAULTS="/etc/default/grub"
GRUB_CONFIG="/boot/grub/grub.cfg"
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

echo "Show full GRUB config after:"
cat $GRUB_DEFAULTS

# Now update GRUB with the new settings
update-grub
