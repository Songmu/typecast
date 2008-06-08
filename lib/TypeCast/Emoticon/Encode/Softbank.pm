# $Id$
package TypeCast::Emoticon::Encode::Softbank;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Encode::MobileJP );

sub emoticon { $_[0]->{emoticon}->{softbank} }

1;
