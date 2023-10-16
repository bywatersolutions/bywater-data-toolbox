package ToolBox::Mungers::lc;

use Modern::Perl;

=pod

=head1 lc

=head2 munge

Converts the entire string to lower case.

=cut

sub munge {
    my ( $class, $data ) = @_;
    return lc $data;
}

1;
