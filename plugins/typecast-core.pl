# $Id$
package TypeCast::Plugin::CoreHandlers;
use strict;
use warnings;

use Storable;
use URI;
use HTML::Parser;
use HTML::Split;

use MT::Util qw( encode_url first_n_words );

use TypeCast::Template::Context;

TypeCast::Template::Context->add_container_tag(Entries => \&_hdlr_entries);
TypeCast::Template::Context->add_tag(EntryPermalink => \&_hdlr_entry_permalink);
TypeCast::Template::Context->add_tag(BlogURL => \&_hdlr_blog_url);
TypeCast::Template::Context->add_container_tag(Comments => \&_hdlr_comments);
TypeCast::Template::Context->add_tag(EntryBody => \&_hdlr_entry_body);

sub _hdlr_entries {
    my ($ctx, $orig_args, $cond) = @_;
    my $entries = $ctx->stash('entries') or return '';
    my $args    = Storable::dclone($orig_args);

    my @list;
    if (%$args) {
        my $n = $args->{lastn};
        ## If lastn is defined, we need to make sure that the list of
        ## entries is in descending order.
        if ($n) {
            @$entries = sort { $b->created_on cmp $a->created_on || $b->id <=> $a->id } @$entries;
        }
        my $off = $args->{offset} || 0;
        my($i, $j) = (0, 0);
        for my $e (@$entries) {
            next if $off && $j++ < $off;
            last if $n && $i >= $n;
            push @list, $e;
            $i++;
        }
    }

    my $html    = '';
    my $i       = 0;
    my $vars    = $ctx->{__stash}{vars} ||= {};
    my $token   = $ctx->stash('tokens');
    my $builder = $ctx->stash('builder');
    for my $e (@$entries) {
        local $vars->{__odd__}     = ($i % 2) == 0;
        local $vars->{__even__}    = ($i % 2) == 1;
        local $vars->{__counter__} = $i + 1;
        local $ctx->{__stash}{entry}    = $e;
        local $ctx->{current_timestamp} = $e->created_on_obj;
        my $out = $builder->build($ctx, $token, {
            %$cond,
            EntryOrderNum => $i,
        });
        return $ctx->error($builder->errstr) unless defined $out;
        $html .= $out;
        $i++;
    }
    $html;
}

sub _hdlr_entry_permalink {
    my ($ctx, $arg) = @_;
    my $entry = $ctx->stash('entry');

    return $entry->url if $arg->{pc_url};

    my $app = MT->instance or return $ctx->error("No MT::App context");
    return $app->uri
        . '?__mode=individual&blog_id=' . $ctx->stash('blog_id')
        . '&entry_id=' . $entry->id;
}

sub _hdlr_blog_url {
    my ($ctx, $arg) = @_;

    my $blog = $ctx->stash('blog');
    return $blog->site_url if $arg->{pc_url};

    my $app = MT->instance;
    return $app->uri . '?blog_id=' . $ctx->stash('blog_id');
}

sub _hdlr_comments {
    my ($ctx, $arg, $cond) = @_;

    my @comments;
    if (my $e = $ctx->stash('entry')) {
        @comments = grep { $_->is_visible } @{ $e->comments };
    }
    elsif (my $c = $ctx->stash('comments')) {
        @comments = grep { $_->is_visible } @{ $c->comments };
    }
    else {
        return '';
    }

    my $vars    = $ctx->{__stash}{vars} ||= {};
    my $html    = '';
    my $builder = $ctx->stash('builder');
    my $tokens  = $ctx->stash('tokens');
    my $i       = 1;
    for my $c (@comments) {
        use Data::Dumper;
        local $ctx->{__stash}{comment}  = $c;
        local $ctx->{current_timestamp} = $c->created_on;
        $ctx->stash('comment_order_num', $i);
#         if ($c->commenter_id) {
#             $ctx->stash('commenter', delay(sub {MT::Author->load($c->commenter_id)}));
#         } else {
#             $ctx->stash('commenter', undef);
#         }
        my $out = $builder->build($ctx, $tokens);

        return $ctx->error( $builder->errstr ) unless defined $out;
        $html .= $out;
        $i++;
    }
    $html;
}

