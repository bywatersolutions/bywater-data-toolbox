package ToolBox::Mungers::money;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    $data =~ s/[^0-9\.]//g;
    return $data;
}

1;
