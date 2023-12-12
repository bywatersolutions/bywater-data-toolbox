use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::dateFromFormat');

is( ToolBox::Mungers::dateFromFormat->munge('20111121', '%Y%m%d'), '2011-11-21', 'dateFromFormat munger functions as expected' );

done_testing();
