# $Id$
package TypeCast::ContentFilter::Vodafone;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Base);

my %imemode_map = (
    1 => 'hiragana',
    2 => 'katakana',
    3 => 'alphabet',
    4 => 'numeric',
);

sub lookup_imemode {
    $imemode_map{$_[1]};
}

sub do_output_tag {
    my $filter = shift;
    my($tagname, $attr, $attrseq) = @_;

    # istyle to mode
    if (exists $attr->{istyle}) {
        my $mode = delete $attr->{istyle};
        $attr->{mode} = $filter->lookup_imemode($mode);
        push @$attrseq, 'mode';
    }

    $filter->SUPER::do_output_tag($tagname, $attr, $attrseq);
}

1;
