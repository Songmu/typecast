# $Id$
package TypeCast::Emoticon::Encode::XHTML;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Encode::Base );

sub lookup {
    my $self = shift;
    my $id   = shift or return '';

    return '&'.$id.';' if $id =~ /^#x/;

    my $static_url = $self->static_url;
    my $code = $self->{emoticon}->{docomo}->{$id}
        or return TypeCast::Emoticon::tag($id);
    ## Fixed emoticon names typo using alias names in emoticons list.
    $id = $code unless $code =~ /^[0-9A-F]{4}$/;
    return $self->{edit_mode}
        ? TypeCast::Emoticon::tag($id)
        : qq{<img class="emoticon $id" src="${static_url}/images/emoticons/$id.gif" alt="$id" />}
        ;
}

1;
