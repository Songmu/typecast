# $Id$
package TypeCast::Emoticon::Decode::KDDI;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Decode::MobileJP );

sub range    { '\x{E468}-\x{E5DF}\x{EA80}-\x{EB88}' }
sub emoticon { $_[0]->{emoticon}->{kddi} }

1;
