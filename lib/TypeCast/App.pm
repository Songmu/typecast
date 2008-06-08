# $Id$
package TypeCast::App;
use strict;
use warnings;

use base qw( MT::App );

use HTTP::Status;
use Encode::JP::Mobile;
use List::Util qw( first );
use Error qw( :try );

use MT::DateTime;
use MT::Category;
use MT::Util qw( decode_url remove_html encode_url );
use MT::Memcached;

use TypeCast::Util;
use TypeCast::ContentFilter;
use TypeCast::Template::Context;
use TypeCast::Remote::Blog;
use TypeCast::Remote::Entry;
use TypeCast::Remote::Comment;
use TypeCast::Cache;

use constant NS_TYPEPAD => 'http://sixapart.com/atom/typepad#';

sub default_encoding {
    my $app = shift;
    $app->{content_filter} ? ($app->{content_filter}->input_encoding || 'utf-8') : 'utf-8';
}

sub id { 'typecast' }

sub entries_per_page  { shift->config->TCEntriesPerPage  || 20 }
sub comments_per_page { shift->config->TCCommentsPerPage || 20 }
sub api_path          { shift->config->TCAtomServerURL }

sub init {
    my $app = shift;
    $app->SUPER::init(@_) or return;
    $app->add_methods(
        main_index       => \&main_index,
        individual       => \&individual,
        list_comments    => \&list_comments,
#         'recent_comments'  => \&recent_comments,
#         'handle_comment'   => \&handle_comment,
#         'about'            => \&about,
#         'thumbnail'        => \&thumbnail,
#         'show_image'       => \&show_image,
        'redirect_confirm' => \&redirect_confirm,
        'mld'              => \&mld,
#         'category'         => \&category,
    );
    $app->{template_dir}   = 'typecast';
    $app->{plugin_template_path} = '';
    $app->{requires_login} = 0;
    $app->{is_admin}       = 0;
    $app->{content_filter} = TypeCast::ContentFilter->new($app->get_header('User-Agent'));

    if (my $url = $app->{query}->param('url')) {
        my($blog_id, $entry_id) = $app->_discover_typecast_feed($url);
        if ($blog_id && $entry_id) {
            $app->{query}->param('__mode' => 'individual');
            $app->{query}->param('blog_id', $blog_id);
            $app->{query}->param('id', $entry_id);
        } elsif ($blog_id) {
            $app->{query}->param('blog_id', $blog_id);
        }
    }

    $app;
}

sub init_request {
    my $app = shift;
    $app->SUPER::init_request(@_);
    $app->{default_mode} = 'main_index';
}

# sub run {
#     my $app = shift;

#     $Error::Debug = 1;
#     local *MT::current_app = sub { $app };

#     try {
#         $app->setup   or die $app->errstr;
#         $app->pre_run or die $app->errstr;
#         $app->encode_incoming_params;

#         ## Add current_app method so any plugin can access $app
#         my $mode = $app->{no_read_body} ? $app->{default_mode} :
#                    $app->mode || $app->{default_mode};

#         my $code = $app->{vtbl}{$mode}
#             or throw TypeCast::Error::NotFound("Unknown action $mode");
#         my $out = $code->($app);

#         ## filtering for each mobile browsers
#         $app->rewrite_content(\$out);
#         $app->{response_body} = $out;

#         $app->post_run or die $app->errstr;

#         ## We must either have content or a redirect. Die otherwise.
#         die $app->errstr
#             unless defined $app->{response_body} or $app->{redirect};
#     }
#     otherwise {
#         my $err = shift;
#         $app->log($err, 'error');

#         my $out = $app->show_error($err);
#         $app->rewrite_content(\$out);
#         $app->{response_body} = $out;

#         ## Establish the proper response code
#         my $rc = $app->response_code || RC_INTERNAL_SERVER_ERROR;
#         $app->response_code($rc);
#     };

#     ## Send this data to the client
#     $app->send_response_body;
# }

