# $Id$
package TypeCast::Remote::Comment;
use strict;
use warnings;

use base qw( TypeCast::Remote );

sub atom_type { 'comment' }

sub init {
    my $comment = shift;
    my($atom, $entry) = @_;
    $comment->{__entry} = $entry;
    $comment;
}

sub id {
    my $thing = shift;

    ## MTOS AtomAPI format id
    $thing->{__id} ||= ($thing->atom->id =~ m{^tag:[^\:]+:.*/(\d+)$})[0];
}

sub entry    { $_[0]->{__entry} }
sub entry_id { $_[0]->{__entry}->id }

sub text {
    my $comment = shift;
    unless (defined $comment->{__text}) {
        $comment->{__text} = $comment->atom->content->body;
        Encode::_utf8_off($comment->{__text});
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
        $entry->{__created_on} = TypeCast::Util::parse_date($entry->atom->issued)->ts;
    }
    $entry->{__created_on};
}

*created_on_obj = MT::Comment->can('created_on_obj') || sub {};

package TypeCast::Remote::Comments;

sub new {
    my $class = shift;
    my($entry, $feed, $blog) = @_;

    my $self = bless { feed => $feed, entry => $entry, blog => $blog }, $class;
    $self->init;
}

sub init {
    my $self = shift;
    my @comments;
    for my $comment ($self->{feed}->entries) {
        my $entry = $self->{entry};
        unless ($entry) {
            ## create entry object, it will be used by recent_comments mode.
            my $atom = XML::Atom::Entry->new;
            $atom->title($comment->title);
            $atom->issued($comment->issued);
            $entry = TypeCast::Remote::Entry->new_from_atom($atom, $self->{blog});
            my ($edit_uri) = grep { $_->rel eq 'service.edit' } $comment->link;
            my ($entry_id) = $edit_uri->href =~ /\bentry_id=(\d+)\b/;
            $entry->set_values(id => $entry_id);
        }
        push @comments, TypeCast::Remote::Comment->new_from_atom($comment, $entry);
    }
    $self->{comments} = \@comments;
    for my $link ($self->{feed}->link) {
        $self->{link}->{$link->rel, $link->type} = $link;
    }
    $self;
}

sub comments { $_[0]->{comments} }

sub has_next {
    my $comments = shift;
    exists $comments->{link}->{"next", "application/x.atom+xml"} ||
        exists $comments->{link}->{"next", "application/atom+xml"};
}

sub has_prev {
    my $comments = shift;
    exists $comments->{link}->{"prev", "application/x.atom+xml"} ||
        exists $comments->{link}->{"prev", "application/atom+xml"};
}

1;
