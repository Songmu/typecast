# $Id$
use strict;
use warnings;

use Test::Base no_plan => 1;

use FindBin;
use HTTP::MobileAgent;
use Encode ();

use_ok 'TypeCast::Emoticon::Encode';

my %ua = (
    docomo   => 'DoCoMo/2.0 ',
    kddi     => 'KDDI-SA31 UP.Browser/',
    softbank => 'SoftBank/1.0/',
    xhtml    => '',
);

my $filter;
sub emoticon {
    my $type = filter_arguments;
    $filter = TypeCast::Emoticon::Encode->new(
        agent      => HTTP::MobileAgent->new($ua{$type}),
        config     => "$FindBin::Bin/../conf/emoticon.yaml",
        static_url => '/tc/static',
    );
    $filter->encode($_);
    return $_;
}

sub remove_broken_emoticon {
    $filter->remove_broken_emoticon($_);
    return $_;
}

sub encode {
    return Encode::encode('utf-8', $_);
}

filters {
    input    => [ qw(chomp) ],
    expected => [ qw(chomp) ],
};

run_compare;

__END__

=== DoCoMo
--- input emoticon=docomo
[E:sun]
--- expected eval encode
"\x{E63E}"

=== KDDI
--- input emoticon=kddi
[E:sun]
--- expected eval encode
"\x{E488}"

=== Softbank
--- input emoticon=softbank
[E:sun]
--- expected eval encode
"\x{E04A}"

=== XHTML
--- input emoticon=xhtml
[E:sun]
--- expected
<img class="emoticon sun" src="/tc/static/images/emoticons/sun.gif" alt="sun" />

=== out of range
--- input emoticon=docomo
[E:#xE001]
--- expected
&#xE001;

=== unknown emoticon for KDDI
--- input emoticon=kddi
[E:info01]
--- expected eval encode=shift_jis-kddi
"\x{3013}"

=== unknown emoticon for Softbank
--- input emoticon=softbank
[E:info01]
--- expected eval encode=utf-8
"\x{3013}"

=== remove broken emoticon
--- input emoticon=xhtml remove_broken_emoticon
Emoticon![E:s
--- expected
Emoticon!

=== remove broken emoticon
--- input emoticon=xhtml remove_broken_emoticon
Emoticon![E:
--- expected
Emoticon!

=== remove broken emoticon
--- input emoticon=xhtml remove_broken_emoticon
Emoticon![E
--- expected
Emoticon!

=== remove broken emoticon
--- input emoticon=xhtml remove_broken_emoticon
Emoticon![
--- expected
Emoticon!

=== not broken emoticon
--- input emoticon=xhtml remove_broken_emoticon
Emoticon![foo
--- expected
Emoticon![foo
