# $Id$
package TypeCast::ContentFilter::KDDI;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Base);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'application/xhtml+xml';
    $filter->{encoding}      = 'Shift_JIS';
    $filter->{input_encoding} = 'shift_jis-kddi';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 1;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 1;
}

## use Shift_JIS version
my %emoticon_map = (
    video        => 110, # &#xF6F0
    audio        => 291, # &#xF6DE
    image        => 94,  # &#xF6EE
    view         => 161, # &#xF7A5
    entry        => 56,  # &#xF77D
    edit         => 149, # &#xF679
    moderated    => 1,   # &#xF659
    delete       => 61,  # &#xF76C
    comment      => 86,  # &#xF6D6
    trackback    => 117, # &#xF778

    digit1       => 180, # &#xF6FB
    digit2       => 181, # &#xF6FC
    digit3       => 182, # &#xF740
    digit4       => 183, # &#xF741
    digit5       => 184, # &#xF742
    digit6       => 185, # &#xF743
    digit7       => 186, # &#xF744
    digit8       => 187, # &#xF745
    digit9       => 188, # &#xF746
    digit0       => 325, # &#xF7C9

    config1      => 314, # &#xF7BE
    config2      => 315, # &#xF7BF
    config3      => 316, # &#xF7C0
    design       => 309, # &#xF7B9
    profile      => 257, # &#xF649
    moblog       => 161, # &#xF7A5
    phoneto      => 513, # &#xF7DF
);
$_ = qq{<img localsrc="$_" />} for values %emoticon_map;

sub lookup_emoticon {
    $emoticon_map{$_[1]};
}

sub declaration {
    my $filter = shift;
    $filter->SUPER::declaration(q{DOCTYPE html PUBLIC "-//OPENWAVE//DTD XHTML 1.0//EN" "http://www.openwave.com/DTD/xhtml-basic.dtd"});
}
1;