# sub base {
#     my $app = shift;
#     my $base = $app->SUPER::base();
#     my $portal = TypePad->current_portal;
#     require URI;
#     my $uri = URI->new($base);
#     $uri->host($portal->conf->{typecast}{hostname});
#     $uri->as_string;
# }

sub build_context {
    my $app = shift;
    my $q   = $app->{query};
    my ($blog, $entry) = @_;

    my $ctx = TypeCast::Template::Context->new;
#    $ctx->stash(emoticon_handler => $app->{content_filter}->{emoticon});
    return $ctx unless $blog;

    my $user_id = $q->param('user_id') || 0;
    $blog->user_id($user_id);
    if ($entry) {
        $entry->user_id($user_id);
        $ctx->stash_many(entry => $entry, enclosures => $entry->enclosures);
        $ctx->{current_timestamp} = $entry->created_on_obj;
    }
    else {
        $ctx->stash(entries => $blog->entries);
    }

    $ctx->stash_many(
        blog_id => $blog->id,
        blog    => $blog,
#        user    => $blog->owner,
#        user_id => $user_id,
        required_query => 'blog_id=' . $blog->id,# . '&user_id=' . $user_id,
    );

    ## Set current_user for timezone in Templates
#    MT->current_user($blog->owner) if $blog && $blog->owner;
    MT->set_language($blog->date_language);
    $ctx;
}

sub build_page {
    my $app = shift;
    my ($file, $ctx, $extra_hdlr) = @_;

    my %cond;
    if (my $entry = $ctx->stash('entry')) {
        %cond = (
            EntryIfExtended      => $entry->text_more ? 1 : 0,
            EntryIfAllowComments => $entry->comment_status,
            EntryIfAllowPings    => $entry->allow_pings,
        );
    }

    # XXX: hack to get correct template paths
    __PACKAGE__->set_instance($app);

    my $tmpl = $app->load_tmpl($file);
    $tmpl->context($ctx);
    my $html = $tmpl->build($ctx, \%cond);
    $html = $tmpl->errstr unless defined $html;
    $html = $app->translate_templatized($html);

    $app->rewrite_content(\$html);

    return $html;
}

sub rewrite_content {
    my $app = shift;
    my $out_ref = shift or die;

    my $filter = $app->{content_filter};
    $filter->rewrite_content($out_ref);
    $app->response_content_type($filter->content_type);
    $app->{charset} = $filter->encoding;
}

sub main_index {
    my $app = shift;

    my $q       = $app->{query};
    my $blog_id = $q->param('blog_id');
    my $page    = $q->param('page') || 1;

    my $blog = $app->_fetch_blog($blog_id, $page)
        or throw TypeCast::Error::NotFound;
    my $ctx = $app->build_context($blog);
    $ctx->stash(page => $page);

    return $app->build_page('main_index.tmpl', $ctx);
}

sub individual {
    my $app = shift;

    my $q        = $app->{query};
    my $blog_id  = $q->param('blog_id');
    my $entry_id = $q->param('entry_id');
    my $page     = $q->param('page') || 1;

    my $blog = $app->_fetch_blog($blog_id, 1)
        or throw TypeCast::Error::NotFound;
    my $entry = $app->_fetch_entry($blog, $entry_id)
        or throw TypeCast::Error::NotFound;
    my $ctx = $app->build_context($blog, $entry);
    $ctx->stash(page => $page);

    return $app->build_page('individual.tmpl', $ctx);
}

sub list_comments {
    my $app = shift;
    my $q = $app->{query};

    my $blog_id  = $q->param('blog_id');
    my $entry_id = $q->param('entry_id');
    my $page     = $q->param('page') || 1;
    my $reload   = $q->param('reload') || 0;
    my $user_id  = $q->param('user_id') || 0;

    my $blog  = $app->_fetch_blog($blog_id, 1)
        or throw TypeCast::Error::NotFound;
    my $entry = $app->_fetch_entry($blog, $entry_id, { reload => $reload })
        or throw TypeCast::Error::NotFound;
    my $comments = $app->_fetch_comments($blog, $entry, $page, { reload => $reload })
        or throw TypeCast::Error::NotFound;
    $entry->set_comments($comments->comments);

    my $ctx = $app->build_context($blog, $entry, $comments);

    $ctx->stash_many(
        page     => $page,
        limit    => $app->comments_per_page,
        comments => $comments,
    );

    $app->build_page('list_comments.tmpl', $ctx);
}

