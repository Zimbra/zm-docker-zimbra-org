#!/bin/bash

if [ ! -f /opt/zimbra-installed ]; then
	cd /opt/zimbra-build
	./install.sh -s <<-EOF
		y
		y
		y
		n
		n
		n
		n
		n
		n
		n
		n
		n
		n
		n
		y
		1
		4
		ldapAdminPassword
		r
		a
		y

		y
		no

	EOF
	RESULT=$?

	if [ $RESULT -eq 0 ]; then
		touch /opt/zimbra-installed
		echo "INSTALL SUCCEEDED"
	else
		echo "INSTALL FAILED"
	fi
else
	/opt/zimbra/bin/zmcontrol start
	tail -f /opt/zimbra/log/*
fi
