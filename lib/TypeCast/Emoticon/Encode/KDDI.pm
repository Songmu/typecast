# $Id$
package TypeCast::Emoticon::Encode::KDDI;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Encode::MobileJP );

sub emoticon { $_[0]->{emoticon}->{kddi} }

1;
