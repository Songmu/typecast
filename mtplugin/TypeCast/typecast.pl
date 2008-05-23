# $Id$
package MT::Plugin::TypeCast;

use strict;
use warnings;
our $VERSION = '0.01';

use base qw( MT::Plugin );

MT->add_plugin(__PACKAGE__->new({
    name        => 'TypeCast',
    description => 'Extend Atom API for TypeCast',
    author_name => 'Hiroshi Sakai',
    version     => $VERSION,
}));

MT->add_callback('get_posts', 0, undef, \&_callback_get_posts);
MT->add_callback('get_post',  0, undef, \&_callback_get_post);

sub _callback_get_posts {
    my $cb = shift;
    my ($feed, $blog) = @_;

    my $app = MT->instance;
    my %arg = %{ $app->{param} };
    ## TODO: Need a patch for R37 MT::AtomServer to designate limit by typecast.
    $arg{limit} ||= 20 + 1;

    _setup_next_prev($feed, $blog, \%arg);
}

sub _callback_get_post {
    my $cb = shift;
    my ($atom, $entry) = @_;

    my $blog = $entry->blog;
    _add_next_prev_link($blog, $entry, $atom, 'next', 'next');
    _add_next_prev_link($blog, $entry, $atom, 'prev', 'previous');

    ## TODO: This should be done in MT::AtomServer, no, really.
    my ($replies) = grep {
        $_->rel eq 'replies'
    } $atom->links;
    if ($replies) {
        require XML::Atom;
        my $ns = XML::Atom::Namespace->new(thr => 'http://purl.org/syndication/thread/1.0');
        $replies->set($ns, 'count', $entry->comment_count);
    }
}

sub _setup_next_prev {
    my ($feed, $blog, $arg) = @_;

    my $count = MT::Entry->count({
        class   => 'entry',
        status  => MT::Entry::RELEASE(),
        blog_id => $blog->id,
    });

    if ($arg->{offset} >= $arg->{limit}) {
        my $offset = $arg->{offset} - $arg->{limit};
        $feed->add_link({
            rel  => 'prev',
            type => 'application/atom+xml',
            href => _atom_script_url() . "/offset=$offset/limit=$arg->{limit}",
        });
    }
    if ($count > $arg->{offset} + $arg->{limit}) {
        my $offset = $arg->{offset} + $arg->{limit};
        $feed->add_link({
            rel  => 'next',
            type => 'application/atom+xml',
            href => _atom_script_url() . "/offset=$offset/limit=$arg->{limit}",
        });
    }
}

sub _add_next_prev_link {
    my ($blog, $entry, $atom, $rel, $method) = @_;

    if (my $e = $entry->$method({ status => MT::Entry::RELEASE() })) {
        my $link = XML::Atom::Link->new;
        $link->rel($rel);
        $link->type('application/atom+xml');
        $link->href(_atom_script_url() . '/blog_id=' . $blog->id . '/entry_id=' . $e->id);
        $link->title($e->title);
        $atom->add_link($link);
    }
}

sub _atom_script_url {
    my $app = MT->instance;
    $app->base . $app->app_path . $app->script;
}

1;
__END__
