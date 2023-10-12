package ToolBox::Mungers::lc;

use Modern::Perl;

sub munge {
    my ( $class, $datum ) = @_;
    return lc $datum;
}

1;
