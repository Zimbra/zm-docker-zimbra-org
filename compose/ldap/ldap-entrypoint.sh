#!/bin/bash

if [ ! -f /opt/zimbra-installed ]; then
	cd /opt/zimbra-build
	./install.sh < /zimbra/install-commands

	result=$?
	if [ $result -eq 0 ]; then
		echo "INSTALL SUCCEEDED"
	else
		echo "INSTALL FAILED"
        exit 1
	fi

    touch /opt/zimbra-installed
fi

if [ -f /opt/zimbra-installed ]; then
    sudo -u zimbra /opt/zimbra/bin/zmcontrol start
	tail -f /opt/zimbra/log/* /var/log/zimbra.log
else
    echo "Zimbra LDAP not installed - failing."
    exit 1
fi
