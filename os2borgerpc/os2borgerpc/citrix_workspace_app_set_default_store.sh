#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2022 Magenta ApS <info@magenta.dk>
#
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPDX-FileContributor: Heini Leander Ovason

set -x

if get_os2borgerpc_config os2_product | grep --quiet kiosk; then
  echo "Dette script er ikke designet til at blive anvendt på en kiosk-maskine."
  exit 1
fi

STORE_DIR=/home/.skjult/.ICAClient/cache/Stores

STORE_NAME=$1
DEFAULT_STORE=$2

if [ -z "$DEFAULT_STORE" ] && [ -z "$STORE_NAME" ]; then
    echo "WARNING: Missing argument(s). Not able to set default citrix store."
    exit 1
fi

mkdir --parents "$STORE_DIR"

if [ ! -f "$STORE_DIR/StoreCache.ctx" ]; then
    touch "$STORE_DIR/StoreCache.ctx"
fi

cat << EOF > "$STORE_DIR/StoreCache.ctx"
<StoreCache>
    <DefaultStore>$DEFAULT_STORE</DefaultStore>
    <ReconnectOnLogon>False</ReconnectOnLogon>
    <ReconnectOnLaunchOrRefresh>False</ReconnectOnLaunchOrRefresh>
    <SharedUserMode>False</SharedUserMode>
    <FullscreenMode>0</FullscreenMode>
    <SelfSelection>True</SelfSelection>
    <SessionWindowedMode>False</SessionWindowedMode>
    <VisibleStores>
        <Store name="$STORE_NAME" type="DS" gatewaystore="" internalbeacon="" externalbeacon="" storeservice="OnPremStore">$DEFAULT_STORE</Store>
    </VisibleStores>
</StoreCache>
EOF
