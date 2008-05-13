# $Id$
package TypeCast::Plugin::ExtraHandlers;
use strict;
use warnings;

use List::Util qw( min );
use MT::Util qw( encode_url remove_html first_n_words );
use TypeCast::Template::Context;

TypeCast::Template::Context->add_tag(PublishCharset => \&PublishCharset);
TypeCast::Template::Context->add_tag(UserID => \&UserID);
TypeCast::Template::Context->add_tag(WeblogThemeMobileURL => \&WeblogThemeMobileURL);
TypeCast::Template::Context->add_tag(TypeCastCommentLink => \&TypeCastCommentLink);
TypeCast::Template::Context->add_tag(TypeCastCommentExcerpt => \&TypeCastCommentExcerpt);
TypeCast::Template::Context->add_tag(TypeCastAppURL => \&TypeCastAppURL);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfAboutPageDisplay => \&TypeCastIfAboutPageDisplay);
TypeCast::Template::Context->add_tag(TypeCastAboutPageLink => \&TypeCastAboutPageLink);
TypeCast::Template::Context->add_conditional_tag(EntryIfTypeCastEnclosures => \&EntryIfTypeCastEnclosures);
TypeCast::Template::Context->add_container_tag(EntryTypeCastEnclosures => \&EntryTypeCastEnclosures);
TypeCast::Template::Context->add_tag(EntryTypeCastEnclosureClass => \&EntryTypeCastEnclosureClass);
TypeCast::Template::Context->add_tag(EntryTypeCastEnclosureTitle => \&EntryTypeCastEnclosureTitle);
TypeCast::Template::Context->add_conditional_tag(EntryIfTypeCastEnclosureShowSize => \&EntryIfTypeCastEnclosureShowSize);
TypeCast::Template::Context->add_tag(EntryTypeCastEnclosureSize => \&EntryTypeCastEnclosureSize);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfPrevEntries => \&TypeCastIfPrevEntries);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfNextEntries => \&TypeCastIfNextEntries);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfPrevOrNextEntries => \&TypeCastIfPrevOrNextEntries);
TypeCast::Template::Context->add_tag(TypeCastPrevEntriesLink => \&TypeCastPrevEntriesLink);
TypeCast::Template::Context->add_tag(TypeCastNextEntriesLink => \&TypeCastNextEntriesLink);
TypeCast::Template::Context->add_tag(TypeCastCommentFrom => \&TypeCastCommentFrom);
TypeCast::Template::Context->add_tag(TypeCastCommentTo => \&TypeCastCommentTo);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfPrevComments => \&TypeCastIfPrevComments);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfNextComments => \&TypeCastIfNextComments);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfPrevOrNextComments => \&TypeCastIfPrevOrNextComments);
TypeCast::Template::Context->add_tag(TypeCastPrevCommentsLink => \&TypeCastPrevCommentsLink);
TypeCast::Template::Context->add_tag(TypeCastNextCommentsLink => \&TypeCastNextCommentsLink);
TypeCast::Template::Context->add_tag(UserEmail => \&UserEmail);
TypeCast::Template::Context->add_conditional_tag(TypeCastBlogIfPrivate => \&TypeCastBlogIfPrivate);
TypeCast::Template::Context->add_tag(TypeCastRedirectURL => \&TypeCastRedirectURL);
TypeCast::Template::Context->add_tag(TypeCastImageURL => \&TypeCastImageURL);
TypeCast::Template::Context->add_tag(TypeCastThumbnailURL => \&TypeCastThumbnailURL);
TypeCast::Template::Context->add_conditional_tag(TypeCastIfDisallowAnonComments => \&TypeCastIfDisallowAnonComments);
TypeCast::Template::Context->add_tag(ArchivePermaLink => \&ArchivePermaLink);

use constant NS_TYPEPAD => 'http://sixapart.com/atom/typepad#';

sub PublishCharset {
    my($ctx, $arg) = @_;
    my $app = MT->instance;
    $app->{charset};
}

sub UserID {
    return shift->stash('blog')->user_id || 0;
}

sub WeblogThemeMobileURL {
    my($ctx, $arg) = @_;
    my $url = $ctx->stash('blog')->site_url;
    $url . "styles-mobile.css";
}

