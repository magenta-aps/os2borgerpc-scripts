#!/usr/bin/env bash
#
#   Takes one boolean parameter. A checked box will enable automatic login
#   while an unchecked one will disable it.  

set -ex

if [ "$1" = "False" ]
then
    # Disable autmatic login
    if id -nG user | grep -qw nopasswdlogin
    then
        deluser user nopasswdlogin
    fi
    sed -i "/autologin-user/d" /etc/lightdm/lightdm.conf
else
    # Enable automatic login
    adduser user nopasswdlogin
    if ! grep -q -- "autologin-user=user" /etc/lightdm/lightdm.conf; then
			cat <<- EOF >> /etc/lightdm/lightdm.conf
				autologin-user-timeout=10
				autologin-user=user
			EOF
    fi
fi