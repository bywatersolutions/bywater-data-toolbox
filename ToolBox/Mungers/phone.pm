package ToolBox::Mungers::phone;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    $data =~ s/ //g;
    if ( length($data) == 10 ) {
        my $area     = substr( $data, 0, 3 );
        my $exchange = substr( $data, 3, 3 );
        my $number   = substr( $data, 6, 4 );
        $data = "(" . $area . ")" . $exchange . "-" . $number;
    }
    return $data;
}

1;
