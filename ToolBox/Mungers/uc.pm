package ToolBox::Mungers::uc;

use Modern::Perl;

=pod

=head1 uc

=head2 munge

Converts the data to all uppercase.

=cut

sub munge {
    my ( $class, $data ) = @_;
    return uc $data;
}

1;
