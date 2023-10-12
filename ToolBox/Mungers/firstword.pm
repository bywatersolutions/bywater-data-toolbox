package ToolBox::Mungers::firstword;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    ( $data, undef ) = split( / /, $data );
    return $data;
}

1;
