# $Id$
package TypeCast::Emoticon;

use strict;
use warnings;

our $START_TAG          = '[E:';
our $END_TAG            = ']';
our $BROKEN_EMOTICON_RE = qr{\[(?:E:?[\w\-]{0,16})?};
our $IS_EMOTICON_RE     = qr{\Q$START_TAG\E([\w\-]+|#x\w{4})\Q$END_TAG\E};

sub tag {
    my $id = shift or return '';
    $START_TAG . $id . $END_TAG;
}

sub has_emoticon {
    my $str = shift or return;
    $str =~ /$IS_EMOTICON_RE/;
}

sub remove_broken_emoticon {
    my $str = shift or return;
    $str =~ s/$BROKEN_EMOTICON_RE$//;
    $str;
}

1;
__END__
