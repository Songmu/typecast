# $Id$
package TypeCast::ContentFilter::Nokia;
use strict;
use warnings;

use base qw(TypeCast::ContentFilter::Base);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'application/xhtml+xml';
    $filter->{encoding}      = 'utf-8';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 1;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 0;
}

1;
