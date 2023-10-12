use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::uc');

is( ToolBox::Mungers::uc->munge("TesT"), "TEST", "uc munger functions as expected" );

done_testing();
