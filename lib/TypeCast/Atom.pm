# $Id$
package TypeCast::Atom;
use strict;
use warnings;

use base qw( MT::ErrorHandler );

sub new_from_atom {
    my $class = shift;
    my($atom) = @_;
    my $thing = bless { atom => $atom }, $class;
    $thing->init(@_);
}

sub atom { $_[0]->{atom} }

sub init {
    my $thing = shift;
    $thing;
}

sub id {
    my $thing = shift;
    unless ($thing->{__id}) {
        my $id_base = TypePad->current_portal->atom_id_base;
        my $type    = $thing->atom_type;
        $thing->{__id} = ($thing->atom->id =~ /^tag:\Q$id_base\E:$type-(\d+)$/)[0];
    }
    $thing->{__id};
}

sub set_values {
    my $thing = shift;
    my %values = @_;
    for my $key (keys %values) {
        $thing->{"__" . $key} = $values{$key};
    }
}

sub atom_type { die "atom_type undefined!" }

1;
