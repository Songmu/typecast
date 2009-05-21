use strict;
use Test::More tests => 4;

use_ok('TypeCast::Util');

can_ok('TypeCast::Util', 'match_ip_domain');

SKIP: {
    unless (gethostbyname 'www.cpan.org') {
        skip(q{couldn't resolve name}, 2);
    }
    isnt(TypeCast::Util::match_ip_domain('222.15.68.216', []), 1);
    is  (TypeCast::Util::match_ip_domain('222.15.68.216', [ 'ezweb.ne.jp' ]), 1);
}
