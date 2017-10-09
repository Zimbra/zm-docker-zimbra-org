#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

#use lib '/code/_base/';
use lib '/opt/zimbra/common/lib/perl5';

use Zimbra::DockerLib;

########################################################

my $LDAP_MASTER_PASSWORD = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD   = Secret("ldap.root_password");
my $LDAP_NGINX_PASSWORD  = Secret("ldap.nginx_password");

########################################################

chomp( my $THIS_HOST = `hostname -f` );

my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_HOST        = "zmc-ldap";
my $LDAP_PORT        = 389;
my $MAILBOX_HOST     = "zmc-mailbox";

########################################################

my $ADMIN_PORT = 7071;
my $HTTPS_PORT = 8443;
my $HTTP_PORT  = 8080;
my $IMAPS_PORT = 7993;
my $IMAP_PORT  = 7143;
my $POP3S_PORT = 7995;
my $POP3_PORT  = 7110;

my $PROXY_ADMIN_PORT = 9071;
my $PROXY_HTTPS_PORT = 443;
my $PROXY_HTTP_PORT  = 80;
my $PROXY_IMAPS_PORT = 993;
my $PROXY_IMAP_PORT  = 143;
my $PROXY_POP3S_PORT = 995;
my $PROXY_POP3_PORT  = 110;

########################################################

EntryExec(
   $THIS_HOST,
   [
      { wait_for => { service => $LDAP_HOST, }, },
      { wait_for => { service => $MAILBOX_HOST, }, },
      {
         desc => "Configuring",    # FIXME - split
         exec => {
            user   => "zimbra",
            script => <<"END_BASH"
echo "## Local Config"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   "zimbra_uid=\$(id -u zimbra)" \\
   "zimbra_gid=\$(id -g zimbra)" \\
   "zimbra_server_hostname=$THIS_HOST" \\
   "zimbra_user=zimbra" \\
   'ldap_starttls_supported=1' \\
   'zimbra_zmprov_default_to_ldap=true' \\
   'ldap_master_url=ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT' \\
   'ldap_url=ldap://$LDAP_HOST:$LDAP_PORT' \\
   'zimbra_ldap_password=$LDAP_MASTER_PASSWORD' \\
   'ldap_root_password=$LDAP_ROOT_PASSWORD' \\
   'ssl_allow_untrusted_certs=true' \\
   'ssl_allow_mismatched_certs=true' \\
   'ldap_nginx_password=$LDAP_NGINX_PASSWORD' \\

echo "## Server Level Config"
V=( \$(/opt/zimbra/bin/zmcontrol -v | grep -o '[0-9A-Za-z_]*') )
/opt/zimbra/bin/zmprov -r -m -l cs '$THIS_HOST'
/opt/zimbra/bin/zmprov -r -m -l ms '$THIS_HOST' \\
   zimbraIPMode ipv4 \\
   zimbraServiceInstalled stats \\
   zimbraServiceEnabled stats \\
   zimbraServiceInstalled proxy \\
   zimbraServiceEnabled proxy \\
   zimbraServiceInstalled memcached \\
   zimbraServiceEnabled memcached \\
   \\
   zimbraAdminPort '$ADMIN_PORT' \\
   zimbraAdminProxyPort '$PROXY_ADMIN_PORT' \\
   zimbraImapBindPort '$IMAP_PORT' \\
   zimbraImapProxyBindPort '$PROXY_IMAP_PORT' \\
   zimbraImapSSLBindPort '$IMAPS_PORT' \\
   zimbraImapSSLProxyBindPort '$PROXY_IMAPS_PORT' \\
   zimbraMailPort '$HTTP_PORT' \\
   zimbraMailProxyPort '$PROXY_HTTP_PORT' \\
   zimbraMailSSLPort '$HTTPS_PORT' \\
   zimbraMailSSLProxyPort '$PROXY_HTTPS_PORT' \\
   zimbraPop3BindPort '$POP3_PORT' \\
   zimbraPop3ProxyBindPort '$PROXY_POP3_PORT' \\
   zimbraPop3SSLBindPort '$POP3S_PORT' \\
   zimbraPop3SSLProxyBindPort '$PROXY_POP3S_PORT' \\
   \\
   zimbraReverseProxyMailMode https \\
   zimbraReverseProxyHttpEnabled TRUE \\
   zimbraReverseProxyMailEnabled TRUE \\
   zimbraReverseProxyAdminEnabled TRUE \\
   zimbraReverseProxySSLToUpstreamEnabled TRUE \\
   \\
   zimbraServerVersionMajor \${V[1]} \\
   zimbraServerVersionMinor \${V[2]} \\
   zimbraServerVersionMicro \${V[3]} \\
   zimbraServerVersionType \${V[4]} \\
   zimbraServerVersionBuild \${V[5]} \\
   zimbraServerVersion \${V[1]}_\${V[2]}_\${V[3]}_\${V[4]}_\${V[5]}

/opt/zimbra/libexec/zmiptool

echo "## CA and Certs"
/opt/zimbra/bin/zmcertmgr createca
/opt/zimbra/bin/zmcertmgr deployca -localonly
/opt/zimbra/bin/zmcertmgr createcrt -new
/opt/zimbra/bin/zmcertmgr deploycrt self
/opt/zimbra/bin/zmcertmgr savecrt self

END_BASH
         },
      },
      {
         desc => "Setting up syslog",
         exec => {
            user   => "root",
            script => <<"END_BASH"
/opt/zimbra/libexec/zmsyslogsetup
# zmschedulebackup
# crontab
END_BASH
         },
      },
      {
         desc => "Bringing up services",
         exec => {
            user   => "zimbra",
            script => <<"END_BASH"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   'ssl_allow_untrusted_certs=false' \\
   'ssl_allow_mismatched_certs=false'

/opt/zimbra/bin/zmcontrol restart
END_BASH
         },
      },
   ],
);
