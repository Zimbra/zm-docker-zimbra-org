#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;
use warnings;

use Cwd;
use File::Basename;

BEGIN
{
   push( @INC, grep { -d $_ } map { join( '/', dirname( Cwd::abs_path($0) ), $_ ); } ( "common/lib/perl5", "../common" ) );
}

use Zimbra::DockerLib qw(EntryExec Secret Config EvalExecAs);
use Net::Domain qw(hostname);

STDOUT->autoflush(1);

my $ENTRY_PID = $$;

## SECRETS AND CONFIGS #################################

my $MYSQL_PASSWORD = Secret("mysql.password");

## CONNECTIONS TO OTHER HOSTS ##########################


## THIS HOST LOCAL VARS ################################

my $THIS_HOST = hostname();
my ( undef, undef, $ZUID, $ZGID ) = getpwnam("zimbra");

my $MYSQL_PORT = 7306;

## CONFIGURATION ENTRY POINT ###########################

EntryExec(
   seq => [
      sub {
         {
            local_config => {
               zimbra_uid                 => $ZUID,
               zimbra_gid                 => $ZGID,
               zimbra_user                => "zimbra",
               zimbra_server_hostname     => $THIS_HOST,
               ssl_allow_untrusted_certs  => "false",
               ssl_allow_mismatched_certs => "false",
               mysql_bind_address         => "0.0.0.0",
               mysql_port                 => $MYSQL_PORT,
            },
         };
      },

      #######################################################################

      # FIXME - requires LDAP
      #sub { { desc => "Setting up syslog", exec => { user => "root", args => ["/opt/zimbra/libexec/zmsyslogsetup"], }, }; },

      sub { { desc => "Initialize and start MySQL", exec => { user => "zimbra", args => [ "/opt/zimbra/libexec/zmmyinit", "--sql_root_pw", $MYSQL_PASSWORD ], }, }; },

      #FIXME - is start required?
      sub { { desc => "Bringing up services", exec => { args => [ "/opt/zimbra/bin/mysql.server", "start" ], }, }; },

      #######################################################################

      sub { { publish_service => {}, }; },

      #######################################################################
   ],
);

END
{
   if ( $$ == $ENTRY_PID )
   {
      print "IF YOU ARE HERE, THEN AN ERROR HAS OCCURRED (^C to exit), OR ATTACH TO DEBUG\n";
      sleep
   }
}
