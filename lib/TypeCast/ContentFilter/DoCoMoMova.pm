# Copyright 2005 Six Apart. This code cannot be redistributed without
# permission from www.sixapart.com.
#
# $Id$

package TypeCast::ContentFilter::DoCoMoMova;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Base);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'text/html';
    $filter->{encoding}      = 'Shift_JIS';
    $filter->{input_encoding} = 'shift_jis-imode';
    $filter->{is_xml}        = 0;
    $filter->{inline_css}    = 0;
    $filter->{strip_css}     = 1;
    $filter->{use_emoticons} = 1;
}

sub lookup_emoticon {
    TypeCast::ContentFilter::DoCoMoFOMA->lookup_emoticon($_[1]);
}

1;
