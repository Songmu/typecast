# $Id$
package TypeCast::Atom::Blog;
use strict;
use base qw( TypeCast::Atom );

sub atom_type { 'weblog' }

sub date_language {
    "en_us"; # XXX
}

sub name {
    $_[0]->atom->title;
}

sub description {
    $_[0]->atom->tagline;
}

sub site_url {
    my $blog = shift;
    unless ($blog->{__site_url}) {
        ## find link rel="alternate" type="text/html"
        for my $link ($blog->atom->link) {
            if ($link->rel eq 'alternate' && $link->type eq 'text/html') {
                $blog->{__site_url} = $link->href;
                last;
            }
        }
    }
    $blog->{__site_url};
}

sub words_in_excerpt { 40 }

sub sort_order_comments { 'descend' }

sub allow_comment_html { 1 }
sub convert_paras_comments { 1 }
sub comment_text_filters { [ ] }

sub sanitize_spec { 0 }

## not in MT::Blog though ...
sub entries {
    my $blog = shift;
    unless ($blog->{__entries}) {
        $blog->{__entries} =
            [ map TypeCast::Atom::Entry->new_from_atom($_, $blog), $blog->atom->entries ];
    }
    $blog->{__entries};
}

1;
