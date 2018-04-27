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

## ENVIRONMENT##########################################


## SECRETS AND CONFIGS #################################

my $DOMAIN_NAME                   = Config("domain_name");
my $LDAP_MASTER_PASSWORD          = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD            = Secret("ldap.root_password");
my $MYSQL_PASSWORD                = Secret("mysql.password");
my $ADMIN_ACCOUNT_NAME            = Config("admin_account_name");
my $ADMIN_PASSWORD                = Secret("admin_account_password");

## CONNECTIONS TO OTHER HOSTS ##########################

my $LDAP_HOST        = "zmc-ldap";
my $LDAP_MASTER_HOST = "zmc-ldap";
my $LDAP_MASTER_PORT = 389;
my $LDAP_PORT        = 389;
my $MYSQL_HOST       = 'zmc-mysql';
my $SMTP_HOST        = 'zmc-mta';
my $SOLR_HOST        = 'zmc-solr';

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

my $ADMIN_ACCOUNT            = "$ADMIN_ACCOUNT_NAME\@$DOMAIN_NAME";

my $CA_TRUSTSTORE              = "/opt/zimbra/common/lib/jvm/java/jre/lib/security/cacerts";
my $CA_TRUSTSTORE_PASSWORD     = "changeit";
my $MAILBOXD_KEYSTORE          = "/opt/zimbra/mailboxd/etc/keystore";
my $MAILBOXD_KEYSTORE_PASSWORD = "zimbra1";
my $IMAPD_KEYSTORE             = "/opt/zimbra/conf/imapd.keystore";
my $IMAPD_KEYSTORE_PASSWORD    = "zimbra2";
my $JETTY_ALIAS_NAME           = "jetty";                                                      # This likely can't be different
my $PKCS_PASSWORD              = "zimbra3";

## CONFIGURATION ENTRY POINT ###########################

