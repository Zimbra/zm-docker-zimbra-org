#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

#use lib '/code/_base/';
use lib '/opt/zimbra/common/lib/perl5';

use Zimbra::DockerLib;

########################################################

my $DOMAIN_NAME                   = Config("domain_name");
my $LDAP_MASTER_PASSWORD          = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD            = Secret("ldap.root_password");
my $MYSQL_PASSWORD                = Secret("mysql.password");
my $ADMIN_ACCOUNT_NAME            = Config("admin_account_name");
my $ADMIN_PASSWORD                = Secret("admin_account_password");
my $SPAM_ACCOUNT_NAME             = Config("spam_account_name");
my $SPAM_PASSWORD                 = Secret("spam_account_password");
my $HAM_ACCOUNT_NAME              = Config("ham_account_name");
my $HAM_PASSWORD                  = Secret("ham_account_password");
my $VIRUS_QUARANTINE_ACCOUNT_NAME = Config("virus_quarantine_account_name");
my $VIRUS_QUARANTINE_PASSWORD     = Secret("virus_quarantine_account_password");
my $GAL_SYNC_ACCOUNT_NAME         = Config("gal_sync_account_name");

########################################################

chomp( my $THIS_HOST = `hostname -f` );

my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_HOST        = "zmc-ldap";
my $LDAP_PORT        = 389;
my $SMTP_HOST        = 'zmc-mta';
my $MYSQL_HOST       = 'zmc-mysql';

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

my $ADMIN_ACCOUNT            = "$ADMIN_ACCOUNT_NAME\@$DOMAIN_NAME";
my $SPAM_ACCOUNT             = "$SPAM_ACCOUNT_NAME\@$DOMAIN_NAME";
my $HAM_ACCOUNT              = "$HAM_ACCOUNT_NAME\@$DOMAIN_NAME";
my $VIRUS_QUARANTINE_ACCOUNT = "$VIRUS_QUARANTINE_ACCOUNT_NAME\@$DOMAIN_NAME";
my $GAL_SYNC_ACCOUNT         = "$GAL_SYNC_ACCOUNT_NAME\@$DOMAIN_NAME";


########################################################

