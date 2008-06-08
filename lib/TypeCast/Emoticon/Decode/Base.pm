# $Id$
package TypeCast::Emoticon::Decode::Base;

use strict;
use warnings;

sub new {
    my $class = shift;
    my %param = @_;
    return bless { emoticon => $param{emoticon} }, $class;
}

sub decode       { die 'ABSTRACT' }
sub lookup       { die 'ABSTRACT' }
sub has_emoticon { die 'ABSTRACT' }

1;
