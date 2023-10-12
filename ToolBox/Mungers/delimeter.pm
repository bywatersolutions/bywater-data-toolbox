package ToolBox::Mungers::delimiter;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    return "$data ; ";
}

1;
