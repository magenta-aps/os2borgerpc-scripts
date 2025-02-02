#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2023 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0
#
# SPDX-FileContributor: Marcus Funch

header() {
  MSG=$1
  printf "\n\n\n%s\n\n\n" "### $MSG: ###"
}

text() {
  MSG=$1
  printf "\n%s\n" "### $MSG: ###"
}

PRINCH_PPD="/usr/share/ppd/princh/princheu.ppd"
PRINTERS_CONF="/etc/cups/printers.conf"

text "Check the version of hplip"
dpkg -l hplip | cat  # Piping to cat because otherwise it seems to open "less"

text "Info about currently added printers"
lpstat -v

text "Global standard paper size is set to"
# "Paperconf prints  the  name  of the
# the  system-  or  user-specified paper, obtained by looking in order at
# the PAPERSIZE environment variable, at the contents of the file  speci-
# fied by the PAPERCONF environment variable, at the contents of /etc/pa-
# persize or by using letter as a fall-back value if none  of  the  other
# alternatives are successful"
paperconf
# The related command "paperconfig" can set the default paper size.

text "These options are set for all printers according to lpoptions:"
lpoptions -l

header "Current printer settings for all added printers"

for printer in $(lpstat -a | cut  --delimiter ' ' --fields 1); do
  text "The printer \"$printer\" has this configuration according to lpstat:"
  lpstat -slp "$printer"

  text "The printer \"$printer\" has this configuration in its PPD, if it exists"
  lpstat -slp "$printer" | grep "Interface" | cut --delimiter ' ' --fields 2 | xargs --no-run-if-empty cat
  echo ""
done

header "Print contents of $PRINTERS_CONF, if it exists"
[ -f $PRINTERS_CONF ] && cat $PRINTERS_CONF

# PRINCH RELATED

dpkg -l | grep princh

header "Print contents of $PRINCH_PPD, if it exists"
[ -f $PRINCH_PPD ] && cat $PRINCH_PPD
