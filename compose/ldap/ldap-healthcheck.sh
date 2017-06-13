#!/bin/bash

if [ ! -f /opt/zimbra-installed ]; then
    exit 1
fi

serviceStatus=`sudo -u zimbra /opt/zimbra/bin/zmcontrol status | grep 'ldap ' | awk '{ print $2 }'`

if [ "$serviceStatus" = "Running" ]; then
    exit 0
else
    exit 2
fi
