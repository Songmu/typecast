# $Id$
package TypeCast::Cache;

use strict;
use warnings;

use MT::Memcached;

sub new {
    my $class   = shift;
    my $blog_id = shift or die;

    my $app = MT->instance;
    my $self    = {
        blog_id => $blog_id,
        cache   => MT::Memcached->instance,
        exptime => {
            flag => $app->config->TypeCastFlagCacheExpTime || 24*60*60,
            atom => $app->config->TypeCastAtomCacheExpTime || 24*60*60,
            html => $app->config->TypeCastHTMLCacheExpTime ||  6*60*60,
        },
    };
    return bless $self, $class;
}

sub _key {
    my $self = shift;
    my @params = ( $self->{blog_id} );
    push @params, @_ if @_;
    return join ':', 'typecast', @params;
}

sub _set {
    my $self = shift;
    my ($key, @params) = @_;

    my ($type, $attr) = ( @$key, 'INDEX' );
    $self->{flag} = $self->{cache}->get($self->_key) || {};
    $self->{flag}{$type}{$attr} = 1;
    $self->{cache}->set($self->_key, $self->{flag}, $self->{exptime}->{flag});
    $self->{cache}->set($self->_key(@$key), @params);
}

sub _get {
    my ($self, $key) = @_;

    my ($type, $attr) = ( @$key, 'INDEX' );
    my $flagkey = $self->_key;
    my $memkey  = $self->_key(@$key);
    my $data = $self->{cache}->get_multi($flagkey, $memkey);
    $self->{flag} = $data->{$flagkey} || {};
    return unless $self->{flag}{$type};
    return unless $self->{flag}{$type}{$attr};
    return $data->{$memkey};
}

sub _delete {
    my ($self, @keys) = @_;

    ## remove all cache if cache keys were not desingated.
    return $self->{cache}->delete($self->_key) unless @keys;

    ## remove logically by remove flags.
    $self->{flag} = $self->{cache}->get($self->_key) or return;
    my $deleted = 0;
    for my $key (@keys) {
        my ($type, $attr) = @$key;
        if ($attr && $self->{flag}{$type}) {
            $deleted++ if delete $self->{flag}{$type}{$attr};
        }
        elsif ($self->{flag}{$type}) {
            $deleted++ if delete $self->{flag}{$type};
        }
    }
    if ($deleted) {
        $self->{cache}->set($self->_key, $self->{flag}, $self->{exptime}->{flag});
    }
}

#
# Set/Get HTML
#
sub html_main {
    my $self = shift;
    my ($page, $html_ref) = @_;
    my $memkey = [ 'html:main', $page ];
    unless ($html_ref) {
        return $self->_get($memkey);
    }
    else {
        return $self->_set($memkey, $$html_ref, $self->{exptime}->{html});
    }
}

sub html_entry {
    my $self = shift;
    my ($entry_id, $html_ref) = @_;
    my $memkey = [ 'html:entry', $entry_id ];
    unless ($html_ref) {
        return $self->_get($memkey);
    }
    else {
        return $self->_set($memkey, $$html_ref, $self->{exptime}->{html});
    }
}

#
# Set/Get Atom
#
sub atom_blog {
    my $self = shift;
    my ($page, $atom) = @_;
    my $memkey = [ 'atom:blog', $page ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

sub atom_entry {
    my $self = shift;
    my ($entry_id, $atom) = @_;
    my $memkey = [ 'atom:entry', $entry_id ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

sub atom_entry_comments {
    my $self = shift;
    my ($entry_id, $page, $atom) = @_;
    my $memkey = [ qq{atom:entry_comments:$entry_id}, $page ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

sub atom_category {
    my $self = shift;
    my ($cat_id, $atom) = @_;
    my $memkey = [ 'atom:category' ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

sub atom_category_archive {
    my $self = shift;
    my ($cat_id, $page, $atom) = @_;
    my $memkey = [ qq{atom:category_archive:$cat_id}, $page ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

sub atom_recent_comments {
    my $self = shift;
    my ($atom) = @_;
    my $memkey = [ 'atom:recent_comments' ];
    unless ($atom) {
        return $self->_get($memkey);
    }
    elsif ($atom->can('as_xml')) {
        return $self->_set($memkey, $atom->as_xml, $self->{exptime}->{atom});
    }
}

#
# purge on some events (class methods)
#
sub purge_on_update_blog {
    my ($class, $blog_id) = @_;
    my $c = $class->new($blog_id);
    $c->_delete;
}

sub purge_on_new_entry {
    my $class = shift;
    my ($blog_id, $entry_id, $cat_ids) = @_;
    my $c = $class->new($blog_id);
    my @cats;
    if ($cat_ids && @$cat_ids) {
        push(@cats, [ qq{atom:category_archive:$_} ]) for @$cat_ids;
    }
    $c->_delete(
        [ 'html:main' ], [ 'html:entry', ],
        [ 'atom:blog' ], [ 'atom:entry', ],
        [ 'atom:category' ], @cats,
    );
}

*purge_on_update_entry = \&purge_on_update_blog;
*purge_on_delete_entry = \&purge_on_update_blog;

sub purge_on_new_comment {
    my ($class, $blog_id, $entry_id) = @_;
    my $c = $class->new($blog_id);
    $c->_delete(
        [ 'atom:entry', $entry_id ],
        [ qq{atom:entry_comments:$entry_id} ], [ 'atom:recent_comments' ],
    );
}

sub purge_on_update_comment {
    my ($class, $blog_id, @entry_ids) = @_;
    my @entry_comments;
    for my $id (@entry_ids) {
        push @entry_comments, [ 'atom:entry', $id ], [ qq{atom:entry_comments:$id} ];
    }
    my $c = $class->new($blog_id);
    $c->_delete(@entry_comments, [ 'atom:recent_comments' ]);
}

*purge_on_delete_comment = \&purge_on_new_comment;

*purge_on_update_category = \&purge_on_update_blog;

1;
__END__

=head1 NAME

TypeCast::Cache - Set/Get/Purge TypeCast HTML/Atom caches.

=head1 SYNOPSIS

    # get / set cache
    my $cache = TypeCast::Cache->new($blog_id);
    my $html  = $cache->html_main;
    $cache->html_main(\$text);

    # purge
    TypeCast::Cache->purge_on_update_blog($blog_id);

=head1 DESCRIPTION

=head1 CLASS METHODS

=head2 new

=head2 purge_on_update_blog

=head2 purge_on_new_entry

=head2 purge_on_update_entry

=head2 purge_on_delete_entry

=head2 purge_on_new_comment

=head2 purge_on_update_comment

=head2 purge_on_delete_comment

=head2 purge_on_update_category

=head1 INSTANCE METHODS

Instance methods to set/get the cache.

=head2 html_main

=head2 html_entry

=head2 atom_blog

=head2 atom_entry

=head2 atom_entry_comments

=head2 atom_category

=head2 atom_category_archive

=head2 atom_recent_comments

=cut
