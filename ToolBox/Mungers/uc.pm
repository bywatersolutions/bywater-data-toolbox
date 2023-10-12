package ToolBox::Mungers::uc;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    return uc $data;
}

1;
