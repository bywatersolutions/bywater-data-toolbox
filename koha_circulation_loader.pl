#!/usr/bin/perl
#---------------------------------
# Copyright 2025 ByWater Solutions
#
# What it does
# Loads current circulation.
#
# What does it expect?
# A txt or csv file of checkouts.
# 
# What does it spit out?
# Circ exceptions of borrowers, items, AND borrowers + items.
#
# Syntax: 
# perl circ_loader_24.11.pl --in checkouts.csv --borr <cardnumber, sort2> --item <barcode, stocknumber> --debug/update
#---------------------------------

use autodie;
use Data::Dumper;
use Getopt::Long;
use Modern::Perl;
use Text::CSV_XS;
use C4::Context;
use C4::Biblio;
use Koha::Items;

$|=1;

my $infile_name = "";
my $borrowercol = "";
my $itemcol = "";
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
my $circitem;
my $circborrower;
my $ignore='';

GetOptions(
    'in=s'     => \$infile_name,
    'borr=s'   => \$borrowercol,
    'alt=s'    => \$alternate,
    'item=s'   => \$itemcol,
    'barprefix=s'  => \$barprefix,
    'barlength=i'  => \$barlength,
    'itemprefix=s' => \$itembarprefix,
    'itembarlen=s' => \$itembarlength,
    'map=s'        => \@datamap_filenames,
    'delimiter=s'  => \$csv_delim,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
    'ignore'   => \$ignore,
);

my %DELIMITER = ( 'comma' => q{,},
                  'tab'   => "\t",
                  'pipe'  => q{|},
                );

if (($infile_name eq '')  ){
   print "Something's missing.\n";
   exit;
}
my $output_filename1 = "circ_exceptions_borrowers.log";
my $output_filename2 = "circ_exceptions_items.log";
my $output_filename3 = "circ_exceptions_borrowerANDitem.log";

open my $output_file1,'>:utf8',$output_filename1;
open my $output_file2,'>:utf8',$output_filename2;
open my $output_file3,'>:utf8',$output_filename3;

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
   $debug and print "\n************\n";
   $debug and print Dumper(@data);
   my $querystr = "INSERT INTO issues (";
   ## INSERT IGNORE if --ignore flag is set
      if ($ignore) {
         $querystr = "INSERT IGNORE INTO issues (";
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
         $data[$i] = uc $data[$i];
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

         if ($borr){
            $circborrower = $borr;  #?  assign borrowernumber to circborrower to preserve cardnumber for error file
            $debug and print "borrowernumber for $data[$i] is $circborrower \n";
            #$data[$i]= $borr;
            $querystr .= $circborrower.",";
         }
         elsif ($data[$i] ne 'NULL' && $data[$i] ne ''){
            $debug and print "No Borrower found for $data[$i]\n";
            $exception = "No Borrower";
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
         }
         $debug and print "item barcode is: $data[$i]\n";

         if ($data[$i]){
            my $convertq = $dbh->prepare("SELECT itemnumber FROM items WHERE $itemcol = '$data[$i]';");
            $convertq->execute();
            my $rec=$convertq->fetchrow_hashref();
            if ($rec->{'itemnumber'}){
               #$data[$i] = $rec->{'itemnumber'};
               $circitem = $rec->{'itemnumber'};
               $debug and print "itemnumber for $data[$i] is $circitem \n";
               $querystr .= $circitem.",";
            }
            elsif ($data[$i] ne 'NULL' && $data[$i] ne '') {
              $exception .= "No Item";
              $debug and print "No Item found for $data[$i]\n";
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

      if (($data[$i] ne "") && ($fields[$i] ne "suppress") && ($fields[$i] ne $itemcol) && ($fields[$i] ne $borrowercol) ){
         $data[$i] =~ s/\"/\\"/g;
         $querystr .= '"'.$data[$i].'",';
      }

   }

   $querystr =~ s/,$//;
   $querystr .= ");";
   if (!$exception ) {
     $debug and print $querystr."\n";
   }

   if (!$exception){
      my $sth = $dbh->prepare($querystr);
      if ($doo_eet){
        $sth->execute();
        #print "\n\n$querystr\n\n";
      }
   }
   elsif ($exception eq 'No Borrower' ) {
      $exceptcount++;
      print "\nEXCEPTION -No Borrower\n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print {$output_file1} $data[$i].",";
      }
      print {$output_file1} "\n";
      $exception = '';
   }
   elsif ($exception eq 'No Item' || $exception eq '0No Item' ) {
      $exceptcount++;
      print "\nEXCEPTION - No Item\n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print {$output_file2} $data[$i].",";
      }
      print {$output_file2} "\n";
      $exception = '';
  }
  elsif ($exception eq 'No BorrowerNo Item') {
      $exceptcount++;
      print "\nEXCEPTION - No Borrower or Item\n";
      for (my $i=0;$i<scalar(@fields);$i++){
         print {$output_file3} $data[$i].",";
      }
      print {$output_file3} "\n";
      $exception = '';
  }


}

 #update timestamp
 print "\n\n************************\n\nUPDATING THE issues.date_due timestamp\n\n";
 my $sth_updateissues =$dbh->prepare("update issues SET date_due = CONCAT(SUBSTR(date_due,1,11),'23:59:00')");
 $sth_updateissues->execute();

 #modify items based on issues
 my $sth=$dbh->prepare("SELECT itemnumber,issuedate,date_due FROM issues join items using (itemnumber)
                       where onloan is null"); 
 $sth->execute(); 
 print "UPDATING items.onloan now if update set...\n";
 my $i=0;
 while (my $rec = $sth->fetchrow_hashref()){
   $i++;
   print ".";
   print "\r$i" unless ($i % 100);
   if ($doo_eet){
      my $item = Koha::Items->find( $rec->{itemnumber} );
      $item->set({datelastborrowed => $rec->{'issuedate'},
                     datelastseen => $rec->{'issuedate'},
                     onloan => $rec->{'date_due'}
                     },undef,$rec->{'itemnumber'});
      $item->store();
   }
 }

print "\n\n$j records processed.  $exceptcount exceptions.\n"; 
