# $Id$
use strict;
use warnings;

use Test::Base no_plan => 1;

use FindBin;
use HTTP::MobileAgent;

use_ok 'TypeCast::Emoticon::Decode';

my %ua = (
    docomo   => 'DoCoMo/2.0 ',
    kddi     => 'KDDI-SA31 UP.Browser/',
    softbank => 'SoftBank/1.0/',
    xhtml    => '',
);
my %filters;
for my $id (keys %ua) {
    $filters{$id} = TypeCast::Emoticon::Decode->new(
        agent  => HTTP::MobileAgent->new($ua{$id}),
        config => "$FindBin::Bin/../conf/emoticon.yaml",
    );
}

sub decode {
    my $type = filter_arguments;
    $filters{$type}->decode($_);
    return $_;
}

filters {
    input    => [ qw(chomp eval) ],
    expected => [ qw(chomp) ],
};

run_compare;

__END__

=== DoCoMo
--- input decode=docomo
"\x{E63E}"
--- expected
[E:sun]

=== KDDI
--- input decode=kddi
"\x{E469}"
--- expected
[E:typhoon]

=== Softbank
--- input decode=softbank
"\x{E003}"
--- expected
[E:kissmark]

=== Softbank Page2
--- input decode=softbank
"\x{E107}"
--- expected
[E:shock]

=== XHTML
--- input decode=xhtml
'<img class="emoticon sun" src="/tc/static/images/emoticons/sun.gif" />'
--- expected
[E:sun]

=== KDDI out of range
--- input decode=kddi
"\x{E46C}"
--- expected
[E:#xE46C]

=== Softbank out of range
--- input decode=softbank
"\x{E001}"
--- expected
[E:#xE001]
