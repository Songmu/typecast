# $Id$
package TypeCast::Error;
use strict;
use warnings;

use Error;
use base qw( Error::Simple );

sub message { shift->text }

## 500
package TypeCast::Error::Fatal;
use base qw( TypeCast::Error );

## 400
package TypeCast::Error::BadRequest;
use base qw( TypeCast::Error );
sub message { "Bad Request." }

## 401
package TypeCast::Error::Authentication;
use base qw( TypeCast::Error );
sub message { "Authorization Required." }

## 403
package TypeCast::Error::Unauthorized;
use base qw( TypeCast::Error );
sub message { "Forbidden." }

## 404
package TypeCast::Error::NotFound;
use base qw( TypeCast::Error );
sub message { "The request URL was not found." }

1;
__END__
