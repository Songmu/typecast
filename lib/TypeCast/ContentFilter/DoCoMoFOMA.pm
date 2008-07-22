# $Id$
package TypeCast::ContentFilter::DoCoMoFOMA;
use strict;
use warnings;

use base qw( TypeCast::ContentFilter::Base );

use CSS;

my %no_style_tags    = map {$_ => 1} qw( h1 h2 h3 h4 h5 h6 a address );
my %no_text_tags     = map {$_ => 1} qw( br hr img input );
my %no_decorate_tags = map {$_ => 1} qw( span textarea );
my %emoticon_map = (
    video       => '&#xE677;',
    audio       => '&#xE67A;',
    image       => '&#xE681;',
    view        => '&#xE688;',
    entry       => '&#xE689;',
    edit        => '&#xE719;',
    moderated   => '&#xE737;',
    delete      => '&#xE696;',
    comment     => '&#xE6FA;',
    trackback   => '&#xE735;',

    digit1       => '&#xE6E2;',
    digit2       => '&#xE6E3;',
    digit3       => '&#xE6E4;',
    digit4       => '&#xE6E5;',
    digit5       => '&#xE6E6;',
    digit6       => '&#xE6E7;',
    digit7       => '&#xE6E8;',
    digit8       => '&#xE6E9;',
    digit9       => '&#xE6EA;',
    digit0       => '&#xE6EB;',

    config1      => '&#xE68E;',
    config2      => '&#xE68F;',
    config3      => '&#xE690;',
    design       => '&#xE67B;',
    profile      => '&#xE6F0;',
    moblog       => '&#xE688;',
    phoneto      => '&#xE6CE;',
);

my %imemode_map = (
    1 => q{-wap-input-format:"*<ja:h>"},
    2 => q{-wap-input-format:"*<ja:hk>"},
    3 => q{-wap-input-format:"*<ja:en>"},
    4 => q{-wap-input-format:"*<ja:n>"},
);

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'application/xhtml+xml';
    $filter->{encoding}      = 'utf-8';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 1;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 1;
    $filter->{typecast_css}  = CSS->new({ parser => 'CSS::Parse::Packed' });
    $filter->{typecast_current} = [];
}

sub lookup_emoticon {
    $emoticon_map{$_[1]};
}

sub lookup_imemode {
    $imemode_map{$_[1]};
}

sub is_header_tag {
    my $filter = shift;
    my($tagname) = @_;
    return $tagname eq 'title';
}

sub no_style_tag {
    my $filter = shift;
    my($tagname) = @_;
    $no_style_tags{$tagname};
}

sub no_text_tag {
    my $filter = shift;
    my($tagname) = @_;
    $no_text_tags{$tagname};
}

sub no_decorate_tag {
    my $filter = shift;
    my($tagname) = @_;
    $no_decorate_tags{$tagname};
}

sub is_block_tag {
    my $filter = shift;
    my($tagname) = @_;
    return $tagname =~ /^h\d/;
}

sub do_output_tag {
    my $filter = shift;
    my($tagname, $attr, $attrseq) = @_;

    ## istyle to xhtml style value
    if (exists $attr->{istyle}) {
        my $mode = delete $attr->{istyle};
        $attr->{style} = $filter->lookup_imemode($mode);
        push @$attrseq, 'style';
    }

    unless ($filter->is_header_tag($tagname)) {
        $filter->do_inline_stylesheet($tagname, $attr, $attrseq);
    }

    my %cb;
    if ($filter->no_style_tag($tagname)) {
        my $style = delete $attr->{style};
        @$attrseq = grep { $_ ne 'style' } @$attrseq;
        ## Enclosing block tag with div.
        if ($filter->is_block_tag($tagname) && $style) {
            $cb{pre} = sub {
                $filter->{typecast_output} .= qq(<div style="$style">);
            };
        }
    }
    elsif ($tagname ne 'span') {
        if ($attr->{style}) {
            $attr->{style} =~ s/font\-size\s*:\s*[\w\-]+;?//;
        }
    }
    elsif ($tagname eq 'label') {
        $tagname = 'span';
        delete $attr->{for};
    }
    elsif ($tagname eq 'br/') {
        $tagname = 'br';
        $attr->{'/'} = '__BOOLEAN__';
        push(@$attrseq, q{/});
    }

    $cb{pre}->() if $cb{pre};
    $filter->{typecast_output} .= qq(<$tagname);
    ## a#id should be retained because that is used as URL fragment part.
    if ($tagname eq 'a' and $attr->{id}) {
        $filter->{typecast_output} .= qq( id="$attr->{id}");
    }
    $filter->do_append_attributes($attr, $attrseq);
    $filter->{typecast_output} .= ">";
    $cb{post}->() if $cb{post};
}

