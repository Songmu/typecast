# $Id$
package TypeCast::Emoticon::Decode::DoCoMo;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Decode::MobileJP );

sub range    { '\x{E63E}-\x{E6A5}\x{E6AC}-\x{E6AE}\x{E6B1}-\x{E6BA}\x{E6CE}-\x{E757}' }
sub emoticon { $_[0]->{emoticon}->{docomo} }

1;
