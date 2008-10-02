# $Id$
package TypeCast::ContentFilter::VodafoneHTML;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Vodafone);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'text/html';
    $filter->{encoding}      = 'Shift_JIS';
    $filter->{input_encoding} = 'shift_jis-vodafone';
    $filter->{is_xml}        = 0;
    $filter->{inline_css}    = 0;
    $filter->{strip_css}     = 1;
    $filter->{use_emoticons} = 1;
}

## use Shift_JIS escape sequence
my %emoticon_map = (
    video     => '$G]',
    audio     => '$Ea',
    image     => '$G(',
    view      => '$G*',
    entry     => '$Eh',
    edit      => '$O!',
    moderated => '$Fr',
    delete    => '$F9',
    comment   => '$ON',
    trackback => '$E!',

    digit1       => '$F<',
    digit2       => '$F=',
    digit3       => '$F>',
    digit4       => '$F?',
    digit5       => '$F@',
    digit6       => '$FA',
    digit7       => '$FB',
    digit8       => '$FC',
    digit9       => '$FD',
    digit0       => '$FE',

    sharp        => '$F0',
    config1      => '$F.',
    config2      => '$F-',
    config3      => '&F/',
    design       => '$Q"',
    profile      => '$Gw',
    moblog       => '$G*',
    phoneto      => '$E$',
);

sub lookup_emoticon {
    "\x1b" . $emoticon_map{$_[1]} . "\x0f";
}

sub do_output_tag {
    my $filter = shift;
    my($tagname, $attr, $attrseq) = @_;

    # accesskey to directkey
    if (exists $attr->{accesskey}) {
        my $key = delete $attr->{accesskey};
        $attr->{directkey} = $key;
        push @$attrseq, 'directkey';
        unless ($attr->{nonumber}) {
            $attr->{nonumber} = 'nonumber';
            push @$attrseq, 'nonumber';
        }
    }

    $filter->SUPER::do_output_tag($tagname, $attr, $attrseq);
}

1;
