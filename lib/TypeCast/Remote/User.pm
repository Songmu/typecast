# $Id$
package TypeCast::Remote::User;
use strict;
use warnings;

use base qw( TypeCast::Remote );

use MT::Util qw( encode_url );
use TypeCast::Util;

sub new_from_foaf {
    my $class = shift;
    my($foaf, $blog) = @_;
    my $user = bless { person => $foaf && $foaf->person, blog => $blog }, $class;
    $user;
}

sub person { $_[0]->{person} }
sub blog   { $_[0]->{blog} }

my %about_display = (
    email    => 'email',
    name     => 'full_name',
    nickname => 'nickname',
    minibio  => 'minibio',
    bio      => 'bio',
    photo    => 'image_url',
    url      => 'url',
    aim      => 'aim',
    icq      => 'icq',
    msn      => 'msn',
    yahoo    => 'yahoo',
    interests => 'interests',
);

sub about_display {
    my $user = shift;
    my($field) = @_;
    if (my $method = $about_display{$field}) {
        defined $user->$method;
    } else {
        return 0;
    }
}

sub email     {
    my $user = shift;
    my $mbox = $user->person->mbox or return;
    $mbox =~ s/^mailto://;
    $mbox;
}

sub url       { $_[0]->person->homepage }
sub full_name { _utf8_off($_[0]->person->name) }
sub nickname  { _utf8_off($_[0]->person->nick) }
sub bio       { _utf8_off($_[0]->person->plan) }

sub aim   { $_[0]->person->aimChatID }
sub icq   { $_[0]->person->icqChatID }
sub msn   { $_[0]->person->msnChatID }
sub yahoo { $_[0]->person->yahooChatID }

sub minibio   { _utf8_off($_[0]->person->get("http://purl.org/vocab/bio/0.1/olb")) }  
sub interests { _utf8_off($_[0]->person->get("http://purl.org/vocab/bio/0.1/keywords")) }

sub image_url {
    my $user = shift;
    my $app  = MT->current_app or return $user->error("No context app running");
    my $url = $user->person->img or return;
    my ($file) = encode_url(TypeCast::Util::basename_of_url($url));
    $app->base . $app->uri . "/$file?__mode=show_image&src=" . encode_url($url) . '&blog_id=' . $user->blog->id . "&user_id=" . $user->blog->user_id;
}

sub portal {
    TypePad->current_portal->code;
}

use Date::Parse ();

## This is tricky. Take the 1st appearance of atom:issued and examine the TZ flag.
## i.e.) <atom:issued>2003-04-17T17:43:30+09:00</atom:issued>
##       indicates that the user's timezone is JST (+0900)
sub timezone {
    my $user = shift;
    my $feed = $user->blog->atom;
    my $offset = [Date::Parse::strptime($feed->get($feed->ns, 'issued'))]->[-1];
    DateTime::TimeZone::offset_as_string($offset);
}

sub preferred_locale {}

sub _utf8_off { 
    Encode::_utf8_off($_[0]) if Encode::is_utf8($_[0]); 
    return $_[0]; 
}

sub name { '_typecast_remote_user_'}
sub id   { $_[0]->blog && $_[0]->blog->user_id }

1;
