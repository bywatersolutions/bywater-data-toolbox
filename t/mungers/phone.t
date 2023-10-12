use Test::More;
use FindBin;
use lib "$FindBin::Bin/../..";

use_ok('ToolBox::Mungers::phone');

is( ToolBox::Mungers::phone->munge('1234567890'), '(123)456-7890', 'Raw phone number reformatted correctly' );
is( ToolBox::Mungers::phone->munge('PHONE1234567890'), 'PHONE1234567890', 'Non-numeric data is not modified.' );
is( ToolBox::Mungers::phone->munge('4567890'), '4567890', 'Non-10 digit data is not modified.' );

done_testing();