sub TypeCastAppURL {
    my($ctx, $arg) = @_;
    my $app = MT->instance or return $ctx->error("No MT::App context");
    $app->base . $app->uri;
}

sub TypeCastIfAboutPageDisplay {
    my($ctx, $arg) = @_;
    defined $ctx->stash('user');
}

sub TypeCastAboutPageLink {
    my($ctx, $arg) = @_;
    my $app = MT->instance or return $ctx->error("No MT::App context");
    # TODO: use an asset ID
    $app->base . $app->uri . "?__mode=about&" . $ctx->stash('required_query');
}

sub TypeCastCommentLink {
    my ($ctx, $arg) = @_;
    my $entry = $ctx->stash('entry') || $ctx->stash('comment')->entry;
    my $app = MT->instance;
    return $app->uri
        . '?__mode=list_comments&blog_id=' . $ctx->stash('blog_id')
        . '&entry_id=' . $entry->id;
}

sub TypeCastCommentExcerpt {
    my ($ctx, $args) = @_;

    $args->{filter_emoticon} = $args->{remove_broken_emoticon} = 1;

    my ($excerpt, $is_cut) = first_n_words(remove_html($ctx->stash('comment')->text),
                                           $args->{words} || 40);
    $excerpt .= '...' if $is_cut;
    return $excerpt;
}

sub EntryIfTypeCastEnclosures {
    my ($ctx, $args, $cond) = @_;
    my $encl = $ctx->stash('enclosures');
    $encl = _filter_enclosures($encl, $args->{type}) if $args->{type};

    return $encl && scalar(@$encl) > 0;
}

sub EntryTypeCastEnclosures {
    my ($ctx, $args, $cond) = @_;
    my $encl = $ctx->stash('enclosures') or return '';
    $encl = _filter_enclosures($encl, $args->{type}) if $args->{type};

    my $builder = $ctx->stash('builder');
    my $tok = $ctx->stash('tokens');
    my $res = '';
    for my $link (@$encl) {
        local $ctx->{__stash}{enclosure} = $link;
        my $out = $builder->build($ctx, $tok, {});
        return $ctx->error($builder->errstr) unless defined $out;
        $res .= $out;
    }
    $res;
}

sub _filter_enclosures {
    my($encl, $type) = @_;
    my $cb = $type =~ s/^\!// ?
        sub { $_[0]->type !~ m!^$type/! } :
        sub { $_[0]->type =~ m!^$type/! } ;
    [ reverse( grep { $cb->($_) } @$encl ) ];
}

sub EntryTypeCastEnclosureClass {
    my ($ctx, $args) = @_;
    (split('/', $ctx->stash('enclosure')->type))[0] || '';
}

sub EntryTypeCastEnclosureTitle {
    my ($ctx, $args) = @_;
    my $title = $ctx->stash('enclosure')->title;
    return _url_filename($ctx->stash('enclosure')->href) unless $title;
    return $title;
}

sub _url_filename {
    my $url = shift;
    $url =~ s!^.*/!!;
    $url;
}

sub EntryIfTypeCastEnclosureShowSize {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('enclosure')->type !~ m!^image/!;
}

sub EntryTypeCastEnclosureSize {
    my($ctx, $args) = @_;
    return "unknown" unless defined $ctx->stash('enclosure');
    my $length = $ctx->stash('enclosure')->length or return "unknown";
    $length > 1024 * 1024 && return sprintf('%.1fM', $length / (1024 * 1024));
    $length > 1024        && return sprintf('%.1fK', $length / 1024);
    sprintf('%db', $length);
}

sub TypeCastIfPrevEntries {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('blog')->has_prev_entries ? 1 : 0;
}

sub TypeCastIfNextEntries {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('blog')->has_next_entries ? 1 : 0;
}

sub TypeCastIfPrevOrNextEntries {
    my($ctx, $args, $cond) = @_;
    my $blog = $ctx->stash('blog');
    ($blog->has_prev_entries || $blog->has_next_entries) ? 1 : 0;
}

