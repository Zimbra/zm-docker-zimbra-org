#!/bin/bash

SCD="$(cd "$(dirname "$0")" && pwd)"

if [ $# -ne 1 ]
then
   echo "$0: <ldap|mailbox|proxy|mysql|mta>" 1>&2
   exit 1;
fi

M="$1"; shift;

diff -w -u \
   <(docker exec "zmdocker_${M}_1" su - zimbra -c "zmlocalconfig -s" | sort) \
   <(sort "$SCD/LC-${M}_1.txt")
