#!/usr/bin/perl
#---------------------------------
# Copyright 2011 ByWater Solutions
#
#---------------------------------
#
# -D Ruth Bavousett
#  edited: 
#     8.23.2012 Joy Nelson -added Notes for patron attribute format in runtime options
#
#  TODO:  add mapping for patron attributes
#
#---------------------------------
#
# EXPECTS:
#   -file of CSV-delimited patron records
#
# DOES:
#   -nothing
#
# CREATES:
#   -Koha patron CSV file 
#
# REPORTS:
#   -count of records manipulated
#
# Notes:
#   This script uses command-line directives to do stuff to the MARC records.  Possible directives:
#
#   --in=<filename>               Incoming csv file
#
#   --out=<filename>              Resulting csv file
#
#   --codes=<filename>            Name of file to contain sql statements for patron categories
#   
#   --col=<colhead>:<column><~tool>
#                    Inserts data from the named column into the patron field listed; i.e. BARCODE:cardnumber.  
#                     Repeatable.  Suffixable by a tool for data cleanup:
#           uc       upper-cases the data, and strips leading and trailing spaces
#           lc       lower cases the data
#           date     Tidies up dates, renders in ISO form
#           date3    Use for dateexpiry values.  mm/dd/yy hh:dd A/PM
#           money    Strips dollar sign, leaves only the numeric part
#           strip    Strips comma (used for patron attributes mainly
#                              
#   --static=<column>:<data>       Inserts static data into the named field.  Repeatable.
#   --name=<column>                Designates the column where the borrower name is--if the column contains a comma, then it splits 
#                                  there for surname, firstname
#   --map=<colhead>:<filename>     Uses the two-column map in the file to edit the given item subtag
#   --barprefix=     use a term as a barcode prefix
#   --barlength=<n>  make sure the minimum barcode length is <n>, left-padding with zeroes as needed.
#
#   To specify the patron_attributes use this format:  
#            --col=<colhead>:EXT:<attribute_name>
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

my $input_filename          = $NULL_STRING;
my $output_filename         = $NULL_STRING;
my $codesfile_name          = '/dev/null';
my $barlength               = 0;
my $barprefix               = $NULL_STRING;
my $namecol = $NULL_STRING;
my $citycol = $NULL_STRING;
my $csv_delim            = 'comma';
my @col;
my @static;
my @datamap_filenames;
my %datamap;


GetOptions(
    'in=s'         => \$input_filename,
    'out=s'        => \$output_filename,
    'codes=s'      => \$codesfile_name,
    'name=s'       => \$namecol,
    'csz=s'        => \$citycol,
    'map=s'        => \@datamap_filenames,
    'col=s'        => \@col,
    'delimiter=s'  => \$csv_delim,
    'barprefix=s'  => \$barprefix,
    'barlength=i'  => \$barlength,
    'static=s'     => \@static,
    'debug'        => \$debug,
);

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );

for my $var ($input_filename,$output_filename) {
   croak ("You're missing something") if $var eq $NULL_STRING;
}

my @field_mapping;
foreach my $map (@col) {
   my ($col, $field) = $map =~ /^(.*?):(.*)$/;
   if (!$col || !$field){
      croak ("--col=$map is ill-formed!\n");
   }
   push @field_mapping, {
      'column'    => $col,
      'field'     => $field,
   };
}

$debug and print Dumper(@field_mapping);

my @field_static;
foreach my $map (@static) {
   my ($field, $data) = $map =~ /^(.*?):(.*)$/;
   if (!$field || !$data ) {
      croak ("--static=$map is ill-formed!\n");
   }
   push @field_static, {
      'field'  => $field,
      'data'      => $data,
   };
}

foreach my $map (@datamap_filenames) {
   my ($mapsub,$map_filename) = split (/:/,$map);
   my $csv = Text::CSV_XS->new( {binary=>1});
   open my $mapfile,'<',$map_filename;
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $datamap{$mapsub}{$data[0]} = $data[1];
   }
   close $mapfile;
}
#$debug and print Dumper(%datamap);
my %branchcounts;
my %categorycounts;

