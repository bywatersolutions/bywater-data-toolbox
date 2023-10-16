package ToolBox::Mungers::money;

use Modern::Perl;

=pod

=head1 money

=head2 munge

Removes non-numeric characters ( or periods ) from a string"
e.g. "$12.00" becomse "12.00". Does not force precision.

=cut

sub munge {
    my ( $class, $data ) = @_;
    $data =~ s/[^0-9\.]//g;
    return $data;
}

1;
