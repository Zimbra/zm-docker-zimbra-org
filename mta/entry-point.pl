#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

#use lib '/code/_base/';
use lib '/opt/zimbra/common/lib/perl5';

use Zimbra::DockerLib;

########################################################

my $AV_NOTIFY_EMAIL       = Config("av_notify_email");
my $LDAP_MASTER_PASSWORD  = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD    = Secret("ldap.root_password");
my $LDAP_POSTFIX_PASSWORD = Secret("ldap.postfix_password");
my $LDAP_AMAVIS_PASSWORD  = Secret("ldap.amavis_password");

########################################################

chomp( my $THIS_HOST = `hostname -f` );

my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_HOST        = "zmc-ldap";
my $LDAP_PORT        = 389;

########################################################

EntryExec(
   $THIS_HOST,
   [
      { wait_for => { service => $LDAP_HOST, }, },
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
   'ssl_allow_untrusted_certs=true' \\
   'ssl_allow_mismatched_certs=true' \\
   'av_notify_user=$AV_NOTIFY_EMAIL' \\
   'av_notify_domain=@{[map { s/.*@//; $_; } $AV_NOTIFY_EMAIL]}' \\
   'zimbra_ldap_password=$LDAP_MASTER_PASSWORD' \\
   'ldap_root_password=$LDAP_ROOT_PASSWORD' \\
   'ldap_postfix_password=$LDAP_POSTFIX_PASSWORD' \\
   'ldap_amavis_password=$LDAP_AMAVIS_PASSWORD' \\
   'zmtrainsa_cleanup_host=true' \\
   'ldap_port=$LDAP_PORT' \\
   'ldap_host=$LDAP_HOST' \\

echo "## Server Level Config"
V=( \$(/opt/zimbra/bin/zmcontrol -v | grep -o '[0-9A-Za-z_]*') )
/opt/zimbra/bin/zmprov -r -m -l cs '$THIS_HOST'
/opt/zimbra/bin/zmprov -r -m -l ms '$THIS_HOST' \\
   zimbraIPMode ipv4 \\
   zimbraServiceInstalled stats \\
   zimbraServiceEnabled stats \\
   zimbraServiceInstalled mta \\
   zimbraServiceEnabled mta \\
   zimbraServiceInstalled amavis \\
   zimbraServiceEnabled amavis \\
   zimbraServiceInstalled antivirus \\
   zimbraServiceEnabled antivirus \\
   zimbraServiceInstalled antispam \\
   zimbraServiceEnabled antispam \\
   zimbraServiceInstalled opendkim \\
   zimbraServiceEnabled opendkim \\
   zimbraServiceInstalled archiving \\
   zimbraServiceEnabled archiving \\
   \\
   zimbraMtaMyNetworks "\$(/opt/zimbra/libexec/zmserverips -n)" \\
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

echo "## Init and start MTA"
/opt/zimbra/libexec/zmmtainit '$LDAP_HOST' '$LDAP_PORT'
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
