# $Id$
use strict;
use Test::More tests => 6;

use_ok('TypeCast::Util');

can_ok('TypeCast::Util', 'match_ip_domain');
isnt(TypeCast::Util::match_ip_domain('204.9.178.11', []), 1);
is  (TypeCast::Util::match_ip_domain('204.9.178.11', [ 'www.typepad.com' ]), 1);
isnt(TypeCast::Util::match_ip_domain('204.9.178.11', [ 'www.typepad.jp' ]), 1);
is  (TypeCast::Util::match_ip_domain('222.15.68.216', [ 'ezweb.ne.jp' ]), 1);
