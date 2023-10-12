use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::money');

is( ToolBox::Mungers::money->munge('2'), '2', '2 remains 2' );
is( ToolBox::Mungers::money->munge('2.00'), '2.00', '2.00 remains 2.00' );
is( ToolBox::Mungers::money->munge('2.001'), '2.001', '2.001 remains 2.001' );
is( ToolBox::Mungers::money->munge('$2'), '2', '$2 becomes 2' );
is( ToolBox::Mungers::money->munge('$12.00'), '12.00', '$12.00 becomes 12.00' );
is( ToolBox::Mungers::money->munge('1,000.00'), '1000.00', '1,000.00 becomes 1000.00' );
is( ToolBox::Mungers::money->munge('$1,000.00'), '1000.00', '$1,000.00 becomes 1000.00' );

done_testing();
