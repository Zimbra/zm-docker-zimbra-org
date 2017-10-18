package Zimbra::DockerLib;

use strict;
use warnings;

use POSIX qw(setgid setuid strftime dup2);
use Data::Dumper;
use Term::ANSIColor;
use Zimbra::TaskDispatch;
use Time::HiRes qw(usleep);
use File::Copy;

our $VERSION = '1.00';
use base 'Exporter';
our @EXPORT = qw(EntryExec Secret Config _EvalExecAs);

BEGIN
{
   #   $ENV{ANSI_COLORS_DISABLED} = 1 if ( !-t STDOUT );
}

my $BENCH_START = time();
chomp( my $this_host = `hostname` );

sub _ColorPrintln
{
   my $color       = shift;
   my $prefix      = shift;
   my $msg         = shift;
   my $delta_start = shift;

   my $date_str = strftime( "%F %T %z", localtime() );

   print color($color) . sprintf( "%s :: %-10s :: %-10s :: %-50s :: %-8s :: %-8s", $date_str, $this_host, $prefix, $msg, $delta_start ? _TimeDurationStr($delta_start) : "", _TimeDurationStr($BENCH_START) ) . color('reset') . "\n";
}

sub _TimeDurationStr
{
   my $time_pt = shift;

   my $duration = time() - $time_pt;

   my $sec   = $duration % 60;
   my $min   = int( ( $duration % 3600 ) / 60 );
   my $hours = int( ( $duration % 86400 ) / 3600 );

   return sprintf( "%02d:%02d:%02d", $hours, $min, $sec );
}

sub EntryExec(%);

my %MAPPING = (
   local_config => {
      desc => "Setting local config...",
      impl => \&_LocalConfig,
   },
   install_keys => {
      desc => "Installing keys...",
      impl => \&_InstallKeys,
   },
   global_config => {
      desc => "Setting global config...",
      impl => \&_GlobalConfig,
   },
   wait_for => {
      desc => "Waiting for service...",
      impl => sub {
         my $a = shift;
         _WaitForService($_)
           foreach ( $a->{service} || (), @{ $a->{services} || [] } );
      },
   },
   exec => {
      desc => undef,
      impl => sub {
         my $a = shift;

         foreach my $entry ( ref($a) eq "ARRAY" ? @$a : $a )
         {
            $entry->{user} ||= "zimbra";
            _ExecAs($entry);
         }
      },
   },
   server_config => {
      desc => "Setting server config...",
      impl => sub {
         my $entry  = shift;
         my $server = ( keys %$entry )[0];

         _ServerConfig( $server, $entry->{$server} );
      },
   },
   cos_config => {
      desc => "Setting cos config...",
      impl => sub {
         my $entry  = shift;
         my $cos_name = ( keys %$entry )[0];

         _CosConfig( $cos_name, $entry->{$cos_name} );
      },
   },
   publish_service => {
      desc => "Publishing service...",
      impl => sub {
         my $entry = shift;
         _ExecAs( { user => "root", args => ["./healthcheck.py"], bg => 1 } );
      },
   },
);

sub EntryExec(%)
{
   my %args = @_;

   _ColorPrintln( 'green', "SERVICE", "INITIALIZING ..." );

   Dispatch(
      %args,
      invoke_wrapper => sub {
         my $func_info = shift;

         my $step_data = $func_info->{func_ref}() || die "step data not provided";

         if ( my $impl_name = ( grep { $step_data->{$_} } keys %MAPPING )[0] )
         {
            my $impl = $MAPPING{$impl_name}->{impl};
            my $desc = $step_data->{desc} || $MAPPING{$impl_name}->{desc};

            my $step_start = time();
            _ColorPrintln( 'yellow', "BEGIN", $desc, $step_start );
            $impl->( $step_data->{$impl_name} );
            _ColorPrintln( 'yellow', "END", $desc, $step_start );
         }
         else
         {
            die "unsupported implementation for: " . Data::Dumper->new( [$step_data], ["step"] )->Dump();
         }
      },
   );

   _ColorPrintln( 'green', "SERVICE", "INITIALIZED" );
   print "(^C to exit)\n";

   wait();
   _ExecAs( { user => "root", args => [ "sleep", "infinity" ] } );
}

sub _WaitForService
{
   my $name = shift;
   my $url = shift || "http://$name:5000/";

   my $c = 0;
   while (1)
   {
      chomp( my $o = `curl --silent --output /dev/null --write-out "%{http_code}" '$url'` );
      last if ( $o eq "200" );
      print "waiting for $name service\n" if ( $c % 30 eq "0" );
      usleep(250000);
      ++$c;
   }

   print "$name service available\n";
}

sub _ExecAs
{
   my $opts = shift;

   my $child_pid = fork() // die "fork failed $!";
   if ($child_pid)
   {
      if ( $opts->{bg} )
      {
         return { status => $?, child_pid => $child_pid, };
      }
      else
      {
         waitpid( $child_pid, 0 );
         return { child_pid => $child_pid, };
      }
   }
   else
   {
      my @user = getpwnam( $opts->{user} );

      my @sec_groups;
      while ( my @gr_entry = getgrent() )
      {
         push( @sec_groups, $gr_entry[2] )
           if ( grep { $_ eq $opts->{user} } split( ',', $gr_entry[3] ) );
      }
      endgrent();

      $( = $user[3];
      $) = join( ' ', $user[3], @sec_groups );
      $< = $user[2];
      $> = $user[2];

      $ENV{LOGNAME} = $user[0];
      $ENV{USER}    = $user[0];
      $ENV{HOME}    = $user[7];
      $ENV{SHELL}   = $user[8];

      dup2( 1, 2 );

      chdir( $opts->{cd} )
        if ( $opts->{cd} );

      exec( @{ $opts->{args} } ) or die "exec failed $!";
   }
}

