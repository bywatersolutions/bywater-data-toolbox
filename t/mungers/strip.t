use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::strip');

is( ToolBox::Mungers::strip->munge("test"), "test", "strip munger doesn't modify item with no commas" );
is( ToolBox::Mungers::strip->munge(",test,test,test,"), "testtesttest", "strip munger removes all commas from string" );

done_testing();
