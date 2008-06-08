# $Id$
package TypeCast::Emoticon::Decode;

use strict;
use warnings;

my $DecodeMap;

sub new {
    my $class = shift;
    my %param = @_;

    my $agent = $param{agent};
    unless ($agent && $agent->isa('HTTP::MobileAgent')) {
        require HTTP::MobileAgent;
        $agent = HTTP::MobileAgent->new;
    }
    my $impl  = $agent->is_docomo   ? 'DoCoMo'
              : $agent->is_softbank ? 'Softbank'
              : $agent->is_ezweb    ? 'KDDI'
              :                       'XHTML'
              ;
    my $impl_class = __PACKAGE__.'::'.$impl;
    eval "require $impl_class";
    die $@ if $@;

    unless ($DecodeMap) {
        require YAML;
        my $file = $param{config} || MT->instance->find_config({ Config => 'conf/emoticon.yaml' });
        $DecodeMap = YAML::LoadFile($file)
            or die "can't open file: $file";
    }

    return $impl_class->new(emoticon => $DecodeMap, %param);
}

1;
__END__

=head1 NAME

TypeCast::Emoticon::Decode - Decode emoticons from utf8/XHTML to emoticon syntax.

=head1 SYHOPSIS

  my $emoticon = TypeCast::Emoticon::Decode->new(
      agent => HTTP::MobileAgent->new,
   );
   $emoticon->decode($str);

=cut
