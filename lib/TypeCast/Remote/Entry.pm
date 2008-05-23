# $Id$
package TypeCast::Remote::Entry;
use strict;
use warnings;

use base qw( TypeCast::Remote );

use Encode ();
use XML::Atom;
use XML::Atom::Entry;
use XML::Atom::Util qw( nodelist );
use TypeCast::Util;

use constant NS_DC   => "http://purl.org/dc/elements/1.1/";
use constant NS_POST => 'http://sixapart.com/atom/post#';

sub atom_type { 'post' }

sub init {
    my $entry = shift;
    my($atom, $blog) = @_;
    $entry->{__blog} = $blog;
    $entry;
}

## TCOS:
sub id {
    my $thing = shift;
    unless ($thing->{__id}) {
        ($thing->{__id}) = $thing->atom->id =~ /(\d+)$/;
    }
    $thing->{__id};
}

sub blog { $_[0]->{__blog} }

sub title {
    $_[0]->atom->title;
}

sub text {
    my $entry = shift;
    unless (defined $entry->{__text}) {
        my $text = $entry->atom->content->body;
        ## XXX: Hack XML-Atom generated Unicode reference
        $text =~ s/&#x([0-9A-F]{4});/Encode::encode("utf-8", chr(hex($1)))/eig;
        Encode::_utf8_off($text);
        $entry->{__text} = $text;
    }
    $entry->{__text};
}

sub url {
    my $entry = shift;
    unless ($entry->{__url}) {
        for my $link ($entry->atom->link) {
            if ($link->type eq 'text/html' && $link->rel eq 'alternate') {
                $entry->{__url} = $link->href;
                last;
            }
        }
    }
    $entry->{__url};
}

sub text_more { }

sub excerpt {
    $_[0]->atom->summary;
}

sub enclosures {
    my $entry = shift;
    my ($key, $val) = @_;
    my $cond = @_ == 2
        ? sub { $_->rel eq 'enclosure' && $_->$key eq $val }
        : sub { $_->rel eq 'enclosure' };
    my @link = grep { $cond->($_) } $entry->atom->link;
    return \@link;
}

sub convert_breaks {
    ($_[0]->atom->get(NS_POST, "convertLineBreaks") || '') eq 'true';
}

sub text_filters { [ ] }

sub categories {
    my $entry = shift;
    unless (defined $entry->{__categories}) {
        my $atom = $entry->atom;
        my $dc = XML::Atom::Namespace->new(dc => NS_DC);
        my @subject = ($atom->getlist($dc, 'subject'), _categories_of_atom_entry($atom));
        $entry->{__categories} = [ map {
            Encode::_utf8_off($_);
            my ($id, $label) = split /:/, $_, 2;
            my $cat = MT::Category->new;
            $cat->blog_id($entry->blog->id);
            $cat->id($id);
            $cat->label($label);
            $cat;
        } @subject ];
    }
    $entry->{__categories};
}

sub created_on {
    my $entry = shift;
    unless (defined $entry->{__created_on}) {
        $entry->{__created_on} = TypeCast::Util::parse_date($entry->atom->issued)->ts;
    }
    $entry->{__created_on};
}

*created_on_obj = MT::Entry->can('created_on_obj') || sub {};

sub _init_comments {
    my $entry = shift;
    $entry->{__comments_info} = { allow => 0, count => 0 };
    for my $link ($entry->atom->link) {
        if ($link->rel eq 'entry.comments') {
            ## TODO: support $link->get($ns, $attr) in XML::Atom
            my $count = ($link->as_xml =~ /comment:count="(\d+)"/)[0] || 0;
            my $allow = ($link->as_xml =~ /comment:allow="(\d+)"/)[0] || 1;
            Encode::_utf8_off($count);
            $entry->{__comments_info}->{count} = $count;
            $entry->{__comments_info}->{allow} = $allow;
            return;
        }
        elsif ($link->rel eq 'replies') {
            ## TODO: support $link->get($ns, $attr) in XML::Atom
            #require XML::Atom;
            #my $ns = XML::Atom::Namespace->new(thr => 'http://purl.org/syndication/thread/1.0');
            #my $count = $link->get($ns, 'count');
            # Try count attribute specified in Atom ThreadingExtension
            my $count = ($link->as_xml =~ /thr:count="(\d+)"/)[0] || 0;
            Encode::_utf8_off($count);
            $entry->{__comments_info}->{count} = $count;
        }
    }
}

sub allow_comments {
    my $entry = shift;
    unless ($entry->{__comments_info}) {
        $entry->_init_comments;
    }
    $entry->{__comments_info}->{allow};
}

sub allow_pings { 0 }

sub comment_count {
    my $entry = shift;
    unless ($entry->{__comments_info}) {
        $entry->_init_comments;
    }
    $entry->{__comments_info}->{count};
}

sub ping_count { 0 }

*comment_status = \&allow_comments;

sub previous { $_[0]->_neighbor_entry('prev') }
sub next     { $_[0]->_neighbor_entry('next') }

sub _neighbor_entry {
    my $entry = shift;
    my($rel) = @_;
    unless ($entry->{__neighbor}) {
        $entry->_init_neighbor;
    }
    $entry->{__neighbor}->{$rel};
}

sub _init_neighbor {
    my $entry = shift;
    for my $link ($entry->atom->link) {
        if ($link->rel eq 'next' || $link->rel eq 'prev') {
            $entry->{__neighbor}->{$link->rel} = TypeCast::Remote::Entry::Neighbor->new($link);
        }
    }
}

sub set_comments {
    my $entry = shift;
    my($comments) = @_;
    $entry->{__comments} = $comments;
}

sub comments {
    $_[0]->{__comments} || [];
}

sub _categories_of_atom_entry {
    my ($entry) = @_;
    return map  { $_->getAttribute('term') }
           grep { ($_->getAttribute('scheme')||'') =~ /#category$/ }
           map  { nodelist($entry->elem, $_, 'category') }
           ('http://www.w3.org/2005/Atom', 'http://purl.org/atom/ns#');
}

package TypeCast::Remote::Entry::Neighbor;

## Mock object for <MTEntryPrevious> & <MTEntryNext>
## Only usable: <$MTEntryPermalink$>, <$MTEntryTitle$> & <$MTEntryID$>

sub new {
    my $class = shift;
    my($link) = @_;
    bless { link => $link }, $class;
}

sub title {
    $_[0]->{link}->title;
}

sub id {
    ## XXX: use atom:id?
    ($_[0]->{link}->href =~ /entry_id=(\d+)/)[0];
}

sub created_on_obj { }
sub allow_comments { 1 }
sub allow_pings    { 0 }
sub comment_status { 1 }
sub text           { }
sub text_more      { }

1;