sub declaration {
    my $filter = shift;
    $filter->{typecast_output} .= q(<!DOCTYPE html PUBLIC "-//i-mode group (ja)//DTD XHTML i-XHTML(Locale/Ver.=ja/1.1) 1.0//EN" "i-xhtml_4ja_10.dtd">);
}

sub end {
    my $filter = shift;
    my($tagname, $text) = @_;

    unless ($filter->no_text_tag($tagname)) {
        pop @{ $filter->{text_styles_tree} };
    }

    my $current = $filter->{typecast_current}->[-1];
    if ($current && ($current->{tagname}||'') eq $tagname) {
        pop @{$filter->{typecast_current}}; # LIFO
    }
    if ($tagname eq 'label') {
        $tagname = 'span';
        $text    =~ s/label/span/;
    }
    if ($filter->no_style_tag($tagname)) {
        if ($filter->is_block_tag($tagname)) {
            $filter->{typecast_output} .= $text;
            $filter->{typecast_output} .= "</div>";
        } else {
            $filter->{typecast_output} .= $text;
        }
    } else {
        $filter->SUPER::end($tagname, $text);
    }
}

sub text {
    my $filter = shift;
    my ($text, $is_cdata) = @_;

    if ($text =~ /\S/) {
        ## if the current tag has font-size style, adding 'span' child node
        ## to apply it except span and textarea tags.
        my $current = $filter->{typecast_current}->[-1];
        unless ($current && $filter->no_decorate_tag($current->{tagname})) {
            my %style;
            for my $st (@{ $filter->{text_styles_tree} }) {
                %style = ( %style, %$st );
            }
            my $style = '';
            while (my ($key, $val) = each %style) {
                $style .= "$key:$val;";
            }
            $text = qq(<span style="$style">$text</span>) if $style;
        }
    }

    $filter->SUPER::text($text, $is_cdata);
}

sub do_append_attributes {
    my($filter, $attr, $attrseq) = @_;
    @$attrseq = grep { $_ ne "id" && $_ ne "class" } @$attrseq;
    $filter->SUPER::do_append_attributes($attr, $attrseq);
}

sub do_inline_stylesheet {
    my($filter, $tagname, $attr, $attrseq) = @_;
    ## We'll search possible selectors
    ## e.g. <form id="comments_form"><dl class="bar"><dd class="foo">
    ## searches for "dd", ".foo", "dd.foo",
    ## "#comments_form dd", "form#comments_form dd"
    ## ".bar dd", "dl.bar dd"
    ## TODO: support class="foo bar"?
    my @cand = ($tagname);
    if (my $class = $attr->{class}) {
        push @cand, ".$class", "$tagname.$class";
    } elsif (my $id = $attr->{id}) {
        push @cand, "#$id", "$tagname#$id";
    }
    if (my $parent = $filter->{typecast_current}->[-1]) {  # LIFO
        my($tag, $class, $id) = @$parent{qw( tagname class id )};
        push @cand, $class
            ? (".$class $tagname", "$tag.$class $tagname")
            : ("#$id $tagname", "$tag#$id $tagname");
    }

    ## find appropriate style properties
    my @style = $filter->find_style(@cand);

    ## append original style used in the post
    my $orig_style = delete $attr->{style};
    push @style, $orig_style if $orig_style;

    ## if no style is found, then use *
    @style = $filter->find_style('*') unless @style;
    if (@style) {
        push @$attrseq, "style" unless $orig_style;
    }

    ## push styles of the current TEXT node to the stack
    my %text_styles = ();
    for my $st (map { ref($_) ? $_->properties : $_ } @style) {
        if ($st =~ /font\-size\s*:\s*([\w\-]+);?/) {
            $text_styles{'font-size'} = $1;
        }
        elsif ($st =~ /(?<!background-)color\s*:\s*([#\w]+)/) {
            $text_styles{color} = $1;
        }
        $attr->{style} .= $st . ';';
    }
    unless ($filter->no_text_tag($tagname)) {
        push @{ $filter->{text_styles_tree} }, \%text_styles;
    }

    ## push the current tag/class or tag/id to the stack
    if (!($attr->{'/'} && $attr->{'/'} eq '__BOOLEAN__') &&
            ($attr->{class} || $attr->{id})) {
        push @{ $filter->{typecast_current} },
            {
                tagname => $tagname,
                class   => ($attr->{class} || ''),
                id      => ($attr->{id} || ''),
            };
    }
}

sub find_style {
    my($filter, @selector) = @_;
    my @style = map $filter->{typecast_css}->get_style_by_selector($_), @selector;
    return grep $_, @style;
}

sub add_css_data {
    my($filter, $css_data) = @_;
    $filter->{typecast_css}->read_string($css_data);
}

1;
