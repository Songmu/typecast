# $Id$
package TypeCast::Util;
use strict;
use warnings;

use File::Basename;
use URI;
use HTML::Parser;
use HTTP::Request;
use HTTP::Headers;
use Socket;
use Date::Parse;

use MT;
use MT::ConfigMgr;
use MT::DateTime;

# sub make_compact_url {
#     my ($str) = @_;

#     my $typecast_uri = TypePad->current_portal->typecast_url;
#     return $str unless ($str && $str =~ m{^$typecast_uri});

#     my $uri = URI->new($str) or return $str;
#     my $query = $uri->query || '';

#     ## get params whil stripping from original query.
#     my $blog_id  = $1      if ($query =~ s{&?blog_id=(\d+)}{});
#     my $user_id  = $1 or 0 if ($query =~ s{&?user_id=(\d+)}{});
#     my $action   = $1      if ($query =~ s{&?(?:entry_)?id=(\d+)}{});
#     my $resource = $1      if ($query =~ s{&?__mode=(\w+)}{});
#     $query =~ s{^&}{} if $query;

#     ## filter
#     if ($resource) {
#         if ($resource eq 'individual' or $resource eq 'main_index') {
#             $resource = undef;
#         }
#         elsif ($resource eq 'list_comments') {
#             $resource = $action;
#             $action   = 'list_comments';
#         }
#     }

#     ## show_image mode append image filename to path of url.
#     my ($file) = $uri =~ m{^$typecast_uri/([\w\.]+)};

#     my $path = join '/', grep { defined $_ } ($blog_id, $user_id, $resource, $action, $file);

#     return "$typecast_uri/$path" . ($query ? '?'.$query : '');
# }

sub basename_of_url {
    my $uri = URI->new(shift) or return;
    return basename $uri->path;
}

sub match_ip {
    my ($remote_ip, $allow_ip_ref) = @_;

    my $remote_ip_bit = join '', map { unpack('B8', pack('C', $_)) } split /\./, $remote_ip;
    for my $allow_ip (@$allow_ip_ref) {
        return 1 if $remote_ip eq $allow_ip;
        if ($allow_ip =~ /^([\d\.]+)\/(\d+)$/) {
            my $allow_ip_bit = join '', map { unpack('B8', pack('C', $_)) } split /\./, $1;
            return 1 if substr($remote_ip_bit, 0, $2) eq substr($allow_ip_bit, 0, $2);
        }
    }
    return;
}

sub match_ip_domain {
    my ($remote_ip, $allow_domain_ref) = @_;

    return unless ref $allow_domain_ref eq 'ARRAY' && @$allow_domain_ref;

    my $host = gethostbyaddr inet_aton($remote_ip), AF_INET;
    for my $domain (@$allow_domain_ref) {
        return 1 if $host =~ m{\Q$domain\E$};
    }
    return;
}

sub http_get {
    my ($url, %header) = @_;

    return '' unless $url =~ /^https?:/;

    my $req = HTTP::Request->new(GET => $url, HTTP::Headers->new(%header));
    my $res = LWP::UserAgent->new(timeout => 15)->request($req);
    return '' unless $res->is_success;
    return $res->content;
}

sub discover_mobile_link {
    my ($url) = @_;

    my $ua = LWP::UserAgent->new(timeout => 15);
    my $res = $ua->get($url);
    return unless $res->is_success;
    my $content = $res->content or return;

    my $p = HTML::Parser->new(
        api_version => 3,
        start_h     => [
            sub {
                my ($p, $tag, $attr) = @_;
                if ($tag eq 'link'
                        && lc $attr->{rel}   eq 'alternate'
                        && lc $attr->{media} eq 'handheld') {
                    $p->{mobile_url} = URI->new_abs($attr->{href}, $p->{base_uri});
                    $p->eof;
                }
                elsif ($tag eq 'body') {
                    $p->eof;
                }
            },
            'self,tagname,attr',
        ],
    );
    $p->{base_uri} = $url;
    local $^W;
    $p->report_tags(qw( link body ));
    $p->parse($content);
    return $p->{mobile_url};
}

sub parse_date {
    my $date = shift or return;
    my ($s, $m, $h, $d, $mo, $y, $tz);
    if ($date =~ /^\d{14}$/) {
        ($y, $mo, $d, $h, $m, $s) = unpack 'A4A2A2A2A2A2', $date;
    }
    else {
        ## 2005-06-23T14:56:06       => $tz = undef
        ## 2005-06-23T14:56:06Z      => $tz = 0
        ## 2005-06-23T14:56:06+09:00 => $tz = 32400
        ($s, $m, $h, $d, $mo, $y, $tz) = Date::Parse::strptime($date);
        $y  += 1900;
        $mo += 1;
    }
    return MT::DateTime->new(
        year   => $y,
        month  => $mo,
        day    => $d,
        hour   => $h || 0,
        minute => $m || 0,
        second => $s || 0,
    );
}

{
    no strict 'refs';
    *MT::DateTime::ts = sub {
        my $dt = shift;
        sprintf '%04d%02d%02d%02d%02d%02d',
                $dt->year, $dt->month, $dt->day,
                $dt->hour, $dt->minute, $dt->second;
    };
}

1;
