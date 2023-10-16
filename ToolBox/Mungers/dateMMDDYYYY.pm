package ToolBox::Mungers::dateMMDDYYYY;

use Modern::Perl;

=pod

=head1 dateMMDDYYYY

=head2 munge

Convert dates in the format mm/dd/yyyy to ISO

=cut

sub munge {
    my ( $class, $data ) = @_;

    $data =~ s/ //g;
    if ( $data ne "0" ) {
        my $year  = substr( $data, 6, 4 );
        my $month = substr( $data, 0, 2 );
        my $day   = substr( $data, 3, 2 );
        if ( $month && $day && $year ) {
            $data = sprintf "%4d-%02d-%02d", $year, $month, $day;
            if ( $data eq "0000-00-00" ) {
                $data = q{};
            }
        }
        else {
            $data = q{};
        }
    }

    return $data;
}

1;