sub _EvalExecAs
{
   my $user = shift;
   my $opts = shift;

   my $child_pid = open( my $read_fh, "-|" ) // die "fork failed $!";
   if ($child_pid)
   {
      local $/;
      my $r = <$read_fh>;

      waitpid( $child_pid, 0 );

      return { result => $r, status => $?, child_pid => $child_pid };
   }
   else
   {
      my @user = getpwnam($user);
      $( = $user[3];
      $) = $user[3];
      $< = $user[2];
      $> = $user[2];
      exec(@$opts) or die "exec failed $!";
   }
}

sub _VersionInfo
{
   my $dir = "/zimbra/release";
   my @v = split( /[.]/, _ReadFile( $dir, ".BUILD_RELEASE_NO", 1 ) );

   return {
      major => $v[0],
      minor => $v[1],
      micro => $v[2],
      type  => _ReadFile( $dir, ".BUILD_RELEASE_CANDIDATE", 1 ),
      build => _ReadFile( $dir, ".BUILD_NUM", 1 ),
   };
}

sub _InstallKeys
{
   my $args = shift;

   unlink( $args->{dest} );

   copy( "/var/run/secrets/$args->{name}", $args->{dest} ) || die "Could not copy $args->{name} to $args->{dest}\n";

   my ( $login, $pass, $uid, $gid ) = getpwnam( $args->{user} || "zimbra" );

   chown( $uid, $gid, $args->{dest} );
   chmod( $args->{mode}, $args->{dest} );
}

sub _LocalConfig
{
   my $params = shift;

   _DumpParams($params);

   return _ExecAs(
      {
         user => "zimbra",
         args => [
            "/opt/zimbra/bin/zmlocalconfig", "-f", "-e",
            map { "$_=$params->{$_}"; } keys %$params
         ],
      }
   );
}

sub _ServerConfig
{
   my $server = shift;
   my $params = shift;

   my $vinfo = _VersionInfo();

   $params->{zimbraServerVersionMajor} = $vinfo->{major};
   $params->{zimbraServerVersionMinor} = $vinfo->{minor};
   $params->{zimbraServerVersionMicro} = $vinfo->{micro};
   $params->{zimbraServerVersionType}  = $vinfo->{type};
   $params->{zimbraServerVersionBuild} = $vinfo->{build};
   $params->{zimbraServerVersion}      = "$vinfo->{major}_$vinfo->{minor}_$vinfo->{micro}_$vinfo->{type}_$vinfo->{build}";

   _DumpParams($params);

   _ExecAs(
      {
         user => "zimbra",
         args => [
            "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "cs", $server
         ],
      }
   );

   return _ExecAs(
      {
         user => "zimbra",
         args => [
            "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "ms", $server,
            map
            {
               my $k = $_;
               ref( $params->{$k} ) eq "ARRAY" ? map { ( $k, $_ ) } @{ $params->{$k} } : ( $k, $params->{$k} );
              } keys %$params
         ],
      }
   );
}

sub _CosConfig
{
   my $cos_name = shift;
   my $params   = shift;

   _DumpParams($params);

   return _ExecAs(
      {
         user => "zimbra",
         args => [
            "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "mc", $cos_name,
            map
            {
               my $k = $_;
               ref( $params->{$k} ) eq "ARRAY" ? map { ( $k, $_ ) } @{ $params->{$k} } : ( $k, $params->{$k} );
              } keys %$params
         ],
      }
   );
}

sub _DumpParams
{
   my $params = shift;

   print Data::Dumper->new(
      [
         {
            map { $_ => ( $_ =~ /password|key|cert/i ? '*' : $params->{$_} ); } keys %$params
         }
      ],
      ["params"]
   )->Dump();
}

sub _GlobalConfig
{
   my $params = shift;

   _DumpParams($params);

   return _ExecAs(
      {
         user => "zimbra",
         args => [
            "/opt/zimbra/bin/zmprov", "-r", "-m", "-l", "mcf",
            map
            {
               my $k = $_;
               ref( $params->{$k} ) eq "ARRAY" ? map { ( $k, $_ ) } @{ $params->{$k} } : ( $k, $params->{$k} );
              } keys %$params
         ],
      }
   );
}

sub _ReadFile
{
   my $dir     = shift;
   my $fname   = shift;
   my $chompit = shift || 0;

   my $file = "$dir/$fname";

   my $r;

   {
      local $/;
      open( my $FD, "<", $file ) or die "missing '$fname' (scope: $dir) - $!";
      $r = <$FD>;
   }

   chomp($r) if ($chompit);
   return $r;
}

sub Secret
{
   my $name = shift;
   return _ReadFile( "/var/run/secrets", $name, 1 );
}

sub Config
{
   my $name = shift;
   return _ReadFile( "/", $name, 1 );
}

1;
