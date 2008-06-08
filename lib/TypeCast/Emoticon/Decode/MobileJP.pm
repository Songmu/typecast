# $Id$
package TypeCast::Emoticon::Decode::MobileJP;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Decode::Base );

use TypeCast::Emoticon;
use Encode ();

sub range    { die 'ABSTRACT' }
sub emoticon { die 'ABSTRACT' }

sub decode {
    Encode::_utf8_on($_[1]);
    my $range = $_[0]->range;
    $_[1] =~ s{([$range])}{$_[0]->lookup($1)}eg;
    Encode::_utf8_off($_[1]);
}

sub lookup {
    my ($self, $char) = @_;
    my $hex = sprintf '%X', ord($char);
    my $e   = $self->emoticon->{$hex};
    return $e ? TypeCast::Emoticon::tag($e) : TypeCast::Emoticon::tag('#x'.$hex);
}

sub has_emoticon {
    my ($self, $str) = @_;
    return unless $str;
    Encode::_utf8_on($str) unless Encode::is_utf8($str);
    my $range = $self->range;
    return $str =~ /[$range]/;
}

1;
