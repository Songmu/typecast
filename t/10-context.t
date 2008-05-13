use strict;
use Test::More tests => 2;

BEGIN { use_ok('TypeCast::Template::Context') };

my $ctx = TypeCast::Template::Context->new;
isa_ok($ctx, 'TypeCast::Template::Context');
