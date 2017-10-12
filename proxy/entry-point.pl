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

chomp( my $THIS_HOST = `hostname -f` );
chomp( my $ZUID      = `id -u zimbra` );
chomp( my $ZGID      = `id -g zimbra` );

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
               ssl_allow_untrusted_certs     => "true",
               ssl_allow_mismatched_certs    => "true",
               ldap_master_url               => "ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT",
               ldap_url                      => "ldap://$LDAP_HOST:$LDAP_PORT",
               ldap_root_password            => $LDAP_ROOT_PASSWORD,
               zimbra_ldap_password          => $LDAP_MASTER_PASSWORD,
               ldap_nginx_password           => $LDAP_NGINX_PASSWORD,
            },
         };
      },

      #######################################################################

      sub { { wait_for => { services => [$LDAP_HOST] }, }; },
      sub {
         {
            server_config => {
               $THIS_HOST => {
                  zimbraIPMode                           => "ipv4",
                  zimbraServiceInstalled                 => "stats",
                  zimbraServiceEnabled                   => "stats",
                  zimbraServiceInstalled                 => "proxy",
                  zimbraServiceEnabled                   => "proxy",
                  zimbraServiceInstalled                 => "memcached",
                  zimbraServiceEnabled                   => "memcached",
                  zimbraAdminPort                        => $ADMIN_PORT,
                  zimbraAdminProxyPort                   => $PROXY_ADMIN_PORT,
                  zimbraImapBindPort                     => $IMAP_PORT,
                  zimbraImapProxyBindPort                => $PROXY_IMAP_PORT,
                  zimbraImapSSLBindPort                  => $IMAPS_PORT,
                  zimbraImapSSLProxyBindPort             => $PROXY_IMAPS_PORT,
                  zimbraMailPort                         => $HTTP_PORT,
                  zimbraMailProxyPort                    => $PROXY_HTTP_PORT,
                  zimbraMailSSLPort                      => $HTTPS_PORT,
                  zimbraMailSSLProxyPort                 => $PROXY_HTTPS_PORT,
                  zimbraPop3BindPort                     => $POP3_PORT,
                  zimbraPop3ProxyBindPort                => $PROXY_POP3_PORT,
                  zimbraPop3SSLBindPort                  => $POP3S_PORT,
                  zimbraPop3SSLProxyBindPort             => $PROXY_POP3S_PORT,
                  zimbraReverseProxyMailMode             => "https",
                  zimbraReverseProxyHttpEnabled          => "TRUE",
                  zimbraReverseProxyMailEnabled          => "TRUE",
                  zimbraReverseProxyAdminEnabled         => "TRUE",
                  zimbraReverseProxySSLToUpstreamEnabled => "TRUE",
               },
            },
         };
      },

      sub { { desc => "Setting up syslog", exec => { user => "root", args => ["/opt/zimbra/libexec/zmsyslogsetup"], }, }; },

      #sub { { desc => "Updating IP Settings", exec => { user => "zimbra", args => ["/opt/zimbra/libexec/zmiptool"], }, }; },

      sub { { desc => "Fetching CA",    exec => { args => [ "/opt/zimbra/bin/zmcertmgr", "createca" ], }, }; },
      sub { { desc => "Deploying CA",   exec => { args => [ "/opt/zimbra/bin/zmcertmgr", "deployca", "-localonly" ], }, }; },
      sub { { desc => "Create Cert",    exec => { args => [ "/opt/zimbra/bin/zmcertmgr", "createcrt", "-new" ], }, }; },
      sub { { desc => "Deploying Cert", exec => { args => [ "/opt/zimbra/bin/zmcertmgr", "deploycrt", "self" ], }, }; },
      sub { { desc => "Saving Cert",    exec => { args => [ "/opt/zimbra/bin/zmcertmgr", "savecrt", "self" ], }, }; },
      sub { { local_config => { ssl_allow_untrusted_certs => "false", ssl_allow_mismatched_certs => "false", }, }; },

      #######################################################################

      sub { { wait_for => { services => [ $MAILBOX_HOST, ], }, }; },    #??

      sub { { desc => "Bringing up services", exec => { args => [ "/opt/zimbra/bin/zmcontrol", "start" ], }, }; },

      sub { { publish_service => {}, }; },
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
