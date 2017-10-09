#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

#use lib '/code/_base/';
use lib '/opt/zimbra/common/lib/perl5';

use Zimbra::DockerLib;

########################################################

my $DOMAIN_NAME               = Config("domain_name");
my $LDAP_MASTER_PASSWORD      = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD        = Secret("ldap.root_password");
my $LDAP_REPLICATION_PASSWORD = Secret("ldap.replication_password");
my $LDAP_POSTFIX_PASSWORD     = Secret("ldap.postfix_password");
my $LDAP_AMAVIS_PASSWORD      = Secret("ldap.amavis_password");
my $LDAP_NGINX_PASSWORD       = Secret("ldap.nginx_password");

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
      {
         desc => "Initializing",
         exec => {
            user   => "root",
            script => <<"END_BASH"
echo "## LDAP Config"
rsync -a --delete "/opt/zimbra/common/etc/openldap/zimbra/config/" "/opt/zimbra/data/ldap/config";
chown -R zimbra:zimbra "/opt/zimbra/data/ldap/config"
find "/opt/zimbra/data/ldap/config" -name '*.ldif' -print0 | xargs -0 -r chmod 600
END_BASH
         },
      },
      {
         desc => "Configuring",    # FIXME - split
         exec => {
            user   => "zimbra",
            script => <<"END_BASH"
echo "## LDAP Schema"
/opt/zimbra/libexec/zmldapschema

echo "## Local Config"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   "zimbra_uid=\$(id -u zimbra)" \\
   "zimbra_gid=\$(id -g zimbra)" \\
   "zimbra_server_hostname=$THIS_HOST" \\
   "zimbra_user=zimbra" \\
   'ldap_is_master=true' \\
   'ldap_starttls_supported=1' \\
   'zimbra_zmprov_default_to_ldap=true' \\
   'ldap_host=$LDAP_HOST' \\
   'ldap_port=$LDAP_PORT' \\
   'ldap_master_url=ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT' \\
   'ldap_url=ldap://$LDAP_HOST:$LDAP_PORT' \\

echo "## CA and Certs (pre ldap)"
/opt/zimbra/bin/zmcertmgr createca -new
/opt/zimbra/bin/zmcertmgr deployca -localonly
/opt/zimbra/bin/zmcertmgr createcrt -new
/opt/zimbra/bin/zmcertmgr deploycrt self

echo "## Init and start the LDAP server"
/opt/zimbra/libexec/zmldapinit '$LDAP_ROOT_PASSWORD' '$LDAP_MASTER_PASSWORD'

echo "## CA and Certs (post ldap)"
/opt/zimbra/bin/zmcertmgr deployca
/opt/zimbra/bin/zmcertmgr savecrt self

echo "## Set ldap login service passwords"
/opt/zimbra/bin/zmldappasswd -l '$LDAP_REPLICATION_PASSWORD'
/opt/zimbra/bin/zmldappasswd -p '$LDAP_POSTFIX_PASSWORD'
/opt/zimbra/bin/zmldappasswd -a '$LDAP_AMAVIS_PASSWORD'
/opt/zimbra/bin/zmldappasswd -n '$LDAP_NGINX_PASSWORD'

# zmldapenablereplica; touch "/opt/zimbra/.enable_replica"

echo "## Server Level Config"
V=( \$(/opt/zimbra/bin/zmcontrol -v | grep -o '[0-9A-Za-z_]*') )
/opt/zimbra/bin/zmprov -r -m -l cs '$THIS_HOST'
/opt/zimbra/bin/zmprov -r -m -l ms '$THIS_HOST' \\
   zimbraIPMode ipv4 \\
   zimbraServiceInstalled stats \\
   zimbraServiceEnabled stats \\
   zimbraServiceInstalled ldap \\
   zimbraServiceEnabled ldap \\
   \\
   zimbraServerVersionMajor \${V[1]} \\
   zimbraServerVersionMinor \${V[2]} \\
   zimbraServerVersionMicro \${V[3]} \\
   zimbraServerVersionType \${V[4]} \\
   zimbraServerVersionBuild \${V[5]} \\
   zimbraServerVersion \${V[1]}_\${V[2]}_\${V[3]}_\${V[4]}_\${V[5]}

/opt/zimbra/libexec/zmiptool

echo "## Global Config"
/opt/zimbra/bin/zmprov -r -m -l mcf \\
   zimbraSSLDHParam /opt/zimbra/conf/dhparam.pem.zcs \\
   zimbraSkinLogoURL http://www.zimbra.com \\
   zimbraDefaultDomainName '$DOMAIN_NAME' \\
   zimbraComponentAvailable '' \\

echo "## COS"
/opt/zimbra/bin/zmprov -r -m -l mc default \\
   zimbraPrefTimeZoneId UTC \\
   zimbraFeatureTasksEnabled TRUE \\
   zimbraFeatureBriefcasesEnabled TRUE \\

echo "## DOMAIN, Distribution Lists"
/opt/zimbra/bin/zmprov -r -m -l cd '$DOMAIN_NAME'

/opt/zimbra/bin/zmprov -r -m -l cdl 'zimbraDomainAdmins\@$DOMAIN_NAME' \\
   displayname 'Zimbra Domain Admins' \\
   zimbraIsAdminGroup TRUE \\
   zimbraHideInGal TRUE \\
   zimbraMailStatus disabled \\
   zimbraAdminConsoleUIComponents DLListView \\
   zimbraAdminConsoleUIComponents accountListView \\
   zimbraAdminConsoleUIComponents aliasListView \\
   zimbraAdminConsoleUIComponents resourceListView \\
   zimbraAdminConsoleUIComponents saveSearch

/opt/zimbra/bin/zmprov -r -m -l cdl 'zimbraDLAdmins\@$DOMAIN_NAME' \\
   displayname 'Zimbra DL Admins' \\
   zimbraIsAdminGroup TRUE \\
   zimbraHideInGal TRUE \\
   zimbraMailStatus disabled \\
   zimbraAdminConsoleUIComponents DLListView

/opt/zimbra/bin/zmprov -r -m -l grr \\
   domain '$DOMAIN_NAME' \\
   grp 'zimbraDomainAdmins\@$DOMAIN_NAME' \\
   +domainAdminConsoleRights

/opt/zimbra/bin/zmprov -r -m -l grr \\
   global \\
   grp 'zimbraDomainAdmins\@$DOMAIN_NAME' \\
   +domainAdminZimletRights

/opt/zimbra/bin/zmprov -r -m -l grr \\
   global \\
   grp 'zimbraDLAdmins\@$DOMAIN_NAME' \\
   +adminConsoleDLRights \\
   +listAccount
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
