package ToolBox::Mungers::dateMMDDYY;

use Modern::Perl;

=pod

=head1 ToolBox::Mungers::dateMMDDYY

Convert dates in the format mm/dd/yy to ISO

=cut

sub munge {
    my ( $class, $data ) = @_;

    $data =~ s/ //g;

    my ( $month, $day, $year ) = $data =~ /(\d+).(\d+).(\d+)/;
    if ( $month && $day && $year ) {
        my @time     = localtime();
        my $thisyear = $time[5] + 1900;
        $thisyear = substr( $thisyear, 2, 2 );
        if ( $year < $thisyear ) {
            $year += 2000;
        }
        elsif ( $year < 100 ) {
            $year += 1900;
        }
        $data = sprintf "%4d-%02d-%02d", $year, $month, $day;
        if ( $data eq "0000-00-00" ) {
            $data = $NULL_STRING;
        }
    }
    else {
        $data = q{};
    }

    return $data;
}

1;
