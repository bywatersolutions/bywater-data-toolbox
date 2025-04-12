#!/usr/bin/perl
#---------------------------------
# Copyright 2025 ByWater Solutions
#
#---------------------------------
# What does it do?  Loads into a table.
#
# What does it expect?  A .txt or .csv file.
#
# Syntax:
# perl table_loader_24.11.pl --in <filename> --table <tablename> --borr <borrower field> --item <item field> --biblio <biblio field>
#---------------------------------

use autodie;
use Data::Dumper;
use Getopt::Long;
use Modern::Perl;
use Text::CSV;
use C4::Context;
$|=1;

my $infile_name = "";
my $table_name = "";
my $borrowercol = "";
my $itemcol = "";
my $bibliocol = "";
my $alternate = undef;
my $csv_delim = 'comma';
my $debug=0;
my $doo_eet=0;
my $barlength = 0;
my $barprefix = '';
my $itembarlength = 0;
my $itembarprefix = '';
my @datamap_filenames;
my %datamap;
my $ignoreflag;

GetOptions(
    'in=s'     => \$infile_name,
    'table=s'  => \$table_name,
    'borr=s'   => \$borrowercol,
    'alt=s'    => \$alternate,
    'item=s'   => \$itemcol,
    'bib=s'    => \$bibliocol,
    'barprefix=s'  => \$barprefix,
    'barlength=i'  => \$barlength,
    'itemprefix=s' => \$itembarprefix,
    'itembarlen=s' => \$itembarlength,
    'map=s'        => \@datamap_filenames,
    'delimiter=s'  => \$csv_delim,
    'ignore'   => \$ignoreflag,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

my %DELIMITER = ( 'comma' => q{,},
                  'tab'   => "\t",
                  'pipe'  => q{|},
                );

if (($infile_name eq '') || ($table_name eq '')){
   print "Something's missing.\n";
   exit;
}

foreach my $map (@datamap_filenames) {
   my ($mapsub,$map_filename) = split (/:/,$map);
   my $csv = Text::CSV_XS->new();
   open my $mapfile,'<',$map_filename;
$debug and print "$map_filename\n";
   while (my $row = $csv->getline($mapfile)) {
      my @data = @$row;
      $datamap{$mapsub}{$data[0]} = $data[1];
#$debug and print "$data[0] and $data[1]\n";
  }
   close $mapfile;
}

my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $DELIMITER{$csv_delim} });
my $dbh=C4::Context->dbh();
my $j=0;
my $exceptcount=0;
open my $io,"<$infile_name";
my $headerline = $csv->getline($io);
my @fields=@$headerline;
$debug and print Dumper(@fields);
while (my $line=$csv->getline($io)){
   $debug and last if ($j>10000); 
   $j++;
   print ".";
   print "\r$j" unless ($j % 100);
   my @data = @$line;
   $debug and print Dumper(@data);
   my $querystr = "INSERT INTO $table_name (";
   ## adds IGNORE if --ignore param is set
      if ($ignoreflag) {
	 $querystr = "INSERT IGNORE INTO $table_name (";
      }
   my $exception = 0;
   for (my $i=0;$i<scalar(@data);$i++){
      next if ($fields[$i] eq "" || $data[$i] eq "");
      if ($fields[$i] eq "ignore"){
         next;
      }
      if ($fields[$i] eq $borrowercol){
         $querystr .= "borrowernumber,";
         next;
      }
      if ($fields[$i] eq $bibliocol){
         $querystr .= "biblionumber,";
         next;
      }
      if ($fields[$i] eq $itemcol){
         $querystr .= "itemnumber,";
         next;
      }
      if (($data[$i] ne "") && ($fields[$i] ne "suppress")){
         $querystr .= $fields[$i].",";
      }
   }
   $querystr =~ s/,$//;
   $querystr .= ") VALUES (";
   for (my $i=0;$i<scalar(@fields);$i++){
      if ($fields[$i] eq "ignore" || $data[$i] eq ""){
         next;
      }
      if ($fields[$i] eq "branchcode") {
         $data[$i] =  $data[$i];
      }
      my $oldval = $data[$i];
      if ($datamap{$fields[$i]}{$oldval}) {
         $debug and say "MAPPED: $oldval  TO $datamap{$fields[$i]}{$oldval}";
         $data[$i] = $datamap{$fields[$i]}{$oldval};
      }
      if ($fields[$i] eq $borrowercol){
         if ($barprefix ne '' || $barlength > 0) {
            my $curbar = $data[$i];
            my $prefixlen = length($barprefix);
            if (($barlength > 0) && (length($curbar) <= ($barlength-$prefixlen))) {
               my $fixlen = $barlength - $prefixlen;
               while (length ($curbar) < $fixlen) {
                  $curbar = '0'.$curbar;
               }
               $curbar = $barprefix . $curbar;
            }
            $data[$i] = $curbar;
         }

$debug and print "cardnumber is: $data[$i]\n";

         my $convertq = $dbh->prepare("SELECT borrowernumber FROM borrowers WHERE $borrowercol = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         my $borr=$rec->{'borrowernumber'} || $alternate;
$debug and print "borrowernumber is: $data[$i]\n";
         if ($borr){
            $data[$i]= $borr;
         }
         elsif ($data[$i] ne 'NULL' && $data[$i] ne ''){
$debug and print "$data[$i] is $data[$i]\n";
            $exception = "No Borrower";
         }
      } 
      if ($fields[$i] eq $bibliocol){
         my $convertq = $dbh->prepare("SELECT biblionumber FROM items WHERE $bibliocol = '$data[$i]';");
         $convertq->execute();
         my $rec=$convertq->fetchrow_hashref();
         if ($rec->{'biblionumber'}){
            $data[$i] = $rec->{'biblionumber'};
$debug and print "biblionumber is: $data[$i]\n";
         }
         else {
            $exception = "No Biblio";
         }
      } 

      if ($fields[$i] eq $itemcol){
         if ($itembarprefix ne '' || $itembarlength > 0) {
            my $itemcurbar = $data[$i];
            my $itemprefixlen = length($itembarprefix);
            if (($itembarlength > 0) && (length($itemcurbar) <= ($itembarlength-$itemprefixlen))) {
               my $itemfixlen = $itembarlength - $itemprefixlen;
               while (length ($itemcurbar) < $itemfixlen) {
                  $itemcurbar = '0'.$itemcurbar;
               }
               $itemcurbar = $itembarprefix . $itemcurbar;
            }
            $data[$i] = $itemcurbar;
$debug and print "item barcode is: $data[$i]\n";
         }

         if ($data[$i]){
            my $convertq = $dbh->prepare("SELECT itemnumber FROM items WHERE $itemcol = '$data[$i]';");
            $convertq->execute();
            my $rec=$convertq->fetchrow_hashref();
            if ($rec->{'itemnumber'}){
               $data[$i] = $rec->{'itemnumber'};
$debug and print "itemnumber is: $data[$i]\n";
            }
            elsif ($data[$i] ne 'NULL' && $data[$i] ne '') {
               $exception = "No Item";
            }
         }
         else{
            $querystr .= "NULL,";
         }
      } 
      if ($fields[$i] =~ /date/){
         if (length($data[$i]) == 8){
           $data[$i] =~ s/(\d{4})(\d{2})(\d{2})/$1-$2-$3/;
         }
      }
      if (($data[$i] ne "") && ($fields[$i] ne "suppress")){
         $data[$i] =~ s/\"/\\"/g;
         $querystr .= '"'.$data[$i].'",';
      }
   }
   $querystr =~ s/,$//;
   $querystr .= ");";
   $debug and print $querystr."\n";
   if (!$exception){
      my $sth = $dbh->prepare($querystr);
      if ($doo_eet){
        $sth->execute();
#print "\n\n$querystr\n\n";
      }
   }
   else {
      $exceptcount++;
      print "\nEXCEPTION:  $exception\n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print $fields[$i].":  ".$data[$i]."\n";
      }
      print "--------------------------------------------\n";
   }
}
print "\n\n$j records processed.  $exceptcount exceptions.\n";
