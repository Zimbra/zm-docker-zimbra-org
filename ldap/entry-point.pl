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

my $DOMAIN_NAME               = Config("domain_name");
my $LDAP_MASTER_PASSWORD      = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD        = Secret("ldap.root_password");
my $LDAP_REPLICATION_PASSWORD = Secret("ldap.replication_password");
my $LDAP_POSTFIX_PASSWORD     = Secret("ldap.postfix_password");
my $LDAP_AMAVIS_PASSWORD      = Secret("ldap.amavis_password");
my $LDAP_NGINX_PASSWORD       = Secret("ldap.nginx_password");

## CONNECTIONS TO OTHER HOSTS ##########################


## THIS HOST LOCAL VARS ################################

my $THIS_HOST = hostname();
my ( undef, undef, $ZUID, $ZGID ) = getpwnam("zimbra");

my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_HOST        = "zmc-ldap";
my $LDAP_PORT        = 389;

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
               ldap_is_master                => "true",
               ldap_host                     => $LDAP_HOST,
               ldap_port                     => $LDAP_PORT,
               ldap_master_url               => "ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT",
               ldap_url                      => "ldap://$LDAP_HOST:$LDAP_PORT",
               mailboxd_truststore           => $CA_TRUSTSTORE,
               mailboxd_truststore_password  => $CA_TRUSTSTORE_PASSWORD,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",   dest => "/opt/zimbra/conf/ca/ca.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ca.pem",   dest => "/opt/zimbra/conf/ca/ca.pem", mode => oct(644), }, }; },
      sub { { install_keys => { name => "ldap.key", dest => "/opt/zimbra/conf/slapd.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ldap.crt", dest => "/opt/zimbra/conf/slapd.crt", mode => oct(644), }, }; },

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

      sub { { desc => "Initializing LDAP", exec => { args => [ "/opt/zimbra/libexec/zmldapinit", $LDAP_ROOT_PASSWORD, $LDAP_MASTER_PASSWORD ], } }; },

      #######################################################################

      sub { { desc => "Set replication service password", exec => { args => [ "/opt/zimbra/bin/zmldappasswd", "-l", $LDAP_REPLICATION_PASSWORD ], }, }; },
      sub { { desc => "Set postfix service password",     exec => { args => [ "/opt/zimbra/bin/zmldappasswd", "-p", $LDAP_POSTFIX_PASSWORD ], }, }; },
      sub { { desc => "Set amavis service password",      exec => { args => [ "/opt/zimbra/bin/zmldappasswd", "-a", $LDAP_AMAVIS_PASSWORD ], }, }; },
      sub { { desc => "Set nginx service password",       exec => { args => [ "/opt/zimbra/bin/zmldappasswd", "-n", $LDAP_NGINX_PASSWORD ], }, }; },

      sub {
         {
            global_config => {
               zimbraSSLDHParam                  => "/opt/zimbra/conf/dhparam.pem.zcs",
               zimbraSkinLogoURL                 => "http://www.zimbra.com",
               zimbraDefaultDomainName           => $DOMAIN_NAME,
               zimbraComponentAvailable          => "",
               zimbraCertAuthorityCertSelfSigned => Secret("ca.pem"),
               zimbraCertAuthorityKeySelfSigned  => Secret("ca.key"),
               zimbraMtaLmtpHostLookup           => "native",
            },
         };
      },
      sub {
         {
            server_config => {
               $THIS_HOST => {
                  zimbraIPMode           => "ipv4",
                  zimbraServiceInstalled => [ "stats", "ldap" ],
                  zimbraServiceEnabled   => [ "stats", "ldap" ],
                  zimbraSSLCertificate   => Secret("ldap.crt"),
                  zimbraSSLPrivateKey    => Secret("ldap.key"),
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

      sub { { desc => "Create domain", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "cd", $DOMAIN_NAME ], }, }; },

      sub {
         {
            desc => "Create domain-admins",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "cdl", "zimbraDomainAdmins\@$DOMAIN_NAME",
                  "displayname",            "Zimbra Domain Admins",
                  "zimbraIsAdminGroup",     "TRUE",
                  "zimbraHideInGal",        "TRUE",
                  "zimbraMailStatus",       "disabled",
                  "zimbraAdminConsoleUIComponents", "DLListView",
                  "zimbraAdminConsoleUIComponents", "accountListView",
                  "zimbraAdminConsoleUIComponents", "aliasListView",
                  "zimbraAdminConsoleUIComponents", "resourceListView",
                  "zimbraAdminConsoleUIComponents", "saveSearch"
               ],
            },
         };
      },

      sub {
         {
            desc => "Create distribution-list-admins",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "cdl", "zimbraDLAdmins\@$DOMAIN_NAME",
                  "displayname",            "Zimbra DL Admins",
                  "zimbraIsAdminGroup",     "TRUE",
                  "zimbraHideInGal",        "TRUE",
                  "zimbraMailStatus",       "disabled",
                  "zimbraAdminConsoleUIComponents", "DLListView"
               ],
            },
         };
      },

      sub { { desc => "Granting domain rights domain-admins", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "grr", "domain", $DOMAIN_NAME, "grp", "zimbraDomainAdmins\@$DOMAIN_NAME", "+domainAdminConsoleRights" ], }, }; },
      sub { { desc => "Granting global rights domain-admins", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "grr", "global", "grp", "zimbraDomainAdmins\@$DOMAIN_NAME", "+domainAdminZimletRights" ], }, }; },
      sub { { desc => "Granting global rights distribution-list-admins", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "grr", "global", "grp", "zimbraDLAdmins\@$DOMAIN_NAME", "+adminConsoleDLRights", "+listAccount" ], }, }; },
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
