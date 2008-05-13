# $Id$
package TypeCast::Remote;
use strict;
use warnings;

no strict 'refs';

use XML::Atom;
use XML::Atom::Entry;
use XML::Atom::Util qw( nodelist );

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
        my $type = $thing->atom_type;
        $thing->{__id} = ($thing->atom->id =~ m{^tag:[^\:]+:$type-(\d+)$})[0];
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

sub user_id {
    my $thing = shift;
    my ($user_id) = @_;
    if (defined $user_id) {
        $thing->{__user_id} = $user_id;
    }
    $thing->{__user_id};

}
*owner_id = \&user_id;

1;
