#!/usr/bin/perl

use Modern::Perl;

use Data::Dumper;
use File::Slurp;
use FindBin;
use Getopt::Long::Descriptive;
use Module::Load;
use Readonly;
use Text::CSV::Slurp;
use Try::Tiny;
use Module::Find;
use Pod::Perldoc;

use lib "$FindBin::Bin";
use lib "/usr/share/koha/lib/";

require Koha::Database;

Readonly my $mungers             => "ToolBox::Mungers::";
Readonly my $option_params_regex => qr/(\w+):([\w\/\.-]+)~?(\w+)?~?(.*)?/;

my ( $opt, $usage ) = describe_options(
    '%c %o ',
    [ 'in|i=s',  "Incoming CSV file", { required => 1 } ],
    [ 'out|o=s', "Resulting CSV file", ],
    [ 'sql=s',   "Resulting SQL file", ],
    [],
    [ 'table|t=s', "Koha table to operate on", ],
    [],
    [
        'col=s@',
        "<header>:<column>[~<tool>[~tool-params]] Repeatable. "
            . "Inserts data from the named column into the patron field listed; i.e. BARCODE:cardnumber.",
    ],
    [ 'static|s=s@', '<header>:<value> Repeatable. Inserts static data into the named field.' ],
    [
        'map|m=s@',
        '<header>:<filename>[~<tool>[~tool-params]] Repeatable. Adds the single column of <filename> to the mashed data as <header>'
    ],
    [],
    [ 'verbose|v', "print extra stuff" ],
    [ 'help|h+',   "print usage message and exit", { shortcircuit => 1 } ],
    { show_defaults => 1 },
);

my $schema  = $opt->table ? Koha::Database->new()->schema() : undef;
my @sources = $schema ? $schema->sources : undef;

print( $usage->text ) if $opt->help;
if ( $opt->help && $opt->help > 1 ) {
    say "\nAVAILABLE TOOLS\n";
    my @found = useall ToolBox::Mungers;
    say qx/PERL5LIB=$FindBin::Bin perldoc -T $_/ for @found;
}
exit if $opt->help;

my $table = $opt->table;

# Load the data from the input file
my $data         = Text::CSV::Slurp->load( file => $opt->in );
my @data_columns = keys %{ $data->[0] };

# Verify the given table name has a result set
my $class_name;
if ($table) {
    ($class_name) = grep { $schema->class($_)->table eq $table } $schema->sources;
    unless ($class_name) {
        say "Unable to locate result set for " . $opt->table;
        exit 1;
    }
}

# Now that we have a valid table, get the columns for checking other parameters
my @columns = $table ? Koha::Database->new()->schema->source($class_name)->columns : undef;

# Validate format of the --col paramters
my @column_mappings;
if ( $opt->col ) {
    foreach my $c ( @{ $opt->col } ) {
        if ( $c =~ $option_params_regex ) {

            # regex capture groups are named $1, $2, $3, $4, etc. Let's make them real boys
            my ( $header, $column, $tool, $tool_params ) = ( $1, $2, $3 );
            push( @column_mappings, { header => $header, column => $column, tool => $tool, tool_params => $tool_params } );

            # verify the header column exists in the input file
            unless ( grep { /^$header$/ } @data_columns ) {
                say "The header '$header' doesn't match any headers in " . $opt->in;
                exit 1;
            }

            # verify the column exists in the table
            if ($table) {
                unless ( grep { /^$column$/ } @columns ) {
                    say "The column '$column' doesn't match any columns in '$table'";
                    exit 1;
                }
            }

            if ($tool) {
                try {
                    load "$mungers$tool";
                } catch {
                    say "Unable to find munger named $tool";
                    exit 1;
                };
            }
        } else {
            say "Parameter --col $c does not match the pattern <colhead>:<column>[~<tool>]";
            exit 1;
        }
    }
}

# Validate the additional file mappings
my @additional_file_mappings;
if ( $opt->map ) {
    foreach my $m ( @{ $opt->map } ) {
        if ( $m =~ $option_params_regex ) {

            # regex capture groups are named $1, $2, $3, $4, etc. Let's make them real boys
            my ( $header, $file, $tool ) = ( $1, $2, $3 );

            my @lines = read_file($file);

            # There needs to be a one-to-one mapping of rows in the source file and additional files
            if ( scalar @lines != scalar @$data ) {
                say "The number of lines in $file doesn't match the number of lines in " . $opt->in;
                say "$file has " . scalar @lines . " but file " . $opt->in . " has " . scalar @$data . " lines";
                exit 1;
            }

            push( @additional_file_mappings, { header => $header, lines => \@lines, tool => $tool } );

            if ($tool) {
                try {
                    load "$mungers$tool";
                } catch {
                    say "Unable to find munger named $tool";
                    exit 1;
                };
            }
        } else {
            say "Parameter --map $m does not match the pattern <header>:<filename>[~<tool>[~<tool params>]]";
            exit 1;
        }
    }
}

# Validate the static mappings
my @static_mappings;
if ( $opt->static ) {
    foreach my $s ( @{ $opt->static } ) {
        my ( $header, $value ) = split( ':', $s );    #FIXME: RegEx?

        push( @static_mappings, { header => $header, value => $value } );

        unless ( $header && $value ) {
            say "Static mapping $s is not in the format <header>:<value>";
            exit 1;
        }
    }
}

my @output_data;
foreach my $d (@$data) {
    my $row = {};
    foreach my $cm (@column_mappings) {
        my $datum = $d->{ $cm->{header} };

        # TODO Tool stuff
        $datum = "$mungers$cm->{tool}"->munge($datum, $cm->{tool_params} ) if $cm->{tool};

        $row->{ $cm->{column} } = $datum;
    }

    foreach my $afm (@additional_file_mappings) {
        my $datum = shift @{ $afm->{lines} };
        chomp $datum;

        # TODO Tool stuff
        $datum = "$mungers$afm->{tool}"->munge($datum, $cm->{tool_params}) if $afm->{tool};

        $row->{ $afm->{header} } = $datum;
    }

    foreach my $sm (@static_mappings) {
        $row->{ $sm->{header} } = $sm->{value};
    }

    push( @output_data, $row );
}

if ( $opt->out ) {
    write_file( $opt->out, Text::CSV::Slurp->create( input => \@output_data ) );
} else {
    print Text::CSV::Slurp->create( input => \@output_data );
}
