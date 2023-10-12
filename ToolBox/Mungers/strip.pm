package ToolBox::Mungers::strip;

use Modern::Perl;

sub munge {
    my ( $class, $data ) = @_;
    $data =~ s/,//g;
    return $data;
}

1;
