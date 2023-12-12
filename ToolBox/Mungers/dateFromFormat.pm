package ToolBox::Mungers::dateFromFormat;

use Modern::Perl;
use DateTime::Format::Strptime;

=pod

=head1 dateFromFormat

=item munge

Convert dates from an arbitrary format to ISO.
Pattern token documentation can be found here: https://metacpan.org/pod/DateTime::Format::Strptime#STRPTIME-PATTERN-TOKENS
e.g. --col "<header>:<column>~dateFromFormat~%Y%m%d"

=cut

sub munge {
    my ( $class, $date, $pattern) = @_;

    $date =~ s/ //g;
    if ( $date ne "0" ) {
        my $format = DateTime::Format::Strptime->new(
            pattern   => $pattern,
            time_zone => 'local',
        );
        my $dt = $format->parse_datetime($date);
        $date = $dt->ymd('-') if $dt;
    }

    return $date;
}

1;
