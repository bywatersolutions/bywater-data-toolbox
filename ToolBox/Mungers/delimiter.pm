package ToolBox::Mungers::delimiter;

use Modern::Perl;

=head1 delimeter

=head2 munge

Appends a semicolon with spaces to the data, e.g. "Test" becomes "Test ; ".

=cut

sub munge {
    my ( $class, $data ) = @_;
    return "$data ; ";
}

1;
