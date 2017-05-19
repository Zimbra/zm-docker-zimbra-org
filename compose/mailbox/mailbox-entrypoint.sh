#!/bin/bash

if [ ! -f /opt/zimbra-installed ]; then
	cd /opt/zimbra-build
	./install.sh -s <<-EOF
		y
		y
	    n
		n
		n
		n
		n
	    y
		n
		n
		n
		n
		n
		n
		y
	EOF
    RESULT=$?

    if [ $RESULT -eq 0 ]; then
	    touch /opt/zimbra-installed
        echo "INSTALL SUCCEEDED"
    else
        echo "INSTALL FAILED"
    fi
else
    echo "INSTALLED"
fi

#        1
#        2
#        ldap.f9.engineering
#        4
#        ldapAdminPassword
#        r

