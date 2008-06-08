# $Id$
package TypeCast::Emoticon::Encode::DoCoMo;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Encode::MobileJP );

sub emoticon { $_[0]->{emoticon}->{docomo} }

1;
