#!/usr/bin/env perl

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# This program comes with ABSOLUTELY NO WARRANTY;

use Modern::Perl;

use utf8;

use Getopt::Long;
use List::MoreUtils qw(none);
use Text::CSV;
use Try::Tiny qw(catch try);

use Koha::Biblio::ItemGroups;
use Koha::Biblio::ItemGroup::Items;
use Koha::Items;

binmode STDOUT, ':encoding(UTF-8)';
binmode STDERR, ':encoding(UTF-8)';

my $help;
my $file;
my $sep_char = ",";
my $separator;

my $usage = <<'ENDUSAGE';

    perl koha_itemgroups_loader.pl --file file.csv 2> item_groups.err

This script generates item groups based on an input file containing:

    barcode,description

Options:
    --file <file>     CSV data file
    --sep             valid values are 'comma' (default), 'tab' or 'pipe'
    -h --help         this message

ENDUSAGE

my $result = GetOptions(
    'f|file:s' => \$file,
    'h|help'   => \$help,
    'sep:s'    => \$separator,
);

if ( !$result ) {
    print $usage;
    exit;
}

if ($help) {
    print $usage;
    exit;
}

unless ($file) {
    print STDERR "-f or --file is mandatory \n$usage";
    exit 1;
}

if ($separator) {
    if ( none { $separator eq $_ } qw{comma tab pipe} ) {
        print STDERR "'$separator' is not a valid separator. Pick 'comma', 'tab' or 'pipe' \n$usage";
        exit 1;
    } else {
        $sep_char =
              ( $separator eq 'comma' ) ? ','
            : $separator eq 'tab'       ? "\t"
            :                             '|';
    }
}

# Open the file
my $csv = Text::CSV->new( { binary => 1, auto_diag => 1, sep_char => $sep_char } );
open my $fh, "<:encoding(utf8)", $file or die "file: $!";

my $biblio_to_itemgroups = {};
my $processed_items      = {};

# Read the header row
my $header    = $csv->getline($fh);
my %col_index = map { $header->[$_] => $_ } 0 .. $#$header;

# load the data in memory
while ( my $row = $csv->getline($fh) ) {

    my $barcode     = $row->[ $col_index{'barcode'} ];
    my $description = $row->[ $col_index{'description'} ];

    my $item = Koha::Items->find( { barcode => $barcode } );

    if ( !$item ) {    # skip if item not found
        print STDERR "ERROR - Barcode not found on DB: \"$barcode\"\n";
        next;
    }

    if ( $processed_items->{$barcode} ) {
        print STDERR "ERROR - Duplicated barcode: \"$barcode\"\n";
        next;
    } else {

        # mark the description/barcode combination as already processed
        $processed_items->{$barcode} = 1;
    }

    my $existing_item_group = Koha::Biblio::ItemGroup::Items->find( { item_id => $item->id } );
    if ($existing_item_group) {
        print STDERR sprintf("ERROR - Barcode (%s) already in item group (%s)\n", $barcode, $existing_item_group->id);
        next;
    }

    my $biblio_id = $item->biblionumber;

    # we got here, the biblio exists, the barcode hasn't been processed yet
    # let's check if the item group exists
    my $item_group;
    if ( !$biblio_to_itemgroups->{$biblio_id}->{$description}->{item_group_id} ) {
        $item_group = Koha::Biblio::ItemGroup->new(
            {
                biblio_id   => $biblio_id,
                description => $description,
            }
        )->store();
        $biblio_to_itemgroups->{$biblio_id}->{$description}->{item_group_id} = $item_group->id;
        print STDOUT
            sprintf( "OK: Created item group '%s' (%s) on biblio '%s'\n", $description, $item_group->id, $biblio_id );
    } else {
        $item_group =
            Koha::Biblio::ItemGroups->find( $biblio_to_itemgroups->{$biblio_id}->{$description}->{item_group_id} );
    }

    # we have an item group, let's add the item
    $item_group->add_item( { item_id => $item->id } );
    print STDOUT sprintf( "OK: Added '%s' to item group '%s' (%s)\n", $barcode, $description, $item_group->id );
}

close $fh;

1;
