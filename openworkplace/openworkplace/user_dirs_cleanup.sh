#!/usr/bin/env sh

# SPDX-FileCopyrightText: 2026 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Andreas Poulsen

set -x

ACTIVATE=$1

CLEANUP_D_FILE="/usr/share/os2borgerpc/bin/user-cleanup.d/600-delete-user-dirs"

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

if [ ! -d "$(dirname $CLEANUP_D_FILE)" ]; then
  echo "This computer does not support user-cleanup.d files. Exiting without doing anything."
  exit 0
fi

if [ "$ACTIVATE" != "True" ]; then
  rm --force $CLEANUP_D_FILE
  exit 0
fi

cat << EOF > $CLEANUP_D_FILE
#!/usr/bin/env sh

# We also need to delete the user-dirs files to ensure that the
# directories are recreated correctly
rm --force --recursive /home/user/* /home/user/.config/user-dirs.*
EOF

chmod 700 $CLEANUP_D_FILE