# sub recent_comments {
#     my $app = shift;
#     my $q   = $app->{query};
#     my $blog_id  = $q->param('blog_id');
#     my $user_id  = $q->param('user_id') || 0;

#     my $blog = $app->_fetch_blog($blog_id, 1, $user_id)
#         or throw TypeCast::Error::NotFound;
#     my $comments = $app->_fetch_blog_comments($blog, $user_id)
#         or throw TypeCast::Error::NotFound;
#     my $ctx = $app->build_context($blog);

#     $ctx->stash(limit    => $app->comments_per_page);
#     $ctx->stash(comments => $comments);

#     $app->build_page('recent_comments.tmpl', $ctx);
# }

# sub handle_comment {
#     my $app = shift;
#     my $q = $app->{query};
#     if ($q->param('preview')) {
#         return $app->preview_post_comment;
#     } else {
#         return $app->post_comment;
#     }
# }

# sub preview_post_comment {
#     my $app = shift;
#     my($err) = @_;
#     my $q = $app->{query};

#     my $blog_id  = $q->param('blog_id');
#     my $entry_id = $q->param('entry_id');
#     my $user_id  = $q->param('user_id') || 0;

#     my $blog  = $app->_fetch_blog($blog_id, 1, $user_id)
#         or throw TypeCast::Error::NotFound;
#     my $entry = $app->_fetch_entry($blog, $entry_id, $user_id)
#         or throw TypeCast::Error::NotFound;

#     ## TODO: support real preview (convert_paras_comments)
#     my $comment = TypeCast::Remote::Comment->new;
#     my $now     = MT::Date->new;
#     $comment->set_values(
#         (map{ $_ => defined $q->param('comment-'.$_) 
#                     ? $q->param('comment-'.$_)
#                     : '' } qw(author email url text)),
#         created_on => $now->ts_utc,
#     );

#     my $ctx = $app->build_context($blog, $entry);
#     $ctx->{current_timestamp} = $now;
#     $ctx->stash(comment_preview => $comment);
#     $ctx->stash(error_message => $err) if $err;
#     $app->build_page('preview_comment.tmpl', $ctx);
# }

# sub post_comment {
#     my $app = shift;
#     my $q = $app->{query};

#     $app->_is_good_ip or return $app->preview_post_comment($app->translate('You are not allowed to post comments from mobile phones.'));

#     my $blog_id  = $q->param('blog_id');
#     my $entry_id = $q->param('entry_id');
#     my $user_id  = $q->param('user_id') || 0;

#     my $blog  = $app->_fetch_blog($blog_id, 1, $user_id)
#         or throw TypeCast::Error::NotFound;
#     my $entry = $app->_fetch_entry($blog, $entry_id, $user_id)
#         or throw TypeCast::Error::NotFound;

#     my $text = $q->param('comment-text');
#     if (TypePad->current_portal->conf->{use_emoticon}) {
#         require TypePad::Emoticon::InputFilter;
#         my $filter = TypePad::Emoticon::InputFilter->new;
#         $filter->filter($text);
#         $q->param('comment-text', $text);
#     }

#     ## find duplicated comment
#     if ($entry->comment_count) {
#         my $comments = $app->_fetch_comments($blog, $entry, 1, $user_id, { nocache => 1 })
#             or throw TypeCast::Error::NotFound;
#         my $author = $q->param('comment-author') or '';
#         $text =~ tr/ \r\n//d;
#         for my $comment (@{ $comments->comments }) {
#             (my $t = remove_html($comment->text)) =~ tr/ \r\n//d;
#             next if $t ne $text;
#             next if ($comment->author or '') ne $author;
#             return $app->redirect($app->base . $app->uri . "/$blog_id/$user_id/$entry_id/list_comments?reload=1");
#         }
#     }

