#!/usr/bin/perl
#---------------------------------
# Copyright 2012 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#
#---------------------------------
#
# EXPECTS:
#   -file of CSV-delimited data
#   -which columns you want  ie. what number column: 1,2,3,4,5,etc
#
# DOES:
#   -nothing
#
# CREATES:
#   -csv with grabbed columns
#
# REPORTS:
#   -count of lines read and output
#

use autodie;
use strict;
use warnings;
use Carp;
use Data::Dumper;
use English qw( -no_match_vars );
use Getopt::Long;
use Readonly;
use Text::CSV_XS;

local    $OUTPUT_AUTOFLUSH =  1;
Readonly my $NULL_STRING   => q{};

my $debug   = 0;
my $doo_eet = 0;
my $i       = 0;
my $j       = 0;
my $k       = 0;
my $written = 0;
my $problem = 0;

my $input_filename  = $NULL_STRING;
my $output_filename = $NULL_STRING;
my $csv_delim       = 'comma';
my $quotechar       = '"';
my $skip_header     = 0;
my @columns;
my $colmapfile;
my $mapcolumn;
my %colmap;

GetOptions(
    'in=s'         => \$input_filename,
    'out=s'        => \$output_filename,
    'delimiter=s'  => \$csv_delim,
    'quotechar=s'  => \$quotechar,
    'skip_header'  => \$skip_header,
    'column=s'     => \@columns,
    'mapcolumn=s'  => \$mapcolumn,
    'debug'        => \$debug,
    'map=s'        => \$colmapfile,
);

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                  'plus'  => '+',
                  );

for my $var ($input_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delim}, quote_char => $quotechar, escape_char => $quotechar });
my $csv_out=Text::CSV_XS->new({binary => 1, sep_char => $delimiter{$csv_delim} });


#comment out encoding lines when you have diacritics?
open my $input_file, '<',$input_filename;
open my $output_file,'>',$output_filename;
#open my $input_file, '<:encoding(UTF-8)',$input_filename;
#open my $output_file, '>:encoding(UTF-8)',$output_filename;

if ($skip_header) {
   my $dummy = $csv->getline($input_file);
}

print "Reading in map file.\n";
if ($colmapfile ne $NULL_STRING) {
   my $csv = Text::CSV_XS->new( { binary => 1} );
   open my $mapfile,'<',$colmapfile;
   while (my $line = $csv->getline($mapfile)) {
      my @data = @$line;
      $colmap{$data[0]} = $data[1];
#print "$data[0] and $colmap{$data[0]}\n";
   }
   close $mapfile;
}

RECORD:
while (my $line = $csv->getline($input_file)) {
   last RECORD if ($debug && $i>9);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my @data=@$line;
#print "data0 is $data[0] and mapped column is $data[$mapcolumn]\n";
   if ( exists($colmap{$data[$mapcolumn]}) ) {
         $debug and print "MAPPED: $data[$mapcolumn]  TO $colmap{$data[$mapcolumn]}\n";
         $data[$mapcolumn] = $colmap{$data[$mapcolumn]};
      }
   else {
    print "$data[$mapcolumn] could not be mapped\n";
     $data[$mapcolumn] = "NOMATCHFOUND for $data[$mapcolumn]";
#    next RECORD;
   }

   my @new_columns;

   foreach my $column (@columns) {
      push @new_columns,$data[$column];
   }
   $csv_out->combine(@new_columns);



   my $output_string = $csv_out->string();
#Dani change to remove pipe and get comma

#print {$output_file} "$output_string|$data[$mapcolumn]\n";
print {$output_file} "$output_string\n";
   $written++;
}
close $input_file;
print << "END_REPORT";

$i records read.
$written records written.
END_REPORT

exit;
