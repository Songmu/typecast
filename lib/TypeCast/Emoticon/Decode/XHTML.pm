# $Id$
package TypeCast::Emoticon::Decode::XHTML;

use strict;
use warnings;

use base qw( TypeCast::Emoticon::Decode::Base );

use TypeCast::Emoticon;

sub decode {
    $_[1] =~ s{<img [^>]*?class="emoticon ([\w\-]+)".*?/>}{$_[0]->lookup($1) || $&}eg;
}

my $Emoticon;
sub lookup {
    my ($self, $id) = @_;
    $Emoticon ||= { reverse %{$self->{emoticon}->{docomo}} };
    my $code = $Emoticon->{$id} or return;
    ## Fixed emoticon names typo using alias names in emoticons list.
    $id = $code unless $code =~ /^[0-9A-F]{4}$/;
    return TypeCast::Emoticon::tag($id)
}

sub has_emoticon { 0 };

1;
