# $Id$
package TypeCast::Emoticon::Encode;

use strict;
use warnings;

use YAML::Tiny;

my $EncodeMap;

sub new {
    my $class = shift;
    my %param = @_;

    my $agent = $param{agent};
    my $impl  = !$agent               ? 'XHTML'
              : !$agent->isa('HTTP::MobileAgent') ? 'XHTML'
              : $agent->is_docomo     ? 'DoCoMo'
              : $agent->is_ezweb      ? 'KDDI'
              : $agent->is_softbank   ? 'Softbank'
              : $agent->is_airh_phone ? 'DoCoMo'
              :                         'XHTML'
              ;
    my $impl_class = __PACKAGE__.'::'.$impl;
    eval "require $impl_class";
    die $@ if $@;

    unless ($EncodeMap) {
        my $file = $param{config} || MT->instance->find_config({ Config => 'conf/emoticon.yaml' });
        my $yaml = YAML::Tiny->read($file)
            or die "can't open file: $file";
        if (ref $yaml) {
            # skip over non-hash elements
            shift @$yaml while @$yaml && ref($yaml->[0]) ne 'HASH';
            $EncodeMap = $yaml->[0] if @$yaml;
        }
        die "can't parse file: $file"
            unless $EncodeMap && %$EncodeMap;

        for (qw( docomo kddi softbank )) {
            $EncodeMap->{$_} = { reverse %{$EncodeMap->{$_}} };
        }
    }

    $param{static_url} ||= MT->instance->config->StaticWebPath;

    return $impl_class->new(emoticon => $EncodeMap, %param);
}

1;
__END__

=head1 NAME

TypeCast::Emoticon::Encode - Encode emoticons from emoticon syntax to utf8/XHTML.

=head1 SYHOPSIS

  my $emoticon = TypeCast::Emoticon::Encode->new(
      agent      => HTTP::MobileAgent->new,
      static_url => '/tc/static',
      edit_mode  => 1,  ## encoding for input / textarea elements.
   );
   $emoticon->encode($str);

=cut
