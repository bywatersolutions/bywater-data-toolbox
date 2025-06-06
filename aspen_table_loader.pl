#!/usr/bin/perl

use Modern::Perl;

use Data::Dumper;
use Getopt::Long;
use Text::CSV;
use Config::Tiny;
use DBI;
use Array::Utils qw(array_minus);
use Try::Tiny;
$|=1;

my $infile_name = "";
my $table_name = "";
my $debug=0;
my $doo_eet=0;
my $csv_delim = 'comma';
my $ini = "";
my $verbose="";

GetOptions(
    'in=s'     => \$infile_name,
    'table=s'  => \$table_name,
    'delimiter=s'  => \$csv_delim,
    'ini|i=s'  => \$ini,
    'verbose'  => \$verbose,
    'debug'    => \$debug,
    'update'   => \$doo_eet,
);

if (($infile_name eq '') || ($table_name eq '') || $ini eq ''){
   print "Something's missing.\n";
   exit;
}

my %delimiter = ( 'comma' => ',',
                  'tab'   => "\t",
                  'pipe'  => '|',
                );


my $config = Config::Tiny->read( $ini );
if ( !$config ) {
    die "Failed to read INI file: " . Config::Tiny->errstr . "\n";
}

# Create the Aspen connection
my $database_user         = $config->{Database}->{database_user};
my $database_password     = $config->{Database}->{database_password};
my $database_dsn          = $config->{Database}->{database_dsn};
my $database_aspen_dbname = $config->{Database}->{database_aspen_dbname};

# Remove outer quotes
$database_dsn =~ s/^(['"])(.*)\1$/$2/;

# Ensure all necessary keys are present
if (   !defined $database_user
    || !defined $database_password
    || !defined $database_dsn )
{
    die "Missing one or more required database connection keys"
      . " (database_user, database_pass, database_dsn) in the INI file\n";
}

# Connect to the database
my $aspen_dbh = DBI->connect(
    "DBI:$database_dsn",
    $database_user,
    $database_password,
    {
        RaiseError => 1,
        PrintError => 0,
        AutoCommit => 1,
    }
);

if ($aspen_dbh) {
    say "Successfully connected to the Aspen database." if $verbose;
}
else {
    die "Failed to connect to the Aspen database: " . DBI->errstr . "\n";
}

my $csv=Text::CSV_XS->new({ binary => 1, sep_char => $delimiter{$csv_delim} });
my $j=0;
my $exceptcount=0;
open my $io,"<$infile_name";
my $headerline = $csv->getline($io);
my @fields=@$headerline;

#$debug and print Dumper(@fields);
while (my $line=$csv->getline($io)){
   $debug and last if ($j>420); 
   $j++;
   print ".";
   print "\r$j" unless ($j % 100);
   my @data = @$line;
   $debug and print Dumper(@data);
   my $querystr = "INSERT INTO $table_name SET ";
   my $exception = 0;
   for (my $i=1;$i<scalar(@data);$i++){
     next if ($fields[$i] eq "");
      if ($fields[$i] eq "ignore"){
         next;
      }
      if (($data[$i] ne "") && ($fields[$i] ne "ignore")){
         $querystr .= $fields[$i]."=";
      }
      if (($data[$i] ne "") && ($fields[$i] ne "suppress")){
         $data[$i] =~ s/\"/\\"/g;
         $querystr .= '"'.$data[$i].'",';
      }
    } 
   $querystr =~ s/,$//;
   $querystr .= " WHERE $fields[0] = '$data[0]'";
   $debug and print $querystr."\n";
   if (!$exception){
      my $sth = $aspen_dbh->prepare($querystr);
      if ($doo_eet){
      $sth->execute();
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