sub _hdlr_entry_body {
    my($ctx, $arg) = @_;
    my $e = $ctx->stash('entry')
        or return $ctx->_no_entry_error('MTEntryBody');
    my $text = $e->text;
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    return '' unless defined $text;

    ## filtering emoticon at post_process_handler.
    ## TODO: support emoticon
#     my $pconf = TypePad->current_portal->conf;
#     $arg->{filter_emoticon} = $pconf->{use_emoticon};

    ## replace or remove "a" tag.
    $text = _entry_body_filter($ctx, $text);

    ## TODO: getting from app->{cfg}
    my $length = 2000;
    if ($length) {
        my $paginator = HTML::Split->new(html => $text, length => $length);
        if ($paginator) {
            $paginator->current_page($ctx->stash('page') || 1);
            $text = $paginator->text;
            $ctx->stash(paginator => $paginator);
        }
    }

    if ($arg->{interpret_tags}) {
        my $b = $ctx->stash('builder');
        my $tokens = $b->compile($ctx, $text) or return $ctx->error($b->errstr);
        defined($text = $b->build($ctx, $tokens))
            or return $ctx->error($b->errstr);
    }
    my $convert_breaks = exists $arg->{convert_breaks} ? $arg->{convert_breaks}
                       : defined $e->convert_breaks    ? $e->convert_breaks
                       :                                 $ctx->stash('blog')->convert_paras
                       ;
    if ($convert_breaks) {
        my $filters = $e->text_filters;
        push @$filters, '__default__' unless @$filters;
        $text = MT->apply_text_filters($text, $filters, $ctx);
    }
    return $arg->{words} ? first_n_words($text, $arg->{words}) : $text;
}

