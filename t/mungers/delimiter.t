use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::delimiter');

is( ToolBox::Mungers::delimiter->munge("TesT"), "TesT ; ", "delimiter munger functions as expected" );

done_testing();
