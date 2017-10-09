#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

#use lib '/code/_base/';
use lib '/opt/zimbra/common/lib/perl5';

use Zimbra::DockerLib;

my $THIS_HOST = "zmc-mysql";

my $MYSQL_PORT = 7306;

########################################################

my $MYSQL_PASSWORD = Secret("mysql.password");

########################################################

EntryExec(
   $THIS_HOST,
   [
      {
         desc => "Initializing",
         exec => {
            user   => "root",
            script => <<"END_BASH"
echo '## Init'
mkdir -p /opt/zimbra/index
mkdir -p /opt/zimbra/store
mkdir -p /opt/zimbra/mailboxd
chown -R zimbra.zimbra /opt/zimbra
/opt/zimbra/libexec/zmfixperms
END_BASH
         },
      },
      {
         desc => "Configuring",    # FIXME - split
         exec => {
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
         },
      },
      {
         desc => "Setting up syslog",
         exec => {
            user   => "root",
            script => <<"END_BASH"
# /opt/zimbra/libexec/zmsyslogsetup
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

/opt/zimbra/bin/mysql.server restart
END_BASH
         },
      },
   ],
);
