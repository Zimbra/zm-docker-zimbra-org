#!/usr/bin/perl

# vim: set ai expandtab sw=3 ts=8 shiftround:

use strict;

BEGIN
{
   push( @INC, grep { -d $_ } map { use Cwd; use File::Basename; join( '/', dirname( Cwd::abs_path($0) ), $_ ); } ( "common/lib/perl5", "../common" ) );
}

use Zimbra::DockerLib;

$| = 1;
my $ENTRY_PID = $$;

## SECRETS AND CONFIGS #################################

my $AV_NOTIFY_EMAIL       = Config("av_notify_email");
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

chomp( my $THIS_HOST = `hostname -f` );
chomp( my $ZUID      = `id -u zimbra` );
chomp( my $ZGID      = `id -g zimbra` );

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
               av_notify_domain              => @{ [ map { s/.*@//; $_; } $AV_NOTIFY_EMAIL ] },
               zmtrainsa_cleanup_host        => "true",
               ldap_port                     => $LDAP_PORT,
               ldap_host                     => $LDAP_HOST,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",  dest => "/opt/zimbra/conf/ca/ca.key", mode => 0600, }, }; },
      sub { { install_keys => { name => "ca.pem",  dest => "/opt/zimbra/conf/ca/ca.pem", mode => 0644, }, }; },
      sub { { install_keys => { name => "mta.key", dest => "/opt/zimbra/conf/smtpd.key", mode => 0600, }, }; },
      sub { { install_keys => { name => "mta.crt", dest => "/opt/zimbra/conf/smtpd.crt", mode => 0644, }, }; },

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
                  zimbraMtaMyNetworks    => join( '', map { chomp; s/\n/ /g; $_; } _EvalExecAs( "zimbra", [ "/opt/zimbra/libexec/zmserverips", "-n" ] )->{result} ),
                  zimbraSSLCertificate   => Secret("mta.crt"),
                  zimbraSSLPrivateKey    => Secret("mta.key"),
               },
            },
         };
      },

      # FIXME - requires LDAP
      #sub { { desc => "Updating IP Settings", exec => { args => ["/opt/zimbra/libexec/zmiptool"], }, }; },

      # FIXME - requires LDAP
      sub { { desc => "Setting up syslog", exec => { user => "root", args => ["/opt/zimbra/libexec/zmsyslogsetup"], }, }; },

      # FIXME - requires LDAP
      sub { { desc => "Bringing up all services", exec => { args => [ "/opt/zimbra/bin/zmcontrol", "start" ], }, }; },

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
