package ToolBox::Mungers::firstword;

use Modern::Perl;

=pod

=head1 firstword

=head2 munge

Returns only the first word of the given data ( e.g. "This is a test" becomes "This" ).

=cut

sub munge {
    my ( $class, $data ) = @_;
    ( $data, undef ) = split( / /, $data );
    return $data;
}

1;
