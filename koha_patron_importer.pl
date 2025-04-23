#!/usr/bin/perl

use feature 'say';

use Modern::Perl;

use Carp::Always;
use Data::Dumper;
use Getopt::Long;
use List::Util qw(any none);
use Parallel::ForkManager;
use Text::CSV::Slurp;
use Try::Tiny;

use C4::Context;
use Koha::Database;
use Koha::DateUtils qw( dt_from_string output_pref );
use Koha::Libraries;
use Koha::Patron::Attribute::Types;
use Koha::Patron::Categories;
use Koha::Patrons;

my $start_time = time();

my $batch_commit_size = 500;
my $input_file;
my $error_file       = "errors.log";
my $bad_patrons_file = "bad_patrons.csv";
my $confirm;
my $verbose = 0;
my $help;

my $usage_string = "Usage: $0 -i <input_file> -e <error_log> -b <bad_patrons_file> --confirm";

GetOptions(
    "i|in|input=s"    => \$input_file,
    "e|error=s"       => \$error_file,
    "b|bad-patrons=s" => \$bad_patrons_file,
    "c|confirm"       => \$confirm,
    "v|verbose+"      => \$verbose,
    "h|help"          => \$help,
    "batch-commit=i"  => \$batch_commit_size,
);

say $usage_string and exit if $help || !$input_file || !$error_file || !$bad_patrons_file;

my $EnhancedMessagingPreferences = C4::Context->preference('EnhancedMessagingPreferences');

my @patron_categories = Koha::Patron::Categories->search()->get_column('categorycode');
say "Patron categories: " . Data::Dumper::Dumper( \@patron_categories ) if $verbose;
my @branchcodes = Koha::Libraries->search()->get_column('branchcode');
say "Branchcodes: " . Data::Dumper::Dumper( \@branchcodes ) if $verbose;

my $schema        = Koha::Database->new()->schema;
my @borrower_keys = $schema->source('Borrower')->columns;

my $patrons = Text::CSV::Slurp->load( file => $input_file );

my @patron_keys = keys %{ $patrons->[0] };

# Remove any keys from @patron_keys that are not in @borrower_keys
@patron_keys = grep { $_ ~~ @borrower_keys } @patron_keys;

my $dbh = C4::Context->dbh();
my $sth_borrower_attributes =
    $dbh->prepare("INSERT INTO borrower_attributes (borrowernumber,code,attribute) VALUES (?,?,?)");
my $sth_borrowers =
    $dbh->prepare( "INSERT INTO borrowers ( "
        . join( ",", @patron_keys )
        . " ) VALUES ( "
        . join( ",", map { '?' } @patron_keys )
        . ")" );

my @invalid_patrons;
my @log_lines;

my $patrons_processed = 0;

open my $error_fh, '>', $error_file or die "Cannot open file '$error_file': $!";

# Disable autocommit
$dbh->{AutoCommit} = 0;

foreach my $patron (@$patrons) {
    my $success = 1;
    my @messages;
    my @errors;

    push( @messages, "Patron: $patron->{surname} $patron->{firstname} $patron->{cardnumber}" );

    if ( !$patron->{categorycode} ) {
        $success = 0;
        push( @errors, "Missing category code" );
    }

    if ( $patron->{categorycode} && none { $_ eq $patron->{categorycode} } @patron_categories ) {
        $success = 0;
        push( @errors, "Unknown category code: $patron->{categorycode}" );
    }

    if ( !$patron->{branchcode} ) {
        $success = 0;
        push( @errors, "Missing branch code" );
    }

    if ( $patron->{branchcode} && none { $_ eq $patron->{branchcode} } @branchcodes ) {
        $success = 0;
        push( @errors, "Unknown branch code: $patron->{branchcode}" );
    }

    if ( !$patron->{surname} ) {
        $success = 0;
        push( @errors, "Missing surname" );
    }

    my $borrowernumber;
    if ($success) {
        my $patron_attributes = $patron->{patron_attributes};
        delete $patron->{patron_attributes};

        # Clean up patron before insert
        $patron->{dateofbirth}   ||= undef;
        $patron->{flags}         ||= 0;
        $patron->{gonenoaddress} ||= 0;
        $patron->{lost}          ||= 0;
        $patron->{debarred}      ||= undef;
        $patron->{userid}        ||= undef;
        $patron->{dateexpiry}    ||= undef;

        try {
            $sth_borrowers->execute( map { $patron->{$_} } @patron_keys );
            ($borrowernumber) = $dbh->selectall_arrayref(
                "SELECT borrowernumber FROM borrowers WHERE cardnumber = ?", undef,
                $patron->{cardnumber}
            )->[0]->[0];

            # set messaging preferences by category if using enhanced messaging preferences
            C4::Members::Messaging::SetMessagingPreferencesFromDefaults(
                {
                    borrowernumber => $borrowernumber,
                    categorycode   => $patron->{categorycode},
                }
            ) if $EnhancedMessagingPreferences;

            # store patron attributes if they exist
            if ($patron_attributes) {
                my @att_arr = split( /,/, $patron_attributes );
                foreach my $attrib (@att_arr) {
                    my ( $code, $attribute ) = split( /:/, $attrib );
                    $sth_borrower_attributes->execute( $borrowernumber, $code, $attribute );
                }
            }
        } catch {
            $success = 0;
            push( @errors, "Failed to store patron: $_" );
        };

    }

    $patron->{ERRORS} = join( ", ", @errors );
    push( @messages, @errors );

    if ( !$success ) {
        push @invalid_patrons, $patron;
    }

    $patrons_processed++;

    # Commit every 500 iterations
    if ( $patrons_processed % $batch_commit_size == 0 ) {
        $dbh->commit;
        say "Committed after $patrons_processed iterations" if $verbose;
    }

    say "Processed $patron->{cardnumber} ($borrowernumber) : $patrons_processed of " . scalar(@$patrons)
        if $verbose;

    my $m = join( "\n", @messages ) . "\n";
    print $error_fh $m unless $success;
    say $m if $verbose;
}

# Final commit after the loop
$dbh->commit;
say "Final commit completed" if $verbose;

close $error_fh;

if (@invalid_patrons) {
    say "There were " . scalar(@invalid_patrons) . " invalid patron records. See $bad_patrons_file for details.";

    my $csv = Text::CSV::Slurp->create( input => \@invalid_patrons );
    open( FH, ">$bad_patrons_file" ) || die "Couldn't open $bad_patrons_file $!";
    print FH $csv;
    close FH;
}

my $end_time = time();
my $time     = $end_time - $start_time;
my $minutes  = int( $time / 60 );
my $seconds  = $time - ( $minutes * 60 );
my $hours    = int( $minutes / 60 );
$minutes -= ( $hours * 60 );
printf "Finished in %dh:%dm:%ds.\n", $hours, $minutes, $seconds;
