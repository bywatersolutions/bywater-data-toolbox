#!/usr/bin/perl
#---------------------------------
# Copyright 2025 ByWater Solutions
#
#---------------------------------
#
# -Mark Miller
#
#---------------------------------
#
# This script checks each current checkout and sets the value of issues.auto_renew to be consistent with circulation rules. 
# Primarily intended for migrated checkouts. Includes a --where parameter to filter based on the issues table.
#

use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;
use C4::Context;
use Koha::Checkouts;
use Koha::Items;
use Koha::Patrons;
use Koha::CirculationRules;

$| = 1;

my $debug = 0;
my $update = 0;
my $where = q{};
my $i = 0;
my $flipped = 0;

GetOptions(
   'where:s'  => \$where,
   'debug'    => \$debug,
   'update'   => \$update,
);

my $dbh=C4::Context->dbh();
my $querystr="SELECT itemnumber, borrowernumber FROM issues";
if ($where ne q{}){
   $where = " WHERE ".$where;
   $querystr .= $where;
}
$debug and print $querystr."\n";
my $sth=$dbh->prepare($querystr);
$sth->execute();

RECORD:
while (my $line=$sth->fetchrow_hashref()){
   last RECORD if ($debug and $i>1000);
   $i++;
   print "." unless ($i % 10);
   print "\r$i" unless ($i % 100);
   my $auto_renew;
   my $issue = Koha::Checkouts->find( { itemnumber => $line->{itemnumber} } );
   my $item = Koha::Items->find({ itemnumber => $line->{itemnumber} } );
   my $patron = Koha::Patrons->find({ borrowernumber => $line->{borrowernumber} } ); 
   next RECORD unless ($issue && $item && $patron);
   
   my $rule = Koha::CirculationRules->get_effective_rule_value(
      {
         categorycode => $patron->categorycode,
         itemtype     => $item->effective_itemtype,
         branchcode   => $issue->branchcode,
         rule_name    => 'auto_renew'
      }
   );
   $auto_renew = $rule if defined $rule && $rule ne '';
   if ($issue->auto_renew ne $auto_renew){
      $debug and print "Flipping auto_renew for $line->{itemnumber}.\n";
      if ($update){
         $issue->set( { auto_renew => $auto_renew } )->store;
         $flipped++;
      }
   }
}

print "\n\n$i records read.\n$flipped auto_renewal flags changed.\n"
