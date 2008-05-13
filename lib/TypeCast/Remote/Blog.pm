# $Id$
package TypeCast::Remote::Blog;
use strict;
use warnings;

use base qw( TypeCast::Remote );

use constant NS_DC      => "http://purl.org/dc/elements/1.1/";
use constant NS_POST    => 'http://sixapart.com/atom/post#';
use constant NS_TYPEPAD => 'http://sixapart.com/atom/typepad#';

use TypeCast::Remote::User;

sub atom_type { 'weblog' }

sub date_language {
    $_[0]->atom->get(NS_DC, "language") || 'ja';
}
*language = \&date_language;

sub name {
    $_[0]->atom->title;
}

sub description {
    $_[0]->atom->tagline;
}


sub init {
    my $blog = shift;
    $blog->__parse_links;
    $blog;
}

sub id {
    my $thing = shift;
    unless ($thing->{__id}) {
        ## TCOS:
        ## AtomAPI of MTOS 4.1 returns Atom without feed.id.
        ## so we need to try to get another way.
        for my $link ($thing->atom->link) {
            next unless $link->rel && $link->href;
            next if $link->rel ne 'service.post';
            $thing->{__id} = $link->href =~ /\bblog_id=(\d+)/;
            last if $thing->{__id};
        }
    }
    $thing->{__id};
}

sub site_url {
    my $blog = shift;
    $blog->{__site_url};
}

*archive_url = \&site_url;

sub links {
    my $blog = shift;
    $blog->__parse_links;
    $blog->{__links};
}

sub __parse_links {
    my $blog = shift;
    unless ($blog->{__links}) {
        for my $link ($blog->atom->link) {
            $blog->{__links}->{$link->rel, $link->type} = $link;
        }

        ## site_url is link with rel="alternate" type="text/html"
        my $html_link = $blog->{__links}->{"alternate","text/html"};
        $blog->{__site_url} = $html_link->href if $html_link;

        ## fetch foaf address
        ## TODO: FOAF address should be taken from weblog HTML along with CSS
        my $foaf_link = $blog->{__links}->{"meta", "application/rdf+xml"};
        $blog->{__foaf_url} = $foaf_link->href if $foaf_link && $foaf_link->title eq 'FOAF';
    }
}

sub owner {
    my $blog = shift;
    unless (exists $blog->{__owner}) {
        if ($blog->{__foaf_url}) {
            my $req = HTTP::Request->new(GET => $blog->{__foaf_url});
            if (my $cred = MT->current_app->get_header('Authorization')) {
                $req->header('Authorization' => $cred);
            }
            my $res = MT->new_ua->request($req);
            if ($res->is_success and (my $data = $res->content)) {
                my $foaf = XML::FOAF->new(\$data, $blog->{__foaf_url});
                $blog->{__owner} = TypeCast::Remote::User->new_from_foaf($foaf, $blog);
            }
        }
        unless (defined $blog->{__owner}) {
            # set dummy user as owner
            $blog->{__owner} = TypeCast::Remote::User->new_from_foaf(undef, $blog);
        }
    }
    $blog->{__owner};
}

sub words_in_excerpt { 40 }

sub sort_order_comments { 'descend' }

sub allow_comment_html { 1 }

sub convert_paras {
    $_[0]->atom->get(NS_POST, "convertLineBreaks") eq 'true';
}

sub is_public {
    $_[0]->atom->get(NS_TYPEPAD, 'is_public') eq 'true';
}

sub allow_anon_comments {
    $_[0]->atom->get(NS_TYPEPAD, 'allow_anon_comments');
}

sub is_password_protected {
    $_[0]->atom->get(NS_TYPEPAD, 'is_password_protected');
}

sub convert_paras_comments { 1 }
sub comment_text_filters { [ '__default__' ] }

sub sanitize_spec { 0 }

## methods below are for TypeCast template tags

sub entries {
    my $blog = shift;
    unless ($blog->{__entries}) {
        $blog->{__entries} =
            [ map TypeCast::Remote::Entry->new_from_atom($_, $blog), $blog->atom->entries ];
    }
    $blog->{__entries};
}

sub has_prev_entries {
    my $blog = shift;
    exists $blog->{__links}->{"prev", "application/x.atom+xml"} ||
        exists $blog->{__links}->{"prev", "application/atom+xml"};
}
sub has_next_entries {
    my $blog = shift;
    exists $blog->{__links}->{"next", "application/x.atom+xml"} ||
        exists $blog->{__links}->{"next", "application/atom+xml"};
}

sub meta {}

sub archive_type { shift->atom->get(NS_TYPEPAD, 'archive_type') }

sub is_dynamic { 0 };

## for TCOS
sub accepts_comments { 1 }
sub allow_comments  { 1 }
sub nofollow_urls { 0 }
sub autolink_urls { 0 }

1;
