# $Id$
package TypeCast::ContentFilter::AirEDGE;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Base);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'text/html';
    $filter->{encoding}      = 'utf-8';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 1;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 1;
}

sub lookup_emoticon {
    TypeCast::ContentFilter::DoCoMoFOMA->lookup_emoticon($_[1]);
}

1;
