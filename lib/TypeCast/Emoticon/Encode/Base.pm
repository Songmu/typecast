# $Id$
package TypeCast::Emoticon::Encode::Base;

use strict;
use warnings;

use base qw( Class::Accessor::Fast );

use TypeCast::Emoticon;

__PACKAGE__->mk_accessors(qw( edit_mode static_url ));

sub new {
    my $class = shift;
    my %param = @_;
    return bless \%param, $class;
}

sub encode {
    return unless $_[1];
    $_[1] =~ s{$TypeCast::Emoticon::IS_EMOTICON_RE}{$_[0]->lookup($1)}eg;
}

sub remove_broken_emoticon {
    return unless $_[1];
    $_[1] =~ s{$TypeCast::Emoticon::BROKEN_EMOTICON_RE(\.*?)$}{$1};
}

sub lookup { die 'ABSTRACT' }

1;
__END__
