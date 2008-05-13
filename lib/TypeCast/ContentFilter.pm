# $Id$
package TypeCast::ContentFilter;
use strict;
use warnings;

use HTTP::MobileAgent;
use File::Basename;
use File::Spec;

use TypeCast::ContentFilter::Base;

## load subclasses here
__PACKAGE__->load_subclasses;

sub load_subclasses {
    my $dir = File::Basename::dirname($INC{'TypeCast/ContentFilter/Base.pm'});
    opendir DIR, $dir;
    while (my $file = readdir DIR) {
        next if $file !~ /\.pm$/ or $file eq 'Base.pm';
        my $module = File::Spec->catfile($dir, $file);
        eval { require $module };
        die $@ if $@;
    }
    closedir DIR;
}

sub new {
    my $class = shift;
    my ($ua) = @_;

    my $agent = HTTP::MobileAgent->new($ua)
        unless ref($ua) eq 'HTTP::MobileAgent';

    my $impl_class = $class . "::" . _init_impl($agent);
    $impl_class->new(agent => $agent);
}

sub _init_impl {
    my $agent = shift || return "Base";

    $agent->is_docomo && $agent->is_foma       and return "DoCoMoFOMA";
    $agent->is_docomo                          and return "DoCoMoMova";
    $agent->is_vodafone && $agent->is_type_3gc and return "VodafoneXHTML";
    $agent->is_vodafone                        and return "VodafoneHTML";
    $agent->is_ezweb                           and return "KDDI";
    $agent->is_airh_phone                      and return "AirEDGE";
    ## TODO:
    ##   'is_nokia' is TypeCore::Util::MobileAgent implementation.
    ##   need to implement the alternate way or patch HTTP::MobileAgent
#    $agent->is_nokia                           and return "Nokia";
    return "Base";
}

1;
