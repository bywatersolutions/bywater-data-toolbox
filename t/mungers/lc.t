use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::lc');

is( ToolBox::Mungers::lc->munge("TesT"), "test", "lc munger functions as expected" );

done_testing();
