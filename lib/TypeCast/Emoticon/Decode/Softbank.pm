# $Id$
package TypeCast::Emoticon::Decode::Softbank;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Decode::MobileJP );

sub range    { '\x{E001}-\x{E05A}\x{E101}-\x{E15A}\x{E201}-\x{E25A}\x{E301}-\x{E34D}\x{E401}-\x{E44C}\x{E501}-\x{E539}' }
sub emoticon { $_[0]->{emoticon}->{softbank} }

1;
