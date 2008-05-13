# $Id$
package TypeCast::Atom::Comment;
use strict;
use warnings;

use base qw( TypeCast::Atom );

sub atom_type { 'comment' }

sub init {
    my $comment = shift;
    my($atom, $entry) = @_;
    $comment->{__entry} = $entry;
    $comment;
}

sub entry { $_[0]->{__entry} }

sub text {
    my $comment = shift;
    unless (defined $comment->{__text}) {
        $comment->{__text} = $comment->atom->content->body;
    }
    $comment->{__text};
}

sub author {
    my $comment = shift;
    unless (defined $comment->{__author}) {
        $comment->{__author} = $comment->atom->author->name;
    }
    $comment->{__author};
}

sub email {
    my $comment = shift;
    unless (defined $comment->{__email}) {
        $comment->{__email} = $comment->atom->author->email;
    }
    $comment->{__email};
}

sub url {
    my $comment = shift;
    unless (defined $comment->{__url}) {
        $comment->{__url} = $comment->atom->author->uri;
    }
    $comment->{__url};
}

sub is_visible { 1 }

sub created_on {
    my $entry = shift;
    unless (defined $entry->{__created_on}) {
        $entry->{__created_on} = MT::Date->parse_date($entry->atom->issued)->ts_utc;
    }
    $entry->{__created_on};
}

*created_on_obj = MT::Comment->can('created_on_obj');

1;
