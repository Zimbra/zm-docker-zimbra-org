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

my $LDAP_MASTER_PASSWORD = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD   = Secret("ldap.root_password");
my $LDAP_NGINX_PASSWORD  = Secret("ldap.nginx_password");

## CONNECTIONS TO OTHER HOSTS ##########################

my $LDAP_HOST        = "zmc-ldap";
my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_PORT        = 389;
my $MAILBOX_HOST     = "zmc-mailbox";

## THIS HOST LOCAL VARS ################################

my $THIS_HOST = hostname();
my ( undef, undef, $ZUID, $ZGID ) = getpwnam("zimbra");

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
               ldap_nginx_password           => $LDAP_NGINX_PASSWORD,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",    dest => "/opt/zimbra/conf/ca/ca.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ca.pem",    dest => "/opt/zimbra/conf/ca/ca.pem", mode => oct(644), }, }; },
      sub { { install_keys => { name => "proxy.key", dest => "/opt/zimbra/conf/nginx.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "proxy.crt", dest => "/opt/zimbra/conf/nginx.crt", mode => oct(644), }, }; },

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

      sub { { wait_for => { services => [$LDAP_HOST] }, }; },
      sub {
         {
            server_config => {
               $THIS_HOST => {
                  zimbraIPMode                              => "ipv4",
                  zimbraServiceInstalled                    => [ "stats", "proxy", "memcached" ],
                  zimbraServiceEnabled                      => [ "stats", "proxy", "memcached" ],
                  zimbraAdminPort                           => $ADMIN_PORT,
                  zimbraAdminProxyPort                      => $PROXY_ADMIN_PORT,
                  zimbraImapBindPort                        => $IMAP_PORT,
                  zimbraImapProxyBindPort                   => $PROXY_IMAP_PORT,
                  zimbraImapSSLBindPort                     => $IMAPS_PORT,
                  zimbraImapSSLProxyBindPort                => $PROXY_IMAPS_PORT,
                  zimbraMailPort                            => $HTTP_PORT,
                  zimbraMailProxyPort                       => $PROXY_HTTP_PORT,
                  zimbraMailSSLPort                         => $HTTPS_PORT,
                  zimbraMailSSLProxyPort                    => $PROXY_HTTPS_PORT,
                  zimbraPop3BindPort                        => $POP3_PORT,
                  zimbraPop3ProxyBindPort                   => $PROXY_POP3_PORT,
                  zimbraPop3SSLBindPort                     => $POP3S_PORT,
                  zimbraPop3SSLProxyBindPort                => $PROXY_POP3S_PORT,
                  zimbraReverseProxyMailMode                => "https",
                  zimbraReverseProxyHttpEnabled             => "TRUE",
                  zimbraReverseProxyMailEnabled             => "TRUE",
                  zimbraReverseProxyAdminEnabled            => "TRUE",
                  zimbraReverseProxySSLToUpstreamEnabled    => "TRUE",
                  zimbraSSLCertificate                      => Secret("proxy.crt"),
                  zimbraSSLPrivateKey                       => Secret("proxy.key"),
                  zimbraReverseProxyStrictServerNameEnabled => "FALSE",
               },
            },
         };
      },

      # FIXME - requires LDAP
      #sub { { desc => "Updating IP Settings", exec => { args => ["/opt/zimbra/libexec/zmiptool"], }, }; },

      sub { { desc => "Starting ssh-server", exec => { user => "root", args => [ "/usr/sbin/service", "ssh", "start" ], }, }; },

      # FIXME - requires LDAP
      sub { { desc => "Bringing up all services", exec => { args => [ "/opt/zimbra/bin/zmcontrol", "start" ], }, }; },

      #######################################################################


      sub { { wait_for => { services => [ $MAILBOX_HOST, ], }, }; },    #??

      #######################################################################

      sub { { configure_staf => {}, }; },

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
