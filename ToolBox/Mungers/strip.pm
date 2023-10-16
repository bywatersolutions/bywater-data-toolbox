package ToolBox::Mungers::strip;

use Modern::Perl;

=pod

=head1 strip

=head2 munge

Removes all commas from a string. E.g. "1,2,3" becomes "123".

=cut

sub munge {
    my ( $class, $data ) = @_;
    $data =~ s/,//g;
    return $data;
}

1;
