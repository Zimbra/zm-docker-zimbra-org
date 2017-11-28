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

my $AV_NOTIFY_EMAIL       = Config("av_notify_email");
my $ZIMBRA_LDAP_USERDN    = Config("zimbra_ldap_userdn");

my $LDAP_MASTER_PASSWORD  = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD    = Secret("ldap.root_password");
my $LDAP_POSTFIX_PASSWORD = Secret("ldap.postfix_password");
my $LDAP_AMAVIS_PASSWORD  = Secret("ldap.amavis_password");


## CONNECTIONS TO OTHER HOSTS ##########################

my $LDAP_HOST        = "zmc-ldap";
my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_PORT        = 389;

## THIS HOST LOCAL VARS ################################

my $THIS_HOST = hostname();
my ( undef, undef, $ZUID, $ZGID ) = getpwnam("zimbra");

my $CA_TRUSTSTORE          = "/opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts";
my $CA_TRUSTSTORE_PASSWORD = "changeit";

## CONFIGURATION ENTRY POINT ###########################

EntryExec(
   seq => [
      sub {
         {
            local_config => {
               zimbra_uid                    => $ZUID,
               zimbra_gid                    => $ZGID,
               zimbra_user                   => "zimbra",
               zimbra_server_hostname        => $THIS_HOST,
               ldap_starttls_supported       => 1,
               zimbra_zmprov_default_to_ldap => "true",
               ssl_allow_untrusted_certs     => "false",
               ssl_allow_mismatched_certs    => "false",
               ldap_master_url               => "ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT",
               ldap_url                      => "ldap://$LDAP_HOST:$LDAP_PORT",
               mailboxd_truststore           => $CA_TRUSTSTORE,
               mailboxd_truststore_password  => $CA_TRUSTSTORE_PASSWORD,
               ldap_root_password            => $LDAP_ROOT_PASSWORD,
               zimbra_ldap_password          => $LDAP_MASTER_PASSWORD,
               ldap_postfix_password         => $LDAP_POSTFIX_PASSWORD,
               ldap_amavis_password          => $LDAP_AMAVIS_PASSWORD,
               av_notify_user                => $AV_NOTIFY_EMAIL,
               av_notify_domain              => @{ [ extract_domain($AV_NOTIFY_EMAIL) ] },
               zmtrainsa_cleanup_host        => "true",
               ldap_port                     => $LDAP_PORT,
               ldap_host                     => $LDAP_HOST,
               zimbra_ldap_userdn            => $ZIMBRA_LDAP_USERDN,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",  dest => "/opt/zimbra/conf/ca/ca.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ca.pem",  dest => "/opt/zimbra/conf/ca/ca.pem", mode => oct(644), }, }; },
      sub { { install_keys => { name => "mta.key", dest => "/opt/zimbra/conf/smtpd.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "mta.crt", dest => "/opt/zimbra/conf/smtpd.crt", mode => oct(644), }, }; },

      sub { { desc => "Hashing certs...", exec => { args => [ "c_rehash", "/opt/zimbra/conf/ca" ], }, }; },

      sub {
         {
            desc => "Importing Cert...",
            exec => [
               {
                  args => [
                     "/opt/zimbra/common/bin/keytool", "-delete", "-alias", "my_ca",
                     "-keystore",                      $CA_TRUSTSTORE,
                     "-storepass",                     $CA_TRUSTSTORE_PASSWORD,
                  ],
               },
               {
                  args => [
                     "/opt/zimbra/common/bin/keytool", "-import", "-alias", "my_ca", "-noprompt",
                     "-file",                          "/opt/zimbra/conf/ca/ca.pem",
                     "-keystore",                      $CA_TRUSTSTORE,
                     "-storepass",                     $CA_TRUSTSTORE_PASSWORD,
                  ],
               }
            ],
         };
      },

      sub { { desc => "Setting up syslog", exec => { user => "root", args => [ "/opt/zimbra/libexec/zmsyslogsetup", "local" ], }, }; },

      #######################################################################

      sub { { desc => "Initializing MTA", exec => { args => [ "/opt/zimbra/libexec/zmmtainit", $LDAP_HOST, $LDAP_PORT ], } }; },

      #######################################################################

      sub { { wait_for => { services => [$LDAP_HOST] }, }; },
      sub {
         {
            server_config => {
               $THIS_HOST => {
                  zimbraIPMode           => "ipv4",
                  zimbraSpellCheckURL    => "http://$THIS_HOST:7780/aspell.php",
                  zimbraServiceInstalled => [ "amavis", "antispam", "antivirus", "archiving", "mta", "opendkim", "stats", ],
                  zimbraServiceEnabled   => [ "amavis", "antispam", "antivirus", "archiving", "mta", "opendkim", "stats", ],
                  zimbraMtaMyNetworks    => join_lines(
                     EvalExecAs( { user => "zimbra", args => [ "/opt/zimbra/libexec/zmserverips", "-n" ] } )->{result}
                  ),
                  zimbraSSLCertificate => Secret("mta.crt"),
                  zimbraSSLPrivateKey  => Secret("mta.key"),
               },
            },
         };
      },

      # FIXME - requires LDAP
      #sub { { desc => "Updating IP Settings", exec => { args => ["/opt/zimbra/libexec/zmiptool"], }, }; },

      # FIXME - requires LDAP
      sub { { desc => "Bringing up all services", exec => { args => [ "/opt/zimbra/bin/zmcontrol", "start" ], }, }; },

      #######################################################################

      sub { { configure_staf => {}, }; },

      #######################################################################

      sub { { publish_service => {}, }; },

      #######################################################################
   ],
);

sub extract_domain
{
   my $email = shift;
   $email =~ s/.*@//;
   return $email;
}

sub join_lines
{
   my $multiple_lines = shift;
   my $split_by       = shift // '\n';
   my $join_by        = shift // ' ';

   chomp $multiple_lines;

   return join( $join_by, split( $split_by, $multiple_lines ) );
}

END
{
   if ( $$ == $ENTRY_PID )
   {
      print "IF YOU ARE HERE, THEN AN ERROR HAS OCCURRED (^C to exit), OR ATTACH TO DEBUG\n";
      sleep
   }
}
