use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::firstword');

is( ToolBox::Mungers::firstword->munge("Testing 1 2 3"), "Testing", "firstword munger functions as expected" );

done_testing();