#     require HTTP::Request::Common;
#     my $url = TypePad->CGIPath . "comments";
#     my $req = HTTP::Request::Common::POST($url, [
#         entry_id => $entry_id,
#         user_id  => $user_id,
#         (map{ $_ => defined $q->param('comment-'.$_) 
#                     ? $q->param('comment-'.$_)
#                     : '' } qw(author email url text)),
#         post    => 1,
#     ]);
#     my $ua  = MT->new_ua;
#     my $res = $ua->simple_request($req);
#     if ($res->is_redirect) {
#         ## 302 redirection means success
#         $app->redirect($app->base . $app->uri . "/$blog_id/$user_id/$entry_id/list_comments?reload=1");
#     } else {
#         ## XXX This is ugly way to extract error message
#         my $error = $res->content;
#         $app->preview_post_comment($error);
#     }
# }

# sub about {
#     my $app = shift;

#     my $q = $app->{query};
#     my $blog_id = $q->param('blog_id');
#     my $user_id = $q->param('user_id') || 0;

#     my $blog = $app->_fetch_blog($blog_id, 1, $user_id)
#         or throw TypeCast::Error::NotFound;

#     delete $blog->{__owner}; #delete cache memory

#     throw TypeCast::Error::NotFound("No about page available.")
#         unless $blog->owner && $blog->owner->person;

#     my $ctx = $app->build_context($blog);
#     $app->build_page('about.tmpl', $ctx);
# }

# sub thumbnail {
#     return shift->show_image(size => 50);
# }

# sub show_image {
#     my $app   = shift;
#     my %param = @_;
#     my $q     = $app->{query};

#     my $blog = $app->_fetch_blog($q->param('blog_id'), 1, $q->param('user_id'))
#         or throw TypeCast::Error::NotFound;

#     my $src = $q->param('src') or throw TypeCast::Error::NotFound;
#     my $req = HTTP::Request->new(GET => $src);
#     if (my $modified_date = $app->get_header('If-Modified-Since')) {
#         $req->header('If-Modified-Since' => $modified_date);
#     }
#     if (my $cred = $app->get_header('Authorization')) {
#         $req->header('Authorization' => $cred);
#     }
#     my $res = MT->new_ua->request($req);
#     if ($res->code != RC_OK) {
#         if ($res->code == RC_NOT_MODIFIED) {
#             $app->expires($res->freshness_lifetime);
#         }
#         return $app->response_code($res->code);
#     }
#     if ($res->header('Content-Type') !~ m{^image/}) {
#         return $app->response_code(RC_BAD_GATEWAY);
#     }

#     require MT::Image;
#     my $im = MT::Image->new(Data => $res->content);
#     return $app->response_code(RC_BAD_GATEWAY) if !$im;

#     ## strip image of all profiles and comments
#     $im->strip;

#     my $image;
#     if ($param{size}) {
#         $app->_optimize_image_format($im);
#         $image = $app->_optimize_image_scale($im, $param{size}, $param{size});
#     }
#     else {
#         $app->_optimize_image_format($im);
#         $app->_optimize_image_scale($im);
#         $image = $im->compress($app->_get_cache_size)->data;
#     }
#     return $app->response_code(RC_BAD_GATEWAY) if !$image;

#     $app->{no_print_body} = 1;
#     $app->set_header('Content-Length' => length $image);
#     if (my $last_modified = $res->header('Last-Modified')) {
#         $app->set_header('Last-Modified' => $last_modified);
#     }
#     $app->send_http_header($im->mime_type);
#     $app->print($image);

#     return $app;
# }

sub redirect_confirm {
    my $app = shift;
    my $q   = $app->{query};

    my $url = $q->param('exturl')
        or throw TypeCast::Error::BadRequest;

    if (my $mobile_url = TypeCast::Util::discover_mobile_link($url)) {
        $app->redirect($mobile_url);
        return 0;
    }

    my $blog = $app->_fetch_blog($q->param('blog_id'))
        or throw TypeCast::Error::NotFound;
    my $ctx = $app->build_context($blog);
    $ctx->stash(redirect_url => $url);
    return $app->build_page('redirect_confirm.tmpl', $ctx);
}