my @borrower_fields = qw /cardnumber          surname
                          firstname           middle_name
			  pronouns	      title
                          othernames          initials
                          streetnumber        streettype
                          address             address2
                          city                state
                          zipcode
                          country             email
                          phone               mobile
                          fax                 emailpro
                          phonepro            B_streetnumber
                          B_streettype        B_address
                          B_address2          B_city
                          B_state 
                          B_zipcode           B_country
                          B_email             B_phone
                          dateofbirth         branchcode
                          categorycode        dateenrolled
                          dateexpiry          gonenoaddress
                          lost                debarred
                          contactname         contactfirstname
                          contacttitle        guarantorid
                          borrowernotes       relationship
                          ethnicity           ethnotes
                          sex                 password
                          flags               userid
                          opacnote            contactnote
                          sort1               sort2
                          altcontactfirstname altcontactsurname
                          altcontactaddress1  altcontactaddress2
                          altcontactaddress3  altcontactzipcode
                          altcontactcountry   altcontactphone
                          smsalertnumber      privacy
                          lastseen            debarredcomment
                          updated_on/;



my $csv=Text::CSV_XS->new({ binary => 1 , sep_char => $delimiter{$csv_delim} });
open my $input_file,'<',$input_filename;
$csv->column_names($csv->getline($input_file)); 
$debug and print Dumper($csv->column_names());
open my $output_file,'>:utf8',$output_filename;
for my $k (0..scalar(@borrower_fields)-1){
   print {$output_file} $borrower_fields[$k].',';
}
print {$output_file} "patron_attributes\n";

