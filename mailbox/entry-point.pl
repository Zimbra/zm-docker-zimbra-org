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

my $SOLR_MODE                     = $ENV{'SOLR_MODE'};

## SECRETS AND CONFIGS #################################

my $DOMAIN_NAME                   = Config("domain_name");
my $LDAP_MASTER_PASSWORD          = Secret("ldap.master_password");
my $LDAP_ROOT_PASSWORD            = Secret("ldap.root_password");
my $MYSQL_PASSWORD                = Secret("mysql.password");
my $ADMIN_ACCOUNT_NAME            = Config("admin_account_name");
my $ADMIN_PASSWORD                = Secret("admin_account_password");
my $SPAM_ACCOUNT_NAME             = Config("spam_account_name");
my $SPAM_PASSWORD                 = Secret("spam_account_password");
my $HAM_ACCOUNT_NAME              = Config("ham_account_name");
my $HAM_PASSWORD                  = Secret("ham_account_password");
my $VIRUS_QUARANTINE_ACCOUNT_NAME = Config("virus_quarantine_account_name");
my $VIRUS_QUARANTINE_PASSWORD     = Secret("virus_quarantine_account_password");
my $GAL_SYNC_ACCOUNT_NAME         = Config("gal_sync_account_name");

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
my $SPAM_ACCOUNT             = "$SPAM_ACCOUNT_NAME\@$DOMAIN_NAME";
my $HAM_ACCOUNT              = "$HAM_ACCOUNT_NAME\@$DOMAIN_NAME";
my $VIRUS_QUARANTINE_ACCOUNT = "$VIRUS_QUARANTINE_ACCOUNT_NAME\@$DOMAIN_NAME";
my $GAL_SYNC_ACCOUNT         = "$GAL_SYNC_ACCOUNT_NAME\@$DOMAIN_NAME";

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
               imap_max_consecutive_error       => 0,
               pop3_max_consecutive_error       => 0,
            },
         };
      },

      sub { { install_keys => { name => "ca.key",      dest => "/opt/zimbra/conf/ca/ca.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "ca.pem",      dest => "/opt/zimbra/conf/ca/ca.pem", mode => oct(644), }, }; },
      sub { { install_keys => { name => "mailbox.key", dest => "/opt/zimbra/conf/jetty.key", mode => oct(600), }, }; },
      sub { { install_keys => { name => "mailbox.crt", dest => "/opt/zimbra/conf/jetty.crt", mode => oct(644), }, }; },

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
                  zimbraSSLCertificate            => Secret("mailbox.crt"),
                  zimbraSSLPrivateKey             => Secret("mailbox.key"),
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
               zimbraIndexURL                              => $SOLR_MODE eq "cloud" ? "solrcloud:$SOLR_HOST:9983" : "solr:http://$SOLR_HOST:8983/solr",
               zimbraEventBackendURL                       => $SOLR_MODE eq "cloud" ? "solrcloud:$SOLR_HOST:9983" : "solr:http://$SOLR_HOST:8983/solr",
            },
         };
      },

      # FIXME - requires LDAP
      #sub { { desc => "Updating IP Settings", exec => { args => ["/opt/zimbra/libexec/zmiptool"], }, }; },
      sub { { desc => "Starting ssh-server", exec => { user => "root", args => [ "/usr/sbin/service", "ssh", "start" ], }, }; },

      # FIXME - requires LDAP
      sub { { desc => "Bringing up all services", exec => { args => [ "/opt/zimbra/bin/zmcontrol", "start" ], }, }; },

      #######################################################################

      sub { { wait_for => { services => [ $MYSQL_HOST, ], }, }; },
      sub {
         {
            desc => "Admin Account",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "ca", $ADMIN_ACCOUNT, $ADMIN_PASSWORD, "description", 'Administrative Account',
                  "zimbraIsAdminAccount", "TRUE", "zimbraAdminConsoleUIComponents", "cartBlancheUI"
               ],
            },
         };
      },
      sub { { desc => "Common Admin Alias", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "aaa", "$ADMIN_ACCOUNT", "root\@$DOMAIN_NAME" ], }, }; },
      sub { { desc => "Common Admin Alias", exec => { args => [ "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "aaa", $ADMIN_ACCOUNT, "postmaster\@$DOMAIN_NAME" ], }, }; },

      #######################################################################

      sub { { wait_for => { services => [ $SMTP_HOST, ], }, }; },
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

      #######################################################################

      sub { { configure_staf => {}, }; },

      #######################################################################

      sub { { publish_service => {}, }; },

      #######################################################################

      sub {
         {
            desc => "Spam Account",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "ca", $SPAM_ACCOUNT, $SPAM_PASSWORD, "description", "System account for spam training.",
                  "amavisBypassSpamChecks", "TRUE", "zimbraAttachmentsIndexingEnabled", "FALSE", "zimbraIsSystemResource", "TRUE", "zimbraIsSystemAccount", "TRUE", "zimbraHideInGal", "TRUE", "zimbraMailQuota", "0"
               ],
            },
         };
      },
      sub {
         {
            desc => "Ham Account",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "ca", $HAM_ACCOUNT, $HAM_PASSWORD, "description", "System account for Non-Spam (Ham) training.",
                  "amavisBypassSpamChecks", "TRUE", "zimbraAttachmentsIndexingEnabled", "FALSE", "zimbraIsSystemResource", "TRUE", "zimbraIsSystemAccount", "TRUE", "zimbraHideInGal", "TRUE", "zimbraMailQuota", "0"
               ],
            },
         };
      },
      sub {
         {
            desc => "Virus Quarantine Account",
            exec => {
               args => [
                  "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "ca", $VIRUS_QUARANTINE_ACCOUNT, $VIRUS_QUARANTINE_PASSWORD, "description", "System, account for Anti-virus quarantine.",
                  "amavisBypassSpamChecks", "TRUE", "zimbraAttachmentsIndexingEnabled", "FALSE", "zimbraIsSystemResource", "TRUE", "zimbraIsSystemAccount", "TRUE", "zimbraHideInGal", "TRUE", "zimbraMailMessageLifetime", "30d",
                  "zimbraMailQuota", "0"
               ],
            },
         };
      },
      sub {
         {
            desc => "GAL Sync Account",
            exec => { args => [ "/opt/zimbra/bin/zmgsautil", "createAccount", "-a", $GAL_SYNC_ACCOUNT, "-n", "InternalGAL", "--domain", $DOMAIN_NAME, "-s", $THIS_HOST, "-t", "zimbra", "-f", "_InternalGAL" ], },
         };
      },
      sub {
         {
            global_config => {
               zimbraSpamIsSpamAccount       => $SPAM_ACCOUNT,
               zimbraSpamIsNotSpamAccount    => $HAM_ACCOUNT,
               zimbraAmavisQuarantineAccount => $HAM_ACCOUNT,
            },
         };
      },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_adminversioncheck.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_attachcontacts.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_attachmail.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_bulkprovision.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_cert_manager.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_clientuploader.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_date.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_email.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_mailarchive.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_phone.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_proxy_config.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_srchhighlighter.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_tooltip.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_url.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_viewmail.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_webex.zip", ], }, }; },
      sub { { desc => "Zimlet", exec => { args => [ "/opt/zimbra/bin/zmzimletctl", "-l", "deploy", "zimlets/com_zimbra_ymemoticons.zip", ], }, }; },
      sub {
         {
            cos_config => {
               default => {
                  zimbraPrefTimeZoneId           => "UTC",
                  zimbraFeatureTasksEnabled      => "TRUE",
                  zimbraFeatureBriefcasesEnabled => "TRUE",
                  zimbraFeatureNotebookEnabled   => "TRUE",
                  zimbraZimletAvailableZimlets   => [ "!com_zimbra_attachcontacts", "!com_zimbra_date", "!com_zimbra_email", "!com_zimbra_attachmail", "!com_zimbra_url" ],
               },
            },
         };
      },
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
