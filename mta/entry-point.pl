#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

sub ExCmd
{
   my $args = shift;

   my $user = $args->{user} || "zimbra";
   my $script = ( $args->{script} || "" ) . "\n";

   open( FD, "|-" ) or exec( "sudo", "su", "-l", $user, "-c", "bash -s" );

   print FD "echo ==================================================================\n";
   print FD "echo 'USER : $user\n'";
   print FD "export TIMEFORMAT='r: %R, u: %U, s: %S'\n";
   print FD "set -u\n";
   print FD "set -x\n";
   print FD $script . "\n";
   print FD "echo ==================================================================\n";

   close(FD);

   return $?;
}

sub WaitForHost
{
   my $name = shift;
   my $url  = shift;
   my $c    = 0;
   while (1)
   {
      chomp( my $o = `curl --silent --output /dev/null --write-out "%{http_code}" '$url'` );
      last if ( $o eq "200" );
      print "$name unavailable\n" if ( $c % 30 eq "0" );
      sleep(1);
      ++$c;
   }

   print "$name available\n";
}

sub RandomStr
{
   my $w      = shift || 10;
   my $prefix = shift || "zimbra";

   return $prefix . "-" . ( 'X' x $w );    #   return `tr -cd '[0-9a-z_]' < /dev/urandom | head -c $w`;
}

my $BENCH_START = time();

chomp( my $HOSTNAME = `hostname -f` );
my $DOMAIN_NAME     = "zmc";
my $AV_NOTIFY_EMAIL = "admin\@$DOMAIN_NAME";

my $LDAP_MASTER_PORT = 389;
my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_PORT        = 389;
my $LDAP_HOST        = "zmc-ldap";

my $LDAP_MASTER_PASSWORD  = RandomStr( 10, "ldap-master" );
my $LDAP_ROOT_PASSWORD    = RandomStr( 10, "ldap-root" );
my $LDAP_POSTFIX_PASSWORD = RandomStr( 10, "ldap-postfix" );
my $LDAP_AMAVIS_PASSWORD  = RandomStr( 10, "ldap-amavis" );

## SYNCHRONIZE
WaitForHost( "LDAP", "http://$LDAP_HOST:5000/" );

ExCmd(
   {
      user   => "zimbra",
      script => <<"END_BASH"
echo "## Local Config"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   "zimbra_uid=\$(id -u zimbra)" \\
   "zimbra_gid=\$(id -g zimbra)" \\
   "zimbra_server_hostname=$HOSTNAME" \\
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
/opt/zimbra/bin/zmprov -r -m -l cs '$HOSTNAME'
/opt/zimbra/bin/zmprov -r -m -l ms '$HOSTNAME' \\
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
   }
);

ExCmd(
   {
      user   => "root",
      script => <<"END_BASH"
echo "## Syslog"
/opt/zimbra/libexec/zmsyslogsetup
# zmschedulebackup
# crontab
END_BASH
   }
);

ExCmd(
   {
      user   => "zimbra",
      script => <<"END_BASH"
echo "## Start/Restart"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   'ssl_allow_untrusted_certs=false' \\
   'ssl_allow_mismatched_certs=false'

/opt/zimbra/bin/zmcontrol restart
END_BASH
   }
);

chomp( my $BENCH_DURATION = `date -u '+%Hh %Mm %Ss' -d '@@{[time() - $BENCH_START]}' | sed -e 's/00[hm] \\?//g' -e 's/\\<0//g'` );

print "MTA STARTED - SETUP - $BENCH_DURATION\n";

system("./healthcheck.py");    # start simple healthcheck so other nodes in the cluster can coordinate startup