sub TypeCastPrevEntriesLink {
    my ($ctx, $args) = @_;
    my $app = MT->instance;
    my @queries;
    my $mode = $app->mode;
    if ($app->mode ne 'main_index') {
        push @queries, '__mode=' . $app->mode;
    }
    push @queries, 'blog_id=' . $ctx->stash('blog_id');
    if (my $id = $app->{query}->param('id')) {
        push @queries, "id=$id";
    }
    if (my $page = $ctx->stash('page') - 1) {
        push @queries, "page=$page";
    }
    return $app->base . $app->uri . '?' . join('&', @queries);
}

sub TypeCastNextEntriesLink {
    my ($ctx, $args) = @_;
    my $app = MT->instance;
    my @queries;
    my $mode = $app->mode;
    if ($app->mode ne 'main_index') {
        push @queries, "__mode=$app->mode";
    }
    push @queries, 'blog_id=' . $ctx->stash('blog_id');
    if (my $id = $app->{query}->param('id')) {
        push @queries, "id=$id";
    }
    if (my $page = $ctx->stash('page') + 1) {
        push @queries, "page=$page";
    }
    return $app->base . $app->uri . '?' . join('&', @queries);
}

sub TypeCastCommentFrom {
    my($ctx, $args) = @_;
    min(($ctx->stash('page') - 1) * $ctx->stash('limit') + 1, $ctx->stash('entry')->comment_count);
}

sub TypeCastCommentTo {
    my($ctx, $args) = @_;
    min($ctx->stash('page') * $ctx->stash('limit'), $ctx->stash('entry')->comment_count);
}

sub TypeCastIfPrevComments {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('comments')->has_prev;
}

sub TypeCastIfNextComments {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('comments')->has_next;
}

sub TypeCastIfPrevOrNextComments {
    my($ctx, $args, $cond) = @_;
    $ctx->stash('comments')->has_prev || $ctx->stash('comments')->has_next;
}

sub TypeCastPrevCommentsLink {
    my($ctx, $args) = @_;
    my $app = MT->instance;
    my $uri = $app->base . $app->uri;
    $uri . '?__mode=list_comments&' . $ctx->stash('required_query') . '&entry_id=' . $ctx->stash('entry')->id . '&page=' . ($ctx->stash('page') - 1);
}

sub TypeCastNextCommentsLink {
    my($ctx, $args) = @_;
    my $app = MT->instance;
    my $uri = $app->base . $app->uri;
    $uri . '?__mode=list_comments&' . $ctx->stash('required_query') . '&entry_id=' . $ctx->stash('entry')->id . '&page=' . ($ctx->stash('page') + 1);
}

## Need to override this for mobile phones without JS
sub UserEmail {
    my($ctx, $args) = @_;
    my $user = $_[0]->stash('user') or return _no_user(@_);
    my $email = $user->email or return '';
    $email =~ s/\@/ at /; ## TODO: so portal can override this?
    $email;
}

sub TypeCastBlogIfPrivate {
    my $ctx = shift;
    return 0 if $ctx->stash('blog') && $ctx->stash('blog')->is_public;
    return 1;
}

sub TypeCastRedirectURL {
    my ($ctx, $arg) = @_;
    return $ctx->stash('redirect_url');
}

sub TypeCastImageURL {
    my ($ctx, $arg) = @_;

    my $file = TypeCast::Util::basename_of_url($arg->{src});
    my $app  = MT->instance;
    return $app->uri . '/'
        . join('/', $ctx->stash('blog_id'), $ctx->stash('user_id'), 'show_image', $file)
        . '?src=' . encode_url($arg->{src});
}

sub TypeCastThumbnailURL {
    my ($ctx, $arg) = @_;

    my $file = TypeCast::Util::basename_of_url($arg->{src});
    my $app  = MT->instance;
    return $app->uri . '/'
        . join('/', $ctx->stash('blog_id'), $ctx->stash('user_id'), 'thumbnail', $file)
        . '?src=' . encode_url($arg->{src});
}

sub TypeCastIfDisallowAnonComments {
    my ($ctx) = @_;
    my $blog = $ctx->stash('blog');
    return $blog->allow_anon_comments ? 0 : 1;
}

sub ArchivePermaLink {
    my ($ctx, $arg) = @_;

    return '' unless $ctx->stash('archive_category');

    my $blog = $ctx->stash('blog');
    return $blog->atom->get(NS_TYPEPAD, 'archive_category_url');
}

1;
