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
   print FD $script;

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

my $MYSQL_PASSWORD = RandomStr( 10, "mysql" );
my $MYSQL_PORT = 7306;

## SYNCHRONIZE
# wait for none

ExCmd(
   {
      user   => "root",
      script => <<"END_BASH"
echo '## Init'
mkdir -p /opt/zimbra/index
mkdir -p /opt/zimbra/store
mkdir -p /opt/zimbra/mailboxd
chown -R zimbra.zimbra /opt/zimbra
/opt/zimbra/libexec/zmfixperms
END_BASH
   }
);

ExCmd(
   {
      user   => "zimbra",
      script => <<"END_BASH"
echo "## Local Config"
/opt/zimbra/bin/zmlocalconfig -f -e \\
   "zimbra_uid=\$(id -u zimbra)" \\
   "zimbra_gid=\$(id -g zimbra)" \\
   "zimbra_user=zimbra" \\
   'mysql_bind_address=0.0.0.0' \\
   'mysql_port=$MYSQL_PORT'

echo '## MySQL Init'
/opt/zimbra/libexec/zmmyinit --sql_root_pw '$MYSQL_PASSWORD'

END_BASH
   }
);

ExCmd(
   {
      user   => "root",
      script => <<"END_BASH"
echo "## Syslog"
# /opt/zimbra/libexec/zmsyslogsetup
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

/opt/zimbra/bin/mysql.server restart
END_BASH
   }
);

chomp( my $BENCH_DURATION = `date -u '+%Hh %Mm %Ss' -d '@@{[time() - $BENCH_START]}' | sed -e 's/00[hm] \\?//g' -e 's/\\<0//g'` );

print "MYSQL STARTED - SETUP - $BENCH_DURATION\n";

system("./healthcheck.py");    # start simple healthcheck so other nodes in the cluster can coordinate startup