# sub category {
#     my $app = shift;

#     my $q       = $app->{query};
#     my $blog_id = $q->param('blog_id');
#     my $user_id = $q->param('user_id');
#     my $cat_id  = $q->param('id');
#     my $page    = $q->param('page') || 1;
#     my $blog    = $app->_fetch_blog($blog_id, $page, $user_id, { category => $cat_id })
#         or throw TypeCast::Error::NotFound;

#     ## listing entries limited by category
#     if ($cat_id) {
#         my $meta = $blog->atom->get(NS_TYPEPAD, 'archive_category');
#         my ($id, $label) = split /:/, $meta, 2;
#         my $cat = MT::Category->new;
#         $cat->id($id);
#         $cat->label($label);
#         my $ctx = $app->build_context($blog);
#         $ctx->stash_many(page => $page, archive_category => $cat);
#         return $app->build_page('category.tmpl', $ctx);
#     }

#     ## listing categories
#     # create XML document from atom
#     my $doc;
#     my $cache = $app->{cache};
#     if ($cache) {
#         my $xml = $cache->atom_category($cat_id);
#         $doc = XML::LibXML->new->parse_string($xml) if $xml;
#     }
#     unless ($doc) {
#         my $uri = $app->api_path . "/weblog/svc=categories/blog_id=$blog_id";
#         $uri .= "/user_id=$user_id" if $user_id;
#         $uri = $app->_append_apikey($uri);
#         my $atom = $app->_get_atom_feed({ uri => $uri })
#             or return $app->error($app->_atom_client->errstr);
#         if ($atom && $cache) {
#             $cache->atom_category($cat_id, $atom);
#         }
#         $doc = XML::LibXML->new->parse_string($atom->as_xml);
#     }
#     $doc or throw TypeCast::Error::Fatal;

#     # create psuedo MTCategory object
#     my @categories;
#     for my $elem ($doc->getElementsByLocalName('subject')) {
#         my ($id, $label) = split /:/, $elem->textContent, 2;
#         my $cat = MT::Category->new;
#         $cat->id($id);
#         $cat->label($label);
#         push @categories, $cat;
#     }
#     my $ctx = $app->build_context($blog);
#     $ctx->stash(categories => \@categories);
#     $ctx->set_var(blog_has_categories => scalar @categories);
#     $app->build_page('list_categories.tmpl', $ctx);
# }

sub show_error {
    my ($app, $err) = @_;

    my $message;
    if (ref($err)) {
        $message = $err->text;
        if ($err->isa('TypeCast::Error::Unauthorized')) {
            $message ||= "Not available to mobile users.";
            $app->response_code('403');
        }
        elsif ($err->isa('TypeCast::Error::NotFound')) {
            $message ||= "The request URL was not found.";
            $app->response_code('404');
        }
        elsif ($err->isa('TypeCast::Error::Authentication')) {
            $message = "Authorization Required.";
            $app->set_header('WWW-Authenticate' => 'Basic realm="Protected"');
            $app->response_code('401');
        }
        elsif ($err->isa('TypeCast::Error::BadRequest')) {
            $message ||= "Bad Request.";
            $app->response_code('400');
        }
        else {
            warn $err->stacktrace if $err->stacktrace;
        }
    }
    unless ($message) {
        $message = $app->errstr || "An error occurred...";
        $app->response_code('500');
    }

    my $ctx = TypeCast::Template::Context->new;
    $ctx->stash(error_message => MT->translate($message));
    $app->build_page('handle_error.tmpl', $ctx);
}

