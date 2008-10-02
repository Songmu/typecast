# $Id$
package TypeCast::ContentFilter::VodafoneXHTML;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Vodafone);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'application/xhtml+xml';
    $filter->{encoding}      = 'utf-8';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 1;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 1;
}

my %emoticon_map = (
    video     => '&#xE03D;',
    audio     => '&#xE141;',
    image     => '&#xE008;',
    view      => '&#xE00A;',
    entry     => '&#xE148;',
    edit      => '&#xE301;',
    moderated => '&#xE252;',
    delete    => '&#xE219;',
    comment   => '&#xE32E;',
    trackback => '&#xE101;',

    digit1       => '&#xE21C;',
    digit2       => '&#xE21D;',
    digit3       => '&#xE21E;',
    digit4       => '&#xE21F;',
    digit5       => '&#xE220;',
    digit6       => '&#xE221;',
    digit7       => '&#xE222;',
    digit8       => '&#xE223;',
    digit9       => '&#xE224;',
    digit0       => '&#xE225;',

    sharp        => '&#xE210;',
    config1      => '&#xE20E;',
    config2      => '&#xE20D;',
    config3      => '&#xE20F;',
    design       => '&#xE502;',
    profile      => '&#xE057;',
    moblog       => '&#xE00A;',
    phoneto      => '&#xE104;',
);

sub lookup_emoticon {
    $emoticon_map{$_[1]};
}

1;
