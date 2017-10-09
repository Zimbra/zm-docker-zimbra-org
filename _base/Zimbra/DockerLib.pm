package Zimbra::DockerLib;

use strict;
use warnings;

our $VERSION = '1.00';
use base 'Exporter';
our @EXPORT = qw(EntryExec Secret Config);

sub EntryExec
{
   my $name  = shift;
   my $steps = shift;

   my $BENCH_START = time();

   print "SERVICE $name : INITIALIZING ...\n";

   my $step_count = 0;

   for my $step (@$steps)
   {
      my $sname = "" . ++$step_count . " of " . scalar(@$steps);

      my $STEP_BENCH_START = time();

      if ( my $entry = $step->{exec} )
      {
         print "STEP $sname : $entry->{desc} ...\n";

         _ExCmd( $step->{exec} );
      }
      elsif ( $entry = $step->{wait_for} )
      {
         print "STEP $sname : Waiting for $entry->{service} ...\n";

         _WaitForService( $entry->{service}, $entry->{check_url} );
      }
      else
      {
         die "Unknown entry";
      }

      chomp( my $STEP_BENCH_DURATION = `date -u '+%Hh %Mm %Ss' -d '@@{[time() - $STEP_BENCH_START]}' | sed -e 's/00[hm] \\?//g' -e 's/\\<0//g'` );

      print "STEP $sname : TOOK $STEP_BENCH_DURATION\n";
   }

   chomp( my $BENCH_DURATION = `date -u '+%Hh %Mm %Ss' -d '@@{[time() - $BENCH_START]}' | sed -e 's/00[hm] \\?//g' -e 's/\\<0//g'` );

   print "SERVICE $name : INITIALIZED IN $BENCH_DURATION\n";

   system("./healthcheck.py");    # start simple healthcheck so other nodes in the cluster can coordinate startup  # FIXME add this explicitly?
}

sub _ExCmd
{
   my $args = shift;

   my $user = $args->{user} || "zimbra";
   my $script = ( $args->{script} || "" ) . "\n";

   open( FD, "|-" ) or exec( "sudo", "su", "-l", $user, "-c", "bash -s" );

   print FD "echo ==================================================================\n";
   print FD "echo 'USER : $user\n'";
   print FD "export TIMEFORMAT='r: %R, u: %U, s: %S'\n";
   print FD "set -u\n";
   print FD "set -x\n";
   print FD $script . "\n";
   print FD "echo ==================================================================\n";

   close(FD);

   return $?;
}

sub _WaitForService
{
   my $name = shift;
   my $url  = shift || "http://$name:5000/";
   my $c    = 0;
   while (1)
   {
      chomp( my $o = `curl --silent --output /dev/null --write-out "%{http_code}" '$url'` );
      last if ( $o eq "200" );
      print "waiting for $name service\n" if ( $c % 30 eq "0" );
      sleep(1);
      ++$c;
   }

   print "$name service available\n";
}

sub _ReadFile
{
   my $dir   = shift;
   my $fname = shift;

   my $file = "$dir/$fname";

   my $r;

   {
      local $/;
      open( my $FD, "<", $file ) or die "missing '$fname' (scope: $dir) - $!";
      $r = <$FD>;
   }

   return $r;
}

sub Secret
{
   my $name = shift;
   chomp( my $r = _ReadFile( "/var/run/secrets", $name ) );
   return $r;
}

sub Config
{
   my $name = shift;
   chomp( my $r = _ReadFile( "/", $name ) );
   return $r;
}

1;