sub _is_good_ip {
    my $app = shift;

    my $file = $app->find_config({ Config => 'conf/mobile_gateway.yaml' });

    my $memcache     = MT::Memcached->instance;
    my $memcache_key = join ':', 'typecast', $file, (stat($file))[9];

    my $cfg;
    unless ($memcache and $cfg = $memcache->get($memcache_key)) {
        require YAML;
        $cfg = YAML::LoadFile($file);
        $memcache->add($memcache_key, $cfg, 60 * 60 * 24) if $memcache;
    }
    $cfg ||= {};

    my $ua = $app->get_header('User-Agent');
    my $allow_ip_ref = [];
    my $allow_domain_ref;
FIND_CARRIER:
    for my $carrier (keys %$cfg) {
        for my $ptn (@{$cfg->{$carrier}{ua_regexp}}) {
            if ($ua =~ m/$ptn/) {
                $allow_ip_ref     = $cfg->{$carrier}{ip};
                $allow_domain_ref = $cfg->{$carrier}{domain};
                last FIND_CARRIER;
            }
        }
    }

    return TypeCast::Util::match_ip($app->remote_ip, $allow_ip_ref)
        || TypeCast::Util::match_ip_domain($app->remote_ip, $allow_domain_ref);
}

sub _optimize_image_scale {
    my $app   = shift;
    my $image = shift;
    my ($want_width, $want_height) = @_ ? @_ : $app->_get_device_size();

    ## If width and height both smaller than device capacity, that's fine
    if ($image->{width} <= $want_width && $image->{height} <= $want_height) {
        return $image->data;
    }

    ## Try width first, then height
    my ($img, $w, $h) = $image->scale(Width => $want_width);
    $img = $image->scale(Height => $want_height) if $h > $want_height;
    $img;
}

sub _optimize_image_format {
    my $app = shift;
    my ($image) = @_;

    if ($app->get_header('User-Agent') =~ /^DoCoMo/) {
        return $image->convert_format('gif') if $image->mime_type eq 'image/png';
    }
    else {
        return $image->convert_format('png') if $image->mime_type eq 'image/gif';
    }
}

sub _get_device_size {
    my $app = shift;
    my ($x, $y) = $app->_agent_spec->get_device_size;
    return (96, 72) if !$x || !$y;
    return ($x, $y);
}

sub _get_cache_size {
    my $app = shift;
    return $app->_agent_spec->get_cache_size;
}

sub _construct_feed {
    my $app     = shift;
    my $blog_id = shift || return;
    my ($entry_id, $page, $term) = @_;

    my $limit = $app->entries_per_page;

    my $uri = $app->api_path . "/weblog/blog_id=$blog_id";
    $uri .= "/entry_id=$entry_id" if $entry_id;
    $uri .= "/limit=$limit";
    $uri .= "/offset=" . ($page - 1) * $limit if $page;
    if ($term) {
        while (my ($k, $v) = each %$term) {
            $uri .= "/$k=". encode_url($v) if $k && $v;
        }
    }
    return $uri;
}

sub _comments_feed {
    my $app     = shift;
    my $blog_id = shift || return;
    my ($entry_id, $page) = @_;

    my $limit = $app->comments_per_page;

    my $uri = $app->api_path . "/comments/blog_id=$blog_id";
    $uri .= "/entry_id=$entry_id" if $entry_id;
    $uri .= "/limit=$limit";
    $uri .= "/offset=" . ($page - 1) * $limit if $page && $page > 0;
    return $uri;
}

sub _fetch_blog {
    my $app = shift;
    my ($blog_id, $page, $user_id, $term) = @_;

    my $atom;
    my $cache = $app->{cache};
    if ($cache) {
        my $xml = ($term && $term->{category})
                ? $cache->atom_category_archive($term->{category}, $page)
                : $cache->atom_blog($page)
                ;
        $atom = XML::Atom::Feed->new(\$xml) if $xml;
    }

    unless ($atom) {
        my $uri = $app->_construct_feed($blog_id, undef, $page, $term);
        $atom = $app->_get_atom_feed({ uri => $uri });
        if ($atom && $cache) {
            ($term && $term->{category})
                ? $cache->atom_category_archive($term->{category}, $page, $atom)
                : $cache->atom_blog($page, $atom)
                ;
        }
    }

    return TypeCast::Remote::Blog->new_from_atom($atom);
}

