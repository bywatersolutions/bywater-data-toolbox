package ToolBox::Mungers::dateMMDDYYYYT;

use Modern::Perl;

=pod

=head1 ToolBox::Mungers::dateMMDDYYYYT

Convert dates in the format mm/dd/yyyy 0:00... or m/d/yyyy 0:00 to ISO

=cut

sub munge {
    my ( $class, $data ) = @_;

    $data =~ s/PM\s*//;
    $data =~ s/AM\s*//;

    $data =~ s/\d+:\d\d//;
    $data =~ s/ //g;
    my ( $month, $day, $year ) = $data =~ /(\d+).(\d+).(\d+)/;
    if ( $month && $day && $year ) {
        if ( length($year) == 2 ) {
            $year = '20' . $year;
        }
        $data = sprintf "%4d-%02d-%02d", $year, $month, $day;
        if ( $data eq "0000-00-00" ) {
            $data = '';
        }
    }
    else {
        $data = '';
    }

    return $data;
}

1;
