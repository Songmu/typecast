# $Id$
package TypeCast::ContentFilter::Base;
use strict;
use warnings;

use base qw( HTML::Parser );

use URI;
use MT::I18N qw( encode_text );
use MT::Util qw( encode_html );
# use TypePad::Emoticon::OutputFilter;
use TypeCast::Util;

sub new {
    my $class = shift;
    my %param = @_;
    my $filter = bless { }, $class;
    $filter->SUPER::init();
    $filter->boolean_attribute_value('__BOOLEAN__');
    $filter->utf8_mode(1);
    $filter->init(%param);
#    $filter->{emoticon} = TypePad::Emoticon::OutputFilter->new(agent => $param{agent});
    $filter;
}

sub init {
    my $filter = shift;
    $filter->{content_type}  = 'text/html';
    $filter->{encoding}      = 'utf-8';
    $filter->{is_xml}        = 1;
    $filter->{inline_css}    = 0;
    $filter->{strip_css}     = 0;
    $filter->{use_emoticons} = 0;
}

sub content_type     { $_[0]->{content_type} }
sub encoding         { $_[0]->{encoding} }
sub input_encoding   { $_[0]->{input_encoding} || $_[0]->{encoding} }
sub is_xml           { $_[0]->{is_xml} }
sub inline_css       { $_[0]->{inline_css} }
sub strip_css        { $_[0]->{strip_css} }
sub use_emoticons    { $_[0]->{use_emoticons} }

sub rewrite_content {
    my $filter = shift;
    my ($html_ref) = @_;

    $filter->parse($$html_ref);
    $filter->eof;

    if (lc $filter->input_encoding ne 'utf-8') {
        $filter->{typecast_output} = encode_text($filter->{typecast_output}, 'utf-8', $filter->input_encoding);
    }
    $$html_ref = $filter->{typecast_output};
}

sub start {
    my($filter, $tagname, $attr, $attrseq, $text) = @_;

    ## Inlining CSS needs fetching the CSS via HTTP
    if ($tagname eq 'link' && lc($attr->{rel} || '') eq 'stylesheet' &&
        ($filter->inline_css || $filter->strip_css)) {
        $filter->add_style($attr->{href}) if $filter->inline_css;
    }
    ## Fix meta tags appropriately regardless of template value
    elsif ($tagname eq 'meta' && lc($attr->{'http-equiv'}) eq 'content-type') {
        $filter->{typecast_output} .= qq(<meta http-equiv="Content-Type" content="$filter->{content_type};charset=$filter->{encoding}") . ($filter->is_xml ? ' /' : '') . '>';
    }
    ## In emoticon mode, strip ul/li to p/br
    elsif ($filter->use_emoticons && $tagname eq 'ul' && ($attr->{class}||'') =~ /emoticons/) {
        $filter->{typecast_output} .= "<p>";
        $filter->{typecast_emoticon_ul} = 1;
    }
    elsif ($filter->use_emoticons && $tagname eq 'li' && ($attr->{class}||'') =~ /emoticon/) {
        my $emo = (grep { $_ ne 'emoticon' } split /\s+/, $attr->{class})[0];
        $filter->{typecast_output} .= $filter->lookup_emoticon($emo) if $emo;
        $filter->{typecast_emoticon_li} = 1;
    }
    ## In emoticon mode, replace img to emoticon
    elsif ($filter->use_emoticons && $tagname eq 'img' && ($attr->{class}||'') =~ /emoticon/) {
        my $emo = (grep { $_ ne 'emoticon' } split /\s+/, $attr->{class})[0];
        $filter->{typecast_output} .= $filter->lookup_emoticon($emo) if $emo;
    }
    ## remove img has no src attribute
    elsif ($tagname eq 'img' && !defined $attr->{src}) {
        ## do nothing ...
    }
    ## Otherwise, just output the parsed tags with approprite fixes
    else {
        $filter->do_output_tag($tagname, $attr, $attrseq);
    }
}

sub do_output_tag {
    my $filter = shift;
    my($tagname, $attr, $attrseq) = @_;

    if ($tagname eq 'br/') {
        $tagname = 'br';
        $attr->{'/'} = '__BOOLEAN__';
        push(@$attrseq, q{/});
    }

    $filter->{typecast_output} .= qq(<$tagname);
    $filter->do_append_attributes($attr, $attrseq);
    $filter->{typecast_output} .= ">";
}

sub do_append_attributes {
    my ($filter, $attr, $attrseq) = @_;
    my $is_boolean = 0;
    for my $key (@$attrseq) {
        next if !defined $attr->{$key};
        ## ignore html xmlns for non-XHTML browsers
        next if !$filter->is_xml && $key eq 'xmlns';
        ## ignore class/style if it strips CSS
        next if $filter->strip_css && ($key eq 'class' || $key eq 'style');
        if ($attr->{$key} eq '__BOOLEAN__') {
            $is_boolean = 1;
        } else {
            $filter->{typecast_output} .= sprintf qq( $key="%s"), encode_html($attr->{$key});
        }
    }

    ## boolean (e.g. <hr />) should come last
    $filter->{typecast_output} .= " /" if $is_boolean && $filter->is_xml;
}

sub end {
    my($filter, $tagname, $text) = @_;
    if ($filter->use_emoticons && $filter->{"typecast_emoticon_$tagname"}) {
        if ($tagname eq 'ul') {
            $filter->{typecast_output} .= "</p>";
        } else {
            $filter->{typecast_output} .= "<br" . ($filter->is_xml ? ' /' : '') . ">";
        }
        $filter->{"typecast_emoticon_$tagname"} = 0;
    } else {
        $filter->{typecast_output} .= $text;
    }
}

sub text {
    my($filter, $text, $is_cdata) = @_;
    ## HTML optimization
    unless ($text =~ /^\n+$/) {
        $filter->{typecast_output} .= $text;
    }
}

sub process {
    my($filter, $token0, $text) = @_;
    if ($filter->is_xml) {
        $filter->{typecast_output} .= $text;
    }
}

sub comment {
    my($filter, $text) = @_;
    ## we should retain comments of Mobile GoogleAdSense.
    if ($text =~ /^\s*google_afm\b/) {
        $filter->{typecast_output} .= '<!--'.$text.'-->';
    }
}

sub declaration {
    my($filter, $text) = @_;
    ## no XHTML declaration for non-XHTML browsers
    if ($filter->is_xml) {
        my $enc = $filter->encoding;
        $filter->{typecast_output} 
            =~ s{^(<\?xml version="1.0" encoding="[^\"]*"\?>)}
                {<?xml version="1.0" encoding="$enc"\?>}i;
        $filter->{typecast_output} .= qq(<!$text>);
    }
}

sub add_style {
    my($filter, $href) = @_;
    my %header = ();
    if (my $cred = MT->instance->get_header('Authorization')) {
        $header{Authorization} = $cred;
    }

    my $css_data = TypeCast::Util::http_get($href, %header)
                || $filter->default_styles_mobile;
    $filter->add_css_data($css_data) if $css_data;
}

sub add_css_data {
    my($filter, $data) = @_;
    $filter->{typecast_output} .= <<STYLE;
<style type="text/css">
$data
</style>
STYLE
}

sub default_styles_mobile {
    return <<CSS;
body { color: black; background-color: white; }
CSS
}

1;
