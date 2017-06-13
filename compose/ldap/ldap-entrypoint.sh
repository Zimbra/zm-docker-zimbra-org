#!/bin/bash

if [ ! -f /opt/zimbra-installed ]; then
	cd /opt/zimbra-build
	./install.sh -s < /zimbra/install-commands

	result=$?
	if [ $result -eq 0 ]; then
		echo "INSTALL SUCCEEDED"
	else
		echo "INSTALL FAILED"
        exit 1
	fi

    /opt/zimbra/libexec/zmsetup.pl -c /zimbra/install-config

	result=$?
	if [ $result -eq 0 ]; then
		touch /opt/zimbra-installed
		echo "CONFIG SUCCEEDED"
	else
		echo "CONFIG FAILED"
        exit 1
	fi
fi

if [ -f /opt/zimbra-installed ]; then
    sudo -u zimbra /opt/zimbra/bin/zmcontrol start
	tail -f /opt/zimbra/log/*
else
    echo "Zimbra LDAP not installed - failing."
    exit 1
fi

# TODO export ldap port 389
