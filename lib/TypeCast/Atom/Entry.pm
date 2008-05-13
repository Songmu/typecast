# $Id$
package TypeCast::Atom::Entry;
use strict;
use warnings;

use base qw( TypeCast::Atom );

use Encode ();
use constant NS_DC    => 'http://purl.org/dc/elements/1.1/';

sub atom_type { 'post' }

sub init {
    my $entry = shift;
    my($atom, $blog) = @_;
    $entry->{__blog} = $blog;
    $entry;
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
        $entry->{__text} = $text;
    }
    $entry->{__text};
}

sub text_more { }

sub excerpt {
    $_[0]->atom->summary;
}

sub enclosures {
    my $entry = shift;
    my @link = grep { $_->rel eq 'enclosure' } $entry->atom->link;
    return \@link;
}

sub convert_breaks { 0 }

#sub text_filters { }

sub categories {
    my $entry = shift;
    unless (defined $entry->{__categories}) {
        my $atom = $entry->atom;
        my $dc = XML::Atom::Namespace->new(dc => NS_DC);
        my @subject = $atom->getlist($dc, 'subject');
        $entry->{__categories} = [ map {
            my $cat = MT::Category->new;
            $cat->blog_id($entry->blog->id);
            $cat->label($_);
            $cat;
        } @subject ];
    }
    $entry->{__categories};
}

sub created_on {
    my $entry = shift;
    unless (defined $entry->{__created_on}) {
        $entry->{__created_on} = MT::Date->parse_date($entry->atom->issued)->ts_utc;
    }
    $entry->{__created_on};
}

*created_on_obj = MT::Entry->can('created_on_obj');

sub _init_comments {
    my $entry = shift;
    for my $link ($entry->atom->link) {
        if ($link->rel eq 'entry.comments') {
            ## TODO: support $link->get($ns, $attr) in XML::Atom
            my $count = ($link->as_xml =~ /comment:count="(\d+)"/)[0] || 0;
            Encode::_utf8_off($count);
            $entry->{__comments_info} = {
                allow => 1,
                count => $count,
            };
            return;
        }
    }
    $entry->{__comments_info} = { allow => 0, count => 0 };
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
            $entry->{__neighbor}->{$link->rel} = TypeCast::Atom::Entry::Neighbor->new($link);
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

package TypeCast::Atom::Entry::Neighbor;

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
sub text_more      { }

1;