sub _fetch_entry {
    my $app = shift;
    my ($blog, $entry_id, $term) = @_;

    my $atom;
    my $cache = $app->{cache};
    if ($cache && !($term && $term->{reload})) {
        my $xml = $cache->atom_entry($entry_id);
        $atom = XML::Atom::Entry->new(\$xml) if $xml;
    }

    unless ($atom) {
        my $uri = $app->_construct_feed($blog->id, $entry_id, undef)
            or return $app->error('No blog_id or entry_id found.');
        $atom = $app->_get_atom_entry({ uri => $uri })
            or return $app->error($app->_atom_client->errstr);
        if ($atom && $cache) {
            $cache->atom_entry($entry_id, $atom)
        }
    }

    return TypeCast::Remote::Entry->new_from_atom($atom, $blog);
}

sub _fetch_comments {
    my $app = shift;
    my ($blog, $entry, $page, $term) = @_;
    $term ||= {};

    my $atom;
    my $cache = $app->{cache};
    if ($cache && !$term->{reload}) {
        my $xml = $cache->atom_entry_comments($entry->id, $page);
        $atom = XML::Atom::Feed->new(\$xml) if $xml;
    }

    unless ($atom) {
        my $uri = $app->_comments_feed($blog->id, $entry->id, $page)
           or return $app->error("No blog_id or entry_id found.");
        $atom = $app->_get_atom_feed({ uri => $uri })
            or return $app->error($app->_atom_client->errstr);
        if ($atom && $cache && !$term->{nocache}) {
            $cache->atom_entry_comments($entry->id, $page, $atom);
        }
    }

    return TypeCast::Remote::Comments->new($entry, $atom);
}

sub _fetch_blog_comments {
    my $app = shift;
    my ($blog, $user_id, $limit) = @_;

    my $atom;
    my $cache = $app->{cache};
    if ($cache) {
        my $xml = $cache->atom_recent_comments;
        $atom = XML::Atom::Feed->new(\$xml) if $xml;
    }

    unless ($atom) {
        my $uri = $app->_comments_feed($blog->id, 0, 0, $limit)
            or return $app->error("No blog_id found.");
        $atom = $app->_get_atom_feed({ uri => $uri })
            or return $app->error($app->_atom_client->errstr);
        if ($atom && $cache) {
            $cache->atom_recent_comments($atom);
        }
    }
    return TypeCast::Remote::Comments->new(undef, $atom, $blog);
}

sub _get_atom_feed  { shift->_get_atom('getFeed', @_); }
sub _get_atom_entry { shift->_get_atom('getEntry', @_); }

sub _get_atom {
    my $app = shift;
    my ($meth, $param) = @_;

    my $uri = $param->{uri} or return;

    ## retry to get Atom when XML(Atom) couldn't parsed,
    ## because libxml2 rarely made broken xml.
    my $atom;
    for (1..2) {
        eval { $atom = $app->_atom_client->$meth($uri); };
        $@ ? warn $@ : last;
    }
    return $atom if $atom;

    my ($code) = $app->_atom_client->errstr =~ m{^Error on GET \S+ (\d{3})};
    throw TypeCast::Error::Authentication if $code eq '401';
    return $app->error($app->_atom_client->errstr);
}

sub _discover_typecast_feed {
    my $app = shift;
    my($url) = @_;

    ## TODO: move to WWW::Blog::Metadata or Feed::Find?
    my $ua  = MT->new_ua;
    my $feed_uri;
    my $content = $ua->get($url)->content; ## TODO: support chunk based to save memory
    require HTML::TokeParser;
    my $p = HTML::TokeParser->new(\$content);
    while (my $token = $p->get_tag('link')) {
        my $rel = $token->[1]{rel};
        if ($rel =~ /typecast\.feed/) {
            $feed_uri = $token->[1]{href};
            last;
        }
    }

    $feed_uri =~ m!/blog_id=(\d+)/entry_id=(\d+)! and return ($1, $2);
    $feed_uri =~ m!/blog_id=(\d+)! and return ($1);
    return $app->error("No blog_id found on typecast.feed discovery");
}

