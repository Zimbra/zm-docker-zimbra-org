package Zimbra::TaskDispatch;

use strict;
use warnings;

use base 'Exporter';
our $VERSION   = '1.00';
our @EXPORT_OK = qw(Dispatch);

sub Dispatch
{
   my %args = @_;

   my $dispatch_type = ( $args{seq} ? "seq" : ( $args{par} ? "par" : undef ) ) || die "dispatch type 'seq' or 'par' not specified";
   my $actions        = $args{seq}            || $args{par} || die "actions not specified";
   my $invoke_level   = $args{invoke_level}   || 0;
   my $invoke_wrapper = $args{invoke_wrapper} || sub { my $fun_info = shift; $fun_info->{func}(); };

   die "actions is not array ref"
     if ( ref($actions) ne "ARRAY" );

   my $invoke_seq = 0;
   my @children   = ();

   while (@$actions)
   {
      my $action_name = !ref( $actions->[0] ) ? shift(@$actions) : undef;
      my $action_ref = shift(@$actions);

      die "unsupported action: dispatch_type => $dispatch_type, action_name => @{[$action_name || '']}, invoke_level => $invoke_level, invoke_seq => $invoke_seq, action_ref = @{[ref($action_ref)]}"
        if ( !grep { ref($action_ref) eq $_ } ( "CODE", "ARRAY" ) );

      my $pid;
      $pid = fork() // die "could not fork: $!"
        if ( $dispatch_type eq "par" );

      # seq case - $pid is undef - fork failure is already handled
      # par case - $pid is defined, $pid is 0 - child
      # par case - $pid is defined, $pid is !0 - parent

      if ( defined $pid && $pid != 0 )
      {
         push( @children, $pid );
      }
      else
      {
         if ( ref($action_ref) eq "CODE" )
         {
            my $func_ref = $action_ref;
            my $func_name = $action_name || "func-$invoke_level-$invoke_seq";

            $invoke_wrapper->(
               {
                  func_ref      => $func_ref,
                  func_name     => $func_name,
                  invoke_level  => $invoke_level,
                  invoke_seq    => $invoke_seq,
                  dispatch_type => $dispatch_type
               }
            );
         }
         elsif ( ref($action_ref) eq "ARRAY" )
         {
            my $sub_actions = $action_ref;
            my $sub_dispatch_type = $action_name || "seq";

            Dispatch( $sub_dispatch_type => $sub_actions, invoke_wrapper => $invoke_wrapper, invoke_level => $invoke_level + 1 );
         }

         exit(0)
           if ( defined $pid );
      }

      ++$invoke_seq;
   }

   map { waitpid( $_, 0 ); } @children;

   return;
}

=pod
use Zimbra::TaskDispatch;

use strict;

Dispatch(
   seq => [
      a => sub {
         print "Hello One\n";
      },
      b => sub {
         print "Hello Two\n";
      },
      c => sub {
         print "Hello Three\n";
      },
      par => [
         sub {
            for ( my $i = 0 ; $i < 10 ; ++$i )
            {
               print "Hello Par One: $i\n";
               sleep(1);
            }
         },
         sub {
            for ( my $i = 0 ; $i < 5 ; ++$i )
            {
               print "Hello Par Two: $i\n";
               sleep(1);
            }
         },
         sub {
            for ( my $i = 0 ; $i < 5 ; ++$i )
            {
               print "Hello Par Three: $i\n";
               sleep(1);
            }
         },
      ],
   ],
   invoke_wrapper => sub {
      my $func_info = shift;
      print "BEGIN : $func_info->{action_name} : " . ( "x" x ( 1 + $func_info->{invoke_level} ) ) . " : " . $func_info->{invoke_seq} . "\n";
      $func_info->{func_ref}();
      print "END   : $func_info->{action_name} : " . ( "x" x ( 1 + $func_info->{invoke_level} ) ) . " : " . $func_info->{invoke_seq} . "\n";
     }
);
=cut

1;