RECORD:
while (my $patronline = $csv->getline_hr($input_file)) {
   last RECORD if ($debug && $i>10);
   $i++;
   print '.'    unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my %record;
   my $addedcode = $NULL_STRING;

   foreach my $map (@field_static) {
      $record{$map->{'field'}} = $map->{'data'};
   }

   if ($namecol ne $NULL_STRING) {
      my $data=$patronline->{$namecol} || $NULL_STRING;
      $debug and print "name data: $data\n";
      if ($data =~ m/\,/) {
         ($record{surname},$record{firstname}) = split /\,/,$data,2;
         $record{firstname} =~ s/^\s+//g;
      }
      else {
         $record{surname} = $data;
      }
      $debug and print "$record{surname} -- $record{firstname} XX\n";
   }

   if ($citycol ne $NULL_STRING) {
      my $data=$patronline->{$citycol} || $NULL_STRING;
      $debug and print "city data before: $data\n";
      if ($data =~ /\d/) {
         ($record{city},$record{state}) = $data =~ m/(.*)? ([\d\-]+)/;
         $debug and print "city data: $record{city}~$record{state}\n";
      }
      else {
         $record{city} = $data;
      }
   }

   foreach my $map (@field_mapping) {
      $debug and print Dumper($map);
      if ((defined $patronline->{$map->{'column'}}) && ($patronline->{$map->{'column'}} ne $NULL_STRING)) {
         my $sub = $map->{'field'};
         #$debug and warn $sub;
         my $tool;
         my $appendflag;
         ($sub,$tool) = split (/~/,$sub,2);
         if ($sub =~ /\+$/) {
            $sub =~ s/\+//g;
            $appendflag=1;
         }

         my $data = $patronline->{$map->{'column'}};
         $data =~ s/^\s+//g;
         $data =~ s/\s+$//g;
         $debug and print "$sub: $data\n";

         if ($tool) {
            if ($tool eq 'uc') {
               $data = uc $data;
            }
            if ($tool eq 'lc') {
               $data = lc $data;
            }
            if ($tool =~ /^yesno:/) {
               my (undef,$value) = split /:/,$tool,2;
               if (!$data) {
                  $data = $NULL_STRING;
               }
               else {
                  $data = $value;
               }
            }
            if ($tool =~ /^prefix:/) {
               my (undef,$value) = split /:/,$tool,2;
               $data = $value . $data;
            }
            if ($tool eq 'strip') {
               $data =~ s/,//g;
            }
            if ($tool eq 'money') {
               $data =~ s/[^0-9\.]//g;
            }
            if ($tool eq 'firstword') {
               ($data,undef) = split / /,$data; 
            }
            if ($tool eq 'delimiter') {
                $data = $data . ' ; ';                
            }
            if ($tool eq 'phone') {
                $data =~ s/ //g;
                if (length($data) == 10) {
                 my $area = substr($data,0,3);
                 my $exchange = substr($data,3,3);
                 my $number = substr($data,6,4);
                 $data = "(".$area.")".$exchange."-".$number;
                }
             }

#keep the last 4 of a field

if ($tool eq 'passcol') {
    $data = substr($data,-4);
}

#date is mm/dd/yy   this works best for date of birth, not future expiration dates.
            if ($tool eq 'date') {
               $data =~ s/ //g;
               my ($month,$day,$year) = $data =~ /(\d+).(\d+).(\d+)/;
               if ($month && $day && $year){
                  my @time = localtime();
                  my $thisyear = $time[5]+1900;
                  $thisyear = substr($thisyear,2,2);
                  if ($year < $thisyear) {
                     $year += 2000;
                  } 
                  elsif ($year < 100) {
                     $year += 1900;
                  }
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
            }
#date1 is mm/dd/yyyy 0:00
             if ($tool eq 'date1') {
                $data =~ s/ //g;
               if ($data ne "0") {
                   my $year = substr($data,6,4);
                   my $month = substr($data,0,2);
                   my $day = substr($data,3,2);
                   if ($month && $day && $year) {
                     $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                     if ($data eq "0000-00-00") {
                      $data = $NULL_STRING;
                   }
               }
                   else {
                   $data= $NULL_STRING;
                   }
               }
             }
#date1a is mm/dd/yyyy 0:00... or m/d/yyyy 0:00
if ($tool eq 'date1a') {
#           my ($date) = @_;
       $data =~ s/PM\s*//;
       $data =~ s/AM\s*//;

       $data =~ s/\d+:\d\d//;
       $data =~ s/ //g;
       my ($month,$day,$year) = $data =~ /(\d+).(\d+).(\d+)/;
       if ($month && $day && $year){
         if (length($year) == 2) {
          $year = '20'.$year;
         }
          $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
          if ($data eq "0000-00-00") {
             $data = '';
          }
       }
       else {
          $data= '';
       }

#date1b is for dates like 4/6/1956 12:00:00 AM ... in progress       
#if ($tool eq 'date1b') {
#$data =~ s/
#    my $year  = substr($datein,0,4);
#    my $month = substr($datein,4,2);
#    my $day   = substr($datein,6,2);
#    my $hr    = substr($datein,8,2);
#    my $min   = substr($datein,10,2);
#    my $sec   = substr($datein,12,2);
#    return sprintf "%d-%02d-%02d %d:%d:%d",$year,$month,$day,$hr,$min,$sec;
# }


#return $data;
 }


#date2 is YYYYMMDD
            if ($tool eq 'date2') {
               $data =~ s/ //g;
              if ($data ne "0") {
               my $year  = substr($data,0,4);
               my $month = substr($data,4,2);
               my $day   = substr($data,6,2);
               if ($month && $day && $year){
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
              }
            }
#date2a is YYYYMMDD
            if ($tool eq 'date2a') {
               $data =~ s/ //g;
              if ($data ne "0") {
               my $year  = substr($data,0,4);
               my $month = substr($data,4,2);
               my $day   = substr($data,6,2);
               if ($month && $day && $year){
                  $data = $year."-".$month."-".$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
              }
            }

#date3 is for Dateexpiry  mm/dd/yy hh:mm (4 digit?)
#use on other dates with caution
            if ($tool eq 'date3') {
               ($data,undef) = split(/ /,$data);
               my ($month,$day,$year) = $data =~ /(\d+).(\d+).(\d+)/;
               if ($month && $day && $year){
                  my @time = localtime();
                  my $thisyear = $time[5]+1900;
                  $thisyear = substr($thisyear,2,2);
                  if ($year <= $thisyear) {
                     $year += 2000;
                  } 
                  elsif ($year > 90 ) {
                     $year += 1900;
                  }
                 elsif ($year <90) {
                     $year += 2000;
                 }
$debug and print "year is $year\n";
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
$debug and print "dateexpiry is $data\n";
            }
#date4 is yyyy-mm-dd hh:mm:ss:.....
            if ($tool eq 'date4') {
               ($data,undef) = split(/ /,$data);
               my ($year,$month,$day) = $data =~ /(\d+).(\d+).(\d+)/;
               if ($month && $day && $year){
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
            }

#retaintimestamp is for dates like this 2019-01-30 10:19:32.193085-06
      if ($tool eq 'retaintimestamp') {
         ($data,undef) = split(/\./,$data);
#          my ($year,$month,$day) = $data =~ /(\d+).(\d+).(\d+)/;
#          if ($month && $day && $year){
#              $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
#              if ($data eq "0000-00-00") {
#                  $data = $NULL_STRING;
#              }
#          }
#          else {
#              $data= $NULL_STRING;
#          }
      }



#date10 is mm/dd/yyyy?
            if ($tool eq 'date10') {
               $data =~ s/ //g;
               my ($month,$day,$year) = $data =~ /(\d+).(\d+).(\d+)/;
               if ($month && $day && $year){
                  my @time = localtime();
                 my $thisyear = $time[5]+1900;
                  $thisyear = substr($thisyear,2,2);
                  if ($year < $thisyear+10) {
                     $year += 2000;
                  } 
                  elsif ($year < 100) {
                     $year += 1900;
                  }
                 $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
            }
#datestr mon day year timestamp
            if ($tool eq 'datestr2') {
              my %monthdigit = (
                'Jan' => '1',  'Feb' => '2', 'Mar' => '3',
                'Apr' => '4',  'May' => '5', 'Jun' => '6',
                'Jul' => '7',  'Aug' => '8', 'Sep' => '9',
                'Oct' => '10',  'Nov' => '11', 'Dec' => '12'
                 );
              $data =~ s/\s\d{1,2}:\d\d:\d\d\s[A|P]M$//;
              $debug and print "$data\n";
              $data =~ s/ //g;
              if ($data ne "0") {
               my $month  = substr($data,0,3);
               my $day = substr($data,3,2);
               $day =~ s/,//g;
               my $year   = substr($data,-4);
               if (exists($monthdigit{$month})) {
                  $month=$monthdigit{$month};
               }
               if ($month && $day && $year){
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
              }
            }
#regular datestring without timestamp month day, year
            if ($tool eq 'datestr') {
              my %monthdigit = (
                'Jan' => '1',  'Feb' => '2', 'Mar' => '3',
                'Apr' => '4',  'May' => '5', 'Jun' => '6',
                'Jul' => '7',  'Aug' => '8', 'Sep' => '9',
                'Oct' => '10',  'Nov' => '11', 'Dec' => '12'
                 );
              $data =~ s/ //g;
              if ($data ne "0") {
               my $month  = substr($data,0,3);
               my $day = substr($data,3,2);
               $day =~ s/,//g;
               my $year   = substr($data,-4);
               if (exists($monthdigit{$month})) {
                  $month=$monthdigit{$month};
               }
               if ($month && $day && $year){
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") {
                     $data = $NULL_STRING;
                  }
               }
               else {
                  $data= $NULL_STRING;
               }
              }
            }
#datestring dd month yyyy
           if ($tool eq 'datestr3') {
              my %monthdigit = (
                'Jan' => '1',  'Feb' => '2', 'Mar' => '3',
                'Apr' => '4',  'May' => '5', 'Jun' => '6',
                'Jul' => '7',  'Aug' => '8', 'Sep' => '9',
                'Oct' => '10',  'Nov' => '11', 'Dec' => '12'
                 );
              my ($month, $day, $year) = $data =~ /(\d+)[ |:](\w+)[ |:](\d\d\d\d)/;
              if ($data ne "0")  
			   {
                  if (exists($monthdigit{$month})) 
				   {
                   $month=$monthdigit{$month};
                   }
               if ($month && $day && $year)
			    {
                  $data = sprintf "%4d-%02d-%02d",$year,$month,$day;
                  if ($data eq "0000-00-00") 
				   {
                     $data = $NULL_STRING;
                   }
                }
               else 
			    {
                  $data= $NULL_STRING;
                }
              }
           }

            if ($tool eq 'areacode') {
               if ($data ne $NULL_STRING) {
                  $data = '(' . $data . ')';
               }
            }
         }
         if ($data ne $NULL_STRING){
            if ($sub =~ /EXT/) {
               $sub =~ s/EXT://g;
               $addedcode .= ',' . $sub . ':'. $data;
            }
            elsif ($appendflag) {
               $record{$sub} .= ' ' .$data;
            }
            else {
               $record{$sub} = $data;
            }
         }
      }
   }

if (!defined $record{cardnumber}) {
      $record{cardnumber} = sprintf "TEMP%010d",$i;
   } 
   
   $record{cardnumber} =~ s/ //g;

   if ($barprefix ne $NULL_STRING || $barlength > 0) {
      my $curbar = $record{cardnumber};
      my $prefixlen = length($barprefix);
      if (($barlength > 0) && (length($curbar) <= ($barlength-$prefixlen))) {
         my $fixlen = $barlength - $prefixlen;
         while (length ($curbar) < $fixlen) {
            $curbar = '0'.$curbar;
         }
       $curbar = $barprefix . $curbar;
      }
      $record{cardnumber} = $curbar;
   }

   for my $tag (keys %record) {
      my $oldval = $record{$tag};
      if ($datamap{$tag}{$oldval}) {
         $record{$tag} = $datamap{$tag}{$oldval};
         if ($datamap{$tag}{$oldval} eq 'NULL') {
            delete $record{$tag};
         }
      }
   }

   next RECORD if (!exists $record{categorycode});
   next RECORD if (!exists $record{branchcode});

   $branchcounts{$record{branchcode}}++;
   $categorycounts{$record{categorycode}}++;

   for $k (0..scalar(@borrower_fields)-1){
      if ($record{$borrower_fields[$k]}){
         $record{$borrower_fields[$k]} =~ s/\"/'/g;
         if ($record{$borrower_fields[$k]} =~ /,/){
            print {$output_file} '"'.$record{$borrower_fields[$k]}.'"';
         }
         else{
            print {$output_file} $record{$borrower_fields[$k]};
         }
      }
      print {$output_file} ",";
   }
   if ($addedcode){
      $addedcode =~ s/^,//;
      print {$output_file} '"'."$addedcode".'"';
   }
   print {$output_file} "\n";
   $written++;
}

close $input_file;
close $output_file;

print << "END_REPORT";

$i records read.
$written records written.
$problem records not written due to problems.
END_REPORT

open my $codes_file,'>',$codesfile_name;

print "\nHOMEBRANCHES:\n";
foreach my $kee (sort keys %branchcounts){
   print $kee.":   ".$branchcounts{$kee}."\n";
   print {$codes_file} "INSERT IGNORE INTO branches (branchcode,branchname) VALUES ('$kee','$kee');\n";
}
print "\nCATEGORIES:\n";
foreach my $kee (sort keys %categorycounts){
   print $kee.":   ".$categorycounts{$kee}."\n";
   print {$codes_file} "INSERT IGNORE INTO categories (categorycode,description,overduenoticerequired) VALUES ('$kee','$kee',1);\n";
}

close $codes_file;
exit;
