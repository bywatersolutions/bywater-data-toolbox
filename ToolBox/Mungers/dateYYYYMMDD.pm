package ToolBox::Mungers::dateYYYYMMDD;

use Modern::Perl;

=pod

=head1 dateYYYYMMDD

=head2 munge

Convert dates in the format YYYYMMDD to ISO

=cut

sub munge {
    my ( $class, $data ) = @_;

    $data =~ s/ //g;
    if ( $data ne "0" ) {
        my $year  = substr( $data, 0, 4 );
        my $month = substr( $data, 4, 2 );
        my $day   = substr( $data, 6, 2 );
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