EntryExec(
   seq => [
      sub {
         {
            local_config => {
               zimbra_uid                       => $ZUID,
               zimbra_gid                       => $ZGID,
               zimbra_user                      => "zimbra",
               zimbra_server_hostname           => $THIS_HOST,
               ldap_starttls_supported          => 1,
               zimbra_zmprov_default_to_ldap    => "false",
               ssl_allow_untrusted_certs        => "false",
               ssl_allow_mismatched_certs       => "false",
               ldap_master_url                  => "ldap://$LDAP_MASTER_HOST:$LDAP_MASTER_PORT",
               ldap_url                         => "ldap://$LDAP_HOST:$LDAP_PORT",
               ldap_root_password               => $LDAP_ROOT_PASSWORD,
               zimbra_ldap_password             => $LDAP_MASTER_PASSWORD,
               zimbra_mysql_password            => $MYSQL_PASSWORD,
               mysql_bind_address               => $MYSQL_HOST,
               mailboxd_java_heap_size          => 512,
               mailboxd_server                  => $JETTY_ALIAS_NAME,
               zimbra_mail_service_port         => $HTTP_PORT,
               zimbra_mysql_connector_maxActive => 100,
               mailboxd_truststore              => $CA_TRUSTSTORE,
               mailboxd_truststore_password     => $CA_TRUSTSTORE_PASSWORD,
               mailboxd_keystore                => $MAILBOXD_KEYSTORE,
               mailboxd_keystore_password       => $MAILBOXD_KEYSTORE_PASSWORD,
               imapd_keystore                   => $IMAPD_KEYSTORE,
               imapd_keystore_password          => $IMAPD_KEYSTORE_PASSWORD,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",      dest => "/opt/zimbra/conf/ca/ca.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ca.pem",      dest => "/opt/zimbra/conf/ca/ca.pem", mode => oct(644), }, }; },

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

      sub {
         {
            desc => "Importing Keystore...",    # FIXME - need to split imapd and mailboxd
            exec => [
               {
                  args => [
                     "/opt/zimbra/common/bin/openssl", "pkcs12",
                     "-inkey",                         "/opt/zimbra/conf/jetty.key",
                     "-in",                            "/opt/zimbra/conf/jetty.crt",
                     "-name",                          $JETTY_ALIAS_NAME,
                     "-export",                        "-out", "/opt/zimbra/conf/jetty.pkcs12",
                     "-passout",                       "pass:$PKCS_PASSWORD"
                  ],
               },
               {
                  args => [
                     "/opt/zimbra/common/bin/keytool", "-delete",
                     "-alias",                         $JETTY_ALIAS_NAME,
                     "-keystore",                      $MAILBOXD_KEYSTORE,
                     "-storepass",                     $MAILBOXD_KEYSTORE_PASSWORD,
                  ],
               },
               {
                  args => [
                     "/opt/zimbra/common/bin/java", "-classpath", "/opt/zimbra/lib/ext/com_zimbra_cert_manager/com_zimbra_cert_manager.jar",
                     "com.zimbra.cert.MyPKCS12Import", "/opt/zimbra/conf/jetty.pkcs12", $MAILBOXD_KEYSTORE, $PKCS_PASSWORD, $MAILBOXD_KEYSTORE_PASSWORD,
                  ],
               },
               {
                  args => [
                     "/opt/zimbra/common/bin/keytool", "-delete",
                     "-alias",                         $JETTY_ALIAS_NAME,
                     "-keystore",                      $IMAPD_KEYSTORE,
                     "-storepass",                     $IMAPD_KEYSTORE_PASSWORD,
                  ],
               },
               {
                  args => [
                     "/opt/zimbra/common/bin/java", "-classpath", "/opt/zimbra/lib/ext/com_zimbra_cert_manager/com_zimbra_cert_manager.jar",
                     "com.zimbra.cert.MyPKCS12Import", "/opt/zimbra/conf/jetty.pkcs12", $IMAPD_KEYSTORE, $PKCS_PASSWORD, $IMAPD_KEYSTORE_PASSWORD,
                  ],
               }
            ],
         };
      },

      #######################################################################

      sub { { wait_for => { services => [$LDAP_HOST] }, }; },
      sub {
         {
            server_config => {
               $THIS_HOST => {
                  zimbraIPMode                    => "ipv4",
                  zimbraSpellCheckURL             => "http://$THIS_HOST:7780/aspell.php",
                  zimbraServiceInstalled          => [ "stats", "mailbox", "imapd" ],
                  zimbraServiceEnabled            => [ "stats", "mailbox", "service", "imapd", "zimbra", "zimlet", "zimbraAdmin" ],
                  zimbraConvertdURL               => "http://$THIS_HOST:7047/convert",
                  zimbraAdminPort                 => $ADMIN_PORT,
                  zimbraAdminProxyPort            => $PROXY_ADMIN_PORT,
                  zimbraImapBindPort              => $IMAP_PORT,
                  zimbraImapCleartextLoginEnabled => "FALSE",
                  zimbraImapProxyBindPort         => $PROXY_IMAP_PORT,
                  zimbraImapSSLBindPort           => $IMAPS_PORT,
                  zimbraImapSSLProxyBindPort      => $PROXY_IMAPS_PORT,
                  zimbraMailMode                  => "https",
                  zimbraMailPort                  => $HTTP_PORT,
                  zimbraMailProxyPort             => $PROXY_HTTP_PORT,
                  zimbraMailReferMode             => "reverse-proxied",
                  zimbraMailSSLPort               => $HTTPS_PORT,
                  zimbraMailSSLProxyPort          => $PROXY_HTTPS_PORT,
                  zimbraPop3BindPort              => $POP3_PORT,
                  zimbraPop3CleartextLoginEnabled => "FALSE",
                  zimbraPop3ProxyBindPort         => $PROXY_POP3_PORT,
                  zimbraPop3SSLBindPort           => $POP3S_PORT,
                  zimbraPop3SSLProxyBindPort      => $PROXY_POP3S_PORT,
                  zimbraReverseProxyHttpEnabled   => "TRUE",
                  zimbraReverseProxyMailEnabled   => "TRUE",
                  zimbraReverseProxyAdminEnabled  => "TRUE",
                  zimbraReverseProxyLookupTarget  => "TRUE",
                  zimbraMtaAuthTarget             => "TRUE",
                  '+zimbraSmtpHostname'           => $SMTP_HOST,
               },
            },
         };
      },

      # FIXME - When we add support for SOLR cloud, update zimbraIndexURL and zimbraEventBackendURL
      sub {
         {
            global_config => {
               "+zimbraReverseProxyAvailableLookupTargets" => $THIS_HOST,
               "+zimbraReverseProxyUpstreamEwsServers"     => $THIS_HOST,
               "+zimbraReverseProxyUpstreamLoginServers"   => $THIS_HOST,
               zimbraRemoteImapServerEnabled               => "TRUE",
               zimbraRemoteImapSSLServerEnabled            => "TRUE",
               zimbraSolrReplicationFactor                 => "1",
            },
         };
      },

      #######################################################################

      sub {
         {
            cos_config => {
               default => {
                  zimbraMailHostPool => strip_zmprov_header(
                     EvalExecAs( { user => "zimbra", args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "gs", $THIS_HOST, "zimbraId" ] } )->{result}
                  ),
               },
            },
         };
      },

      sub { { desc => "Creating SSL PEM /etc/haproxy/server.pem", exec => { user => "root", args => [ "cat /run/secrets/proxy.key /run/secrets/proxy.crt > /etc/haproxy/server.pem" ], }, }; },

      sub { { desc => "Starting up mailbox-monitor", exec => { user => "root", args => [ "/opt/zimbra/mailbox-monitor&" ], }, }; },

      #######################################################################

      sub { { publish_service => {}, }; },

      #######################################################################
   ],
);

sub strip_zmprov_header
{
   my $x = shift;
   $x =~ s/^[^:]*:\s*//s;
   $x =~ s/\s*\n*$//s;
   return $x;
}

END
{
   if ( $$ == $ENTRY_PID )
   {
      print "IF YOU ARE HERE, THEN AN ERROR HAS OCCURRED (^C to exit), OR ATTACH TO DEBUG\n";
      sleep
   }
}
