#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2021 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Søren Howe Gersager, Emil Nordahn Andersen, Andreas Poulsen

# Overwrite the Libreoffice registrymodifications.xcu config with our own version.
# Takes two checkboxes as input. The first disables Tip of the day and displaying the changelog when you start the app.
# The second changes the default fileformats to Microsoft's (.docx, .pptx, .xlsx).

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

REMOVE_TIP_OF_THE_DAY=$1
SET_FORMATS_TO_MICROSOFTS=$2

CONFIG_DIR="/home/.skjult/.config/libreoffice/4/user/"
FILE_PATH=$CONFIG_DIR"registrymodifications.xcu"

mkdir --parents $CONFIG_DIR

rm --force $FILE_PATH

cat << EOF >> $FILE_PATH
<?xml version="1.0" encoding="UTF-8"?>
<oor:items xmlns:oor="http://openoffice.org/2001/registry" xmlns:xs="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
EOF

if [ "$REMOVE_TIP_OF_THE_DAY" == "True" ]; then
  cat << EOF >> $FILE_PATH
    <item oor:path="/org.openoffice.Office.Common/Misc"><prop oor:name="ShowTipOfTheDay" oor:op="fuse"><value>false</value></prop></item>
    <item oor:path="/org.openoffice.Setup/Product"><prop oor:name="ooSetupLastVersion" oor:op="fuse"><value>30.0</value></prop></item>
EOF
fi

if [ "$SET_FORMATS_TO_MICROSOFTS" == "True" ]; then
  cat << EOF >> $FILE_PATH
    <item oor:path="/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['com.sun.star.text.TextDocument']"><prop oor:name="ooSetupFactoryDefaultFilter" oor:op="fuse"><value>MS Word 2007 XML</value></prop></item>
    <item oor:path="/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['com.sun.star.sheet.SpreadsheetDocument']"><prop oor:name="ooSetupFactoryDefaultFilter" oor:op="fuse"><value>Calc MS Excel 2007 XML</value></prop></item>
    <item oor:path="/org.openoffice.Setup/Office/Factories/org.openoffice.Setup:Factory['com.sun.star.presentation.PresentationDocument']"><prop oor:name="ooSetupFactoryDefaultFilter" oor:op="fuse"><value>Impress MS PowerPoint 2007 XML</value></prop></item>
EOF
fi

printf "</oor:items>"  >> $FILE_PATH