sub mld {
    my $app = shift;
    my $q   = $app->{query};
    my $url = $q->param('url');

    my ($cache, $cache_key);
    if (MT::Memcached->is_available) {
        $cache     = MT::Memcached->instance;
        $cache_key = "typecast:mld:$url";
        if (my $mobile_url = $cache->get($cache_key)) {
            $app->redirect($mobile_url);
            return 0;
        }
    }

    my $mobile_url = TypeCast::Util::discover_mobile_link($url)
        or throw TypeCast::Error::NotFound;

    if ($cache) {
        $cache->set($cache_key => $mobile_url, 24*60*60);
    }

    $app->redirect($mobile_url);
    return 0;
}

# sub pre_run {
#     my $app = shift;
#     $app->SUPER::pre_run(@_);

#     my $q = $app->{query};

#     ## parse path_info to get parameters
#     ##   /<blog_id>/<user_id>/<resource>/<action>
#     ## resource:
#     ##   entry_id, recent_comment, show_image, profile, category
#     ## action:
#     ##   list_comments, handle_comments, filename, category_id
#     ##
#     my $path_info = $app->path_info;
#     if ($path_info && $path_info !~ m{^/?(?:[^/]+)?$}) {
#         my ($dm, $blog_id, $user_id, $resource, $action) = split '/', $path_info;

#         $q->param(blog_id => $blog_id) if defined $blog_id;
#         $q->param(user_id => $user_id) if defined $user_id;

#         unless ($resource) {
#             $resource = 'main_index';
#         }
#         elsif ($resource !~ m{^\d+$}) {
#             $q->param(id => $action || '');
#         }
#         elsif ($action) { ## 'list_comments' mode only
#             $q->param(entry_id => $resource);
#             $resource = 'list_comments';
#         }
#         else {
#             $q->param(id => $resource);
#             $resource = 'individual';
#         }
#         $q->param('__mode' => $resource);
#         $app->mode($resource);
#     }

#     return 1 if ($q->param('__mode')||'') eq 'mld';

#     ## common validation of query parameters
#     my $blog_id = $q->param('blog_id');
#     throw TypeCast::Error::NotFound("The photo album can't view from mobile.")
#         if defined $q->param('set_id');
#     throw TypeCast::Error::NotFound
#         if !defined $blog_id or $blog_id <= 0;
#     throw TypeCast::Error::NotFound
#         if defined $q->param('user_id') && $q->param('user_id') < 0;

#     ## create instance of cache object for caching atom/html.
#     if ($blog_id) {
#         $app->{cache} = TypeCast::Cache->new($blog_id);
#     }

#     $app->{breadcrumbs} = [];
#     MT->run_callbacks((ref $app) . '::pre_run', $app);
#     1;
# }

sub expires {
    my ($app, $exp) = @_;
    return $app->{__expires} unless defined $exp;
    return $app->{__expires} = $exp;
}

sub _atom_client {
    my $app = shift;
    return $app->{__atom_client} if $app->{__atom_client};

    require XML::Atom::Client;
    require TypeCast;

    my $client = XML::Atom::Client->new;
    $client->username($app->config->TCAtomAPIUsername);
    $client->password($app->config->TCAtomAPIPassword);
    $client->{ua}->agent('TypeCast/' . TypeCast->VERSION);
    ## handling basic authentication
    my $cred = $app->get_header('Authorization');
    if ($cred && $cred =~ m{^Basic }) {
        $client->{ua}->default_header('X-TC-Authorization' => $cred);
    }

    return $app->{__atom_client} = $client;
}

sub _agent_spec {
    my $app = shift;
    require TypeCast::AgentSpec;
    $app->{__agent_spec} ||= TypeCast::AgentSpec->new($app->{query});
}

{
    no warnings 'redefine';
    *MT::ConfigMgr::read_config_db = sub { };
    *MT::ConfigMgr::save_config    = sub { };
    *MT::init_config_from_db       = sub { 1 };
}

1;
