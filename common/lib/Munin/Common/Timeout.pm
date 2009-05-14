use warnings;
use strict;

package Munin::Common::Timeout;
use base qw(Exporter);

use Carp;
use English qw(-no_match_vars);


BEGIN {
    our @EXPORT = qw(
        &do_with_timeout
        &reset_timeout
    );
}


my $current_timeout;


sub do_with_timeout {
    my ($timeout, $block) = @_;

    croak "Argument exception: \$timeout" 
        unless $timeout && $timeout =~ /^\d+$/;
    croak "Argument exception: \$block" 
        unless ref $block eq 'CODE';

    my $old_alarm           = alarm 0;
    my $old_handler         = $SIG{ALRM};
    my $old_current_timeout = $current_timeout;

    $current_timeout = $timeout;

    eval {
        local $SIG{ALRM} = sub { die "alarm\n" };
        alarm $timeout;
        $block->();
    };
    my $err = $EVAL_ERROR;

    my $remaining_alarm = alarm 0;

    $SIG{ALRM} = $old_handler ? $old_handler : 'DEFAULT';

    $current_timeout = $old_current_timeout;

    if ($old_alarm) {
	my $old_alarm = $old_alarm - $timeout + $remaining_alarm;
	if ($old_alarm > 0) {
	    alarm($old_alarm);
	} 
        else {
            #It should have gone off already - so set it off
	    kill 'ALRM', $$;
	}
    }

    if ($err) {
        return if $EVAL_ERROR eq "alarm\n";
        die;  # Propagate any other exceptions
    }

    return 1;
}


sub reset_timeout {
    alarm $current_timeout;
}


1;


__END__


=head1 NAME

Munin::Common::Timeout - Run code with a timeout.


=head1 SYNOPSIS

 use Munin::Common::Timeout;

 do_with_timeout(5, sub {
     # ...
     reset_timout(); # If needed
     # ...
 });


=head1 DESCRIPTION

See also L<Time::Out>, L<Sys::AlarmCall>

=head1 SUBROUTINES

=over

=item B<do_with_timeout>

 my $finished_with_no_timeout = do_with_timeout($seconds, $block)
     or die "Timed out!";

Executes $block with a timeout of $seconds.  Returns true if it 
completed within the timeout.  If the timeout is reached and the 
code is still running, it halts it and returns false.

Calls to do_with_timeout() can be nested.  Any exceptions raised 
by $block are propagated.

=item B<reset_timeout>

 reset_timeout();

When called from within $block, resets its timeout to its original
value.

=back