EntryExec(
   $THIS_HOST,
   [
      { wait_for => { service => $LDAP_HOST, }, },
      { wait_for => { service => $SMTP_HOST, }, },
      { wait_for => { service => $MYSQL_HOST, }, },
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
   'zimbra_zmprov_default_to_ldap=false' \\
   'zimbra_mail_service_port=$HTTP_PORT' \\
   'mailboxd_server=jetty' \\
   'ldap_master_url=ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT' \\
   'ldap_url=ldap://$LDAP_HOST:$LDAP_PORT' \\
   'zimbra_ldap_password=$LDAP_MASTER_PASSWORD' \\
   'ldap_root_password=$LDAP_ROOT_PASSWORD' \\
   'ssl_allow_untrusted_certs=true' \\
   'ssl_allow_mismatched_certs=true' \\
   'mysql_bind_address=$MYSQL_HOST' \\
   'zimbra_mysql_password=$MYSQL_PASSWORD' \\
   'zimbra_mysql_connector_maxActive=100' \\
   'mailboxd_java_heap_size=512' \\

echo "## Server Level Config"
V=( \$(/opt/zimbra/bin/zmcontrol -v | grep -o '[0-9A-Za-z_]*') )
/opt/zimbra/bin/zmprov -r -m -l cs '$THIS_HOST'
/opt/zimbra/bin/zmprov -r -m -l ms '$THIS_HOST' \\
   zimbraIPMode ipv4 \\
   zimbraServiceInstalled stats \\
   zimbraServiceEnabled stats \\
   zimbraServiceInstalled mailbox \\
   zimbraServiceEnabled mailbox \\
   zimbraServiceEnabled service \\
   zimbraServiceInstalled imapd \\
   zimbraServiceEnabled imapd \\
   zimbraServiceInstalled spell \\
   zimbraServiceEnabled spell \\
   zimbraServiceEnabled zimbra \\
   zimbraServiceEnabled zimlet \\
   zimbraServiceEnabled zimbraAdmin \\
   \\
   zimbraSpellCheckURL 'http://$THIS_HOST:7780/aspell.php' \\
   zimbraConvertdURL 'http://$THIS_HOST:7047/convert' \\
   \\
   zimbraAdminPort '$ADMIN_PORT' \\
   zimbraAdminProxyPort '$PROXY_ADMIN_PORT' \\
   zimbraImapBindPort '$IMAP_PORT' \\
   zimbraImapCleartextLoginEnabled FALSE \\
   zimbraImapProxyBindPort '$PROXY_IMAP_PORT' \\
   zimbraImapSSLBindPort '$IMAPS_PORT' \\
   zimbraImapSSLProxyBindPort '$PROXY_IMAPS_PORT' \\
   zimbraMailMode https \\
   zimbraMailPort '$HTTP_PORT' \\
   zimbraMailProxyPort '$PROXY_HTTP_PORT' \\
   zimbraMailReferMode reverse-proxied \\
   zimbraMailSSLPort '$HTTPS_PORT' \\
   zimbraMailSSLProxyPort '$PROXY_HTTPS_PORT' \\
   zimbraPop3BindPort '$POP3_PORT' \\
   zimbraPop3CleartextLoginEnabled FALSE \\
   zimbraPop3ProxyBindPort '$PROXY_POP3_PORT' \\
   zimbraPop3SSLBindPort '$POP3S_PORT' \\
   zimbraPop3SSLProxyBindPort '$PROXY_POP3S_PORT' \\
   \\
   zimbraReverseProxyHttpEnabled TRUE \\
   zimbraReverseProxyMailEnabled TRUE \\
   zimbraReverseProxyAdminEnabled TRUE \\
   zimbraReverseProxyLookupTarget TRUE \\
   zimbraMtaAuthTarget TRUE \\
   +zimbraSmtpHostname '$SMTP_HOST' \\
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

echo "## ACCOUNTS"
/opt/zimbra/bin/zmprov -r -m -l ca '$ADMIN_ACCOUNT' '$ADMIN_PASSWORD' \\
   description 'Administrative Account' \\
   zimbraIsAdminAccount TRUE \\
   zimbraAdminConsoleUIComponents cartBlancheUI

/opt/zimbra/bin/zmprov -r -m -l aaa '$ADMIN_ACCOUNT' 'root\@$DOMAIN_NAME'
/opt/zimbra/bin/zmprov -r -m -l aaa '$ADMIN_ACCOUNT' 'postmaster\@$DOMAIN_NAME'

/opt/zimbra/bin/zmprov -r -m -l ca '$SPAM_ACCOUNT' '$SPAM_PASSWORD' \\
   description 'System account for spam training.' \\
   amavisBypassSpamChecks TRUE \\
   zimbraAttachmentsIndexingEnabled FALSE \\
   zimbraIsSystemResource TRUE \\
   zimbraIsSystemAccount TRUE \\
   zimbraHideInGal TRUE \\
   zimbraMailQuota 0

/opt/zimbra/bin/zmprov -r -m -l ca '$HAM_ACCOUNT' '$HAM_PASSWORD' \\
   description 'System account for Non-Spam (Ham) training.' \\
   amavisBypassSpamChecks TRUE \\
   zimbraAttachmentsIndexingEnabled FALSE \\
   zimbraIsSystemResource TRUE \\
   zimbraIsSystemAccount TRUE \\
   zimbraHideInGal TRUE \\
   zimbraMailQuota 0

/opt/zimbra/bin/zmprov -r -m -l ca '$VIRUS_QUARANTINE_ACCOUNT' '$VIRUS_QUARANTINE_PASSWORD' \\
   description 'System account for Anti-virus quarantine.' \\
   amavisBypassSpamChecks TRUE \\
   zimbraAttachmentsIndexingEnabled FALSE \\
   zimbraIsSystemResource TRUE \\
   zimbraIsSystemAccount TRUE \\
   zimbraHideInGal TRUE \\
   zimbraMailMessageLifetime 30d \\
   zimbraMailQuota 0

/opt/zimbra/bin/zmprov -r -m -l mcf \\
   zimbraSpamIsSpamAccount '$SPAM_ACCOUNT' \\
   zimbraSpamIsNotSpamAccount '$HAM_ACCOUNT' \\
   zimbraAmavisQuarantineAccount '$HAM_ACCOUNT' \\
   +zimbraReverseProxyAvailableLookupTargets '$THIS_HOST' \\
   +zimbraReverseProxyUpstreamEwsServers '$THIS_HOST' \\
   +zimbraReverseProxyUpstreamLoginServers '$THIS_HOST' \\
   zimbraRemoteImapServerEnabled 'TRUE' \\
   zimbraRemoteImapSSLServerEnabled 'TRUE' \\

echo "## Zimlets"
for file in /opt/zimbra/zimlets/*.zip
do
   zmzimletctl -l deploy zimlets/\$(basename \$file)
done

echo "## COS"
/opt/zimbra/bin/zmprov -r -m -l mc default \\
   zimbraMailHostPool "\$(/opt/zimbra/bin/zmprov -r -m -l gs '$THIS_HOST' zimbraId | sed -n -e '/zimbraId:/{s/.*: *//p;}')" \\
   zimbraZimletAvailableZimlets '!com_zimbra_attachcontacts' \\
   zimbraZimletAvailableZimlets '!com_zimbra_date' \\
   zimbraZimletAvailableZimlets '!com_zimbra_email' \\
   zimbraZimletAvailableZimlets '!com_zimbra_attachmail' \\
   zimbraZimletAvailableZimlets '!com_zimbra_url'

/opt/zimbra/bin/zmmailboxdctl restart # Required for GAL sync account to work

echo "## GAL Sync"
/opt/zimbra/bin/zmgsautil createAccount -a '$GAL_SYNC_ACCOUNT' \\
   -n InternalGAL \\
   --domain '$DOMAIN_NAME' \\
   -s '$THIS_HOST' \\
   -t zimbra \\
   -f _InternalGAL
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