sub _entry_body_filter {
    my ($ctx, $str) = @_;

    my $entry = $ctx->stash('entry');
    my ($last_tagname, $last_href) = ();

    my $start_handler = sub {
        my ($p, $tagname, $attr, $text) = @_;
        if ($tagname eq 'a') {
            my $url = URI->new($attr->{href})->abs($entry->url);
            $last_href = $url;
            unless ($url) {
                $p->{filtered_content} .= $text;
            }
            else {
                $url = _filter_url($ctx, $url);
                $p->{filtered_content} .= qq{<a href="$url">};

                my ($enc) = @{$entry->enclosures(href => $url)};
                if ($enc && $enc->type !~ m#^image/#) {
                    local $ctx->{__stash}{enclosure} = $enc;
                    my $length = $ctx->handler_for('EntryTypeCastEnclosureSize')->($ctx);
                    $p->{to_insert} = sprintf q{[<img class="emoticon %s" />%s]}, (split /\//, $enc->type)[0], $length;
                }
            }
        }
        elsif ($tagname eq 'img') {
            my $enclosure_icon = _is_enclosure_icon_url($attr->{src});

            ## obtain thumbnail url and link url.
            my ($href, $thumb_url);
            unless ($enclosure_icon) {
                my $src = $last_href || $attr->{src};
                my $cnt = $ctx->stash('thumbnail_count') || 0;
                if ($src) {
                    unless ($src =~ m{^http://}) {
                        $src = URI->new_abs($src, $ctx->stash('blog')->site_url)->as_string;
                    }
                    ($href, $thumb_url) = $ctx->_make_typecast_href($src, ($cnt < 3) ? 50 : 32);
                }
            }

            ## create html tag
            my $title = length $attr->{alt}   ? $attr->{alt}
                      : length $attr->{title} ? $attr->{title}
                      :                         ''
                      ;
            my $html = '';
            if ($enclosure_icon) {
                $html .= qq{[<img class="emoticon $enclosure_icon" />$title]};
            }
            elsif ($thumb_url) {
                $html = qq{<img class="thumbnail" src="$thumb_url" />};
            }
            elsif ($href) {
                $title ||= MT->translate('_IMAGE_1');
                $html = qq{[<img class="emoticon image" />$title]};
            }
            if ($href && $html && $last_tagname ne 'a') {
                $html = qq{<a href="$href">$html</a>};
            }

            $p->{filtered_content} .= $html;
        }
        else {
            $p->{filtered_content} .= $text;
        }
        $last_tagname = $tagname;
    };

    my $p = HTML::Parser->new(
        api_version => 3,
        start_h => [ $start_handler, "self,tagname,attr,text" ],
        end_h => [
            sub {
                my($p, $tagname, $text) = @_;
                $tagname ||= '';
                $text    ||= '';
                if ($tagname eq 'a') {
                    my $insert = delete $p->{to_insert} || '';
                    $p->{filtered_content} .= "$text$insert";
                    $last_href = '';
                }
                else {
                    $p->{filtered_content} .= $text;
                }
                $last_tagname = '';
            },
            "self,tagname,text",
        ],
        default_h => [
            sub { $_[0]->{filtered_content} .= $_[1] },
            "self,text",
        ],
    );
    $p->utf8_mode(1);
    $p->parse($str);
    $p->eof;
    $p->{filtered_content};
}

sub _make_typecast_href {
    my ($ctx, $url, $size) = @_;

    return unless is_valid_url($url);
    return $url if $url !~ m{^https?};

    my $url_obj   = URI->new($url);
    my $url_host  = $url_obj->host;
    my $blog_host = URI->new($ctx->stash('blog')->site_url)->host;

    my $is_internal =
        first {
            $url_host =~ m/$_$/
        } $blog_host, @{TypePad->current_portal->allowed_domains};

    my ($href, $thumbnail);
    ## is internal link
    if ($is_internal) {
        my $path = $url_obj->path;
        if ($path eq q{/.shared/image.html}) {
            $url =~ s{\Q$path?\E}{};
        }
        my ($enc) = @{$ctx->stash('entry')->enclosures(href => $url)};
        ## image file is not required including by enclosure
        if ($url =~ m{\.(jpe?g|png|gif)$}i) {
            $href      = $ctx->handler_for('TypeCastImageURL')->($ctx, { src => $url });
            $thumbnail = $ctx->handler_for('TypeCastThumbnailURL')->($ctx, { src => $url, size => $size });
        }
        elsif ($enc) {
            $href = $enc->href;
        }
    }
    $href ||= $ctx->handler_for('TypeCastRedirectLink')->($ctx, { exturl => $url });

    return ($href, $thumbnail);
}

sub _filter_url {
    my $ctx     = shift;
    my $url     = shift;
    my @filters = @_ ? @_ : qw( amazon_jp external image );

    return $url if $url !~ m{^https?};

    $url = URI->new($url) if ref $url eq 'URI::http';
    my ($new_url, $is_external);
    my $handler = {
        external => sub {
            my $blog_host = URI->new($ctx->stash('blog')->site_url)->host;
            return if $url->host =~ m{$blog_host$};
            $is_external = $new_url = _make_redirect_url($ctx, $url);
        },
        amazon_jp => sub {
            my ($asin, $associate_id) = $url =~ m{^http://www\.amazon\.co\.jp/exec/obidos/ASIN/(\w+)/([\w\-]+)};
            return unless $asin and $associate_id;
            $new_url = sprintf 'http://www.amazon.co.jp/gp/aw/rd.html?uid=NULLGWDOCOMO&at=%s&a=%s&dl=1&url=/gp/aw/d.html&lc=msn',
                $associate_id, $asin;
        },
        image => sub {
            return if $is_external;
            return if $url->path !~ m{\.(?:jpe?g|png|gif)$}i;
            $new_url = $ctx->handler_for('TypeCastImageURL')->($ctx, { src => $url });
        },
    };

    for my $filter (@filters) {
        exists $handler->{$filter} && $handler->{$filter}->();
    }

    return $new_url || $url;
}

sub _is_enclosure_icon_url {
    my $url = shift;

    return unless $url =~ m{/graphics/audio\-icon\.gif$};
    my ($extra_host) = MT::ConfigMgr->instance->URLStaticExtras =~ m{^https?://([\w\-\.]+)};
    my ($image_host) = $url =~ m{^https?://([\w\-\.]+)};
    return "audio" if $extra_host =~ m{$image_host$};
    return;
}

sub _make_redirect_url {
    my ($ctx, $url) = @_;
    my $entry = $ctx->stash('entry');
    my $blog  = $ctx->stash('blog');

    my $app = MT->instance or return $ctx->error("No MT::App context");
    return $app->uri . '?__mode=redirect_confirm'
        . '&blog_id=' . $blog->id . '&exturl=' . encode_url($url);
}

1;
