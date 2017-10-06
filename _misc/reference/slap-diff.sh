#!/bin/bash

SCD="$(cd "$(dirname "$0")" && pwd)"

docker exec zmdocker_ldap_1 su - zimbra -c 'source ~/bin/zmshutil; zmsetvars; ldapsearch -x -H "$ldap_master_url" -D "$zimbra_ldap_userdn" -w "$zimbra_ldap_password"' | perl -p0e 's/\n //g' > /tmp/SLDAP.txt

GetAllDn()
{
   grep '^dn:' -h "$SCD/SLDAP.txt" /tmp/SLDAP.txt | sort | uniq 
}

DumpDn()
{
   local file="$1"; shift;
   local dn="$1"; shift;
   local dn_reg="$(echo "$dn" | sed -e 's,[/],\\\/,g')"

   echo "# $dn"
   echo "$dn"
   sed -n "/^${dn_reg}/,/^$/p" "$file" | sort | sed -e '/^${dn_reg}/d' -e '/^$/d'
   echo
}

RemoveTrivialDiff()
{
   sed \
      -e 's/^\(zimbraCreateTimestamp: \).*/\1DDDDD/' \
      -e 's/^\(zimbraPasswordModifiedTime: \).*/\1DDDDD/' \
      -e 's/^\(zimbraZimletVersion: \).*/\1DDDDD/' \
      -e 's/^\(zimbraAuthTokenKey: \).*/\1DDDDD/' \
      -e 's/^\(zimbraZimletPriority: \).*/\1DDDDD/' \
      -e 's/^\(zimbraCsrfTokenKey: \).*/\1DDDDD/' \
      -e 's/^\(zimbraSshPublicKey: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersion: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersionBuild: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersionMajor: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersionMinor: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersionMicro: \).*/\1DDDDD/' \
      -e 's/^\(zimbraServerVersionType: \).*/\1DDDDD/' \
      \
      -e 's/^\(zimbraCertAuthorityCertSelfSigned:: \).*/\1DDDDD/' \
      -e 's/^\(zimbraCertAuthorityKeySelfSigned:: \).*/\1DDDDD/' \
      -e 's/^\(zimbraSSLCertificate:: \).*/\1DDDDD/' \
      -e 's/^\(zimbraSSLPrivateKey:: \).*/\1DDDDD/' \
      -e 's/^\(userPassword:: \).*/\1DDDDD/' \

}

diff -w -u \
   <(GetAllDn | while read dn; do DumpDn "$SCD/SLDAP.txt" "$dn"; done | RemoveTrivialDiff) \
   <(GetAllDn | while read dn; do DumpDn "/tmp/SLDAP.txt" "$dn"; done | RemoveTrivialDiff)

rm -f /tmp/SLDAP.txt
