#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Carsten Agger, Marcus Funch, Sebastian Heiberg
#
# This script sets printer options in various different ways based on what seems to work.
# lpadmin makes changes in the PPD of the specified printer
# lpoptions creates a config file in /etc/cups/lpoptions. It's global for all printers.
# Sometimes it appears as if lpoptions settings take precedence over lpadmin (PPD) settings. GNOME Settings appears to set options via lpadmin (PPD).
# Papersize is globally configured for all printers via paperconfig - and it's also set via lpoptions AND lpadmin to hopefully cover all bases.
# Orientation modifies /etc/cups/printers.conf, which should be shared by all printers. When set via lpadmin or lpoptions it may not work, at least not according to GNOME Settings for a given printer.

set -ex

PRINTER="$1"
PAGE_SIZE="$2"
COLOR="$3"
DUPLEX="$4"
ORIENTATION="$5"

CUPS_PRINTER_CONF="/etc/cups/printers.conf"

lower() {
    echo "$@" | tr '[:upper:]' '[:lower:]'
}

if [ -n "$PAGE_SIZE" ]; then
    # lpoptions can also take a printer as an argument, but when setting options it seems to have no effect anyway - it's globally configured for all printers
    lpoptions -o PageSize="$PAGE_SIZE"

    # This sets the papersize in the PPD if there is one - specifically the value *DefaultPageSize in /etc/cups/ppd/YourPrinter.ppd (and additionally in /var/snap/cups/common/etc/cups/ppd/YourPrinter.ppd)
    # Okular ignores Paperconfig and lpoptions when printing, but it respects this one
    lpadmin -p "$PRINTER" -o media="$PAGE_SIZE"

    # Additionally globally set the paper size to that size as well
    paperconfig --paper "$PAGE_SIZE"
fi

if [ -n "$COLOR" ]; then
    # Some printers may call it ColorModel while others call it DefaultColorModel.
    # Attempt to set both, as it seems that setting a nonexisting option has no effect.
    lpadmin -p "$PRINTER" -o ColorModel="$COLOR" -o DefaultColorModel="$COLOR"

    # Also set the color model globally in case the above has no effect
    lpoptions -o ColorModel="$COLOR" -o DefaultColorModel="$COLOR"

    # A third approach to setting color, as it seemed that sometimes the above weren't enough
    # Lowercasing for case insensitivity
    COLOR_LOWERCASED=$(lower "$COLOR")
    if [ "$COLOR_LOWERCASED" = "rgb" ] || [ "$COLOR_LOWERCASED" = "color" ]; then
      # More info on this option: https://github.com/OpenPrinting/cups/issues/421
      lpadmin -p "$PRINTER" -o print-color-mode-default=color
    else
      lpadmin -p "$PRINTER" -o print-color-mode-default=monochrome
    fi
fi

if [ -n "$DUPLEX" ]; then
    # This effectively writes it to printers.conf for the specific printer
    lpadmin -p "$PRINTER" -o Duplex="$DUPLEX"
fi

if [ -n "$ORIENTATION" ]; then
    # Mapping the requested orientation to the number CUPS expect, which for some reason is 3-indexed.
    # Available orientations: https://www.cups.org/doc/options.html#ORIENTATION

    case $ORIENTATION in
    "Portrait")
        ORIENTATION="3"
        ;;
    "Landscape")
        ORIENTATION="4"
        ;;
    "Reverse landscape")
        ORIENTATION="5"
        ;;
    "Reverse portrait")
        ORIENTATION="6"
        ;;
    esac

    lpadmin -p "$PRINTER" -o "orientation-requested=$ORIENTATION"
    lpoptions -o "orientation-requested=$ORIENTATION"

    # The previous approach to setting orientation - should no longer be needed:
    # NOTE: This currently sets the orientation for ALL connected printers, which may not be ideal in all situations.
    # printers.conf says to not edit it while CUPS is running, so stop it first
    #systemctl stop cups
    ## Delete any occurrence of orientation already in the file, then add it to all printers in the file, each within an XML tag
    #sed --in-place "/orientation-requested [0-9]/d" $CUPS_PRINTER_CONF
    #sed --in-place "/<\/[A-Za-z]\+>/iOption orientation-requested $ORIENTATION" $CUPS_PRINTER_CONF
    #systemctl start cups
fi

echo "Finally list all the settings after the changes, for verification that the changes succeeded:"

echo "These options are set for all printers according to lpoptions"
lpoptions -l

echo "The specified printer has this configuration according to lpstat:"
lpstat -slp "$PRINTER"

echo "Contents of $CUPS_PRINTER_CONF:"
echo "Contents of $CUPS_PRINTER_CONF, if it exists:"
[ -f $CUPS_PRINTER_CONF ] && cat $CUPS_PRINTER_CONF
