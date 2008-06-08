# $Id$
package TypeCast::Emoticon::Encode::MobileJP;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Encode::Base );

use TypeCast::Emoticon;

sub emoticon { die }

sub lookup {
    my $self = shift;
    my $id   = shift or return '';

    return '&'.$id.';' if $id =~ /^#x/;

    my $code = $self->emoticon->{$id};
    return TypeCast::Emoticon::tag($id) if $self->{edit_mode} && !$code;
    ## Ouptut japanese turned letter, U+3013, if no proper emoticon was found.
    return Encode::encode('utf-8', chr(hex($code || '3013')));
}

1;
__END__
