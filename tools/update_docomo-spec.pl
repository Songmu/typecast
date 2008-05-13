#!/usr/bin/perl
use strict;
use warnings;

BEGIN {
    use FindBin;
    $ENV{TypePadBase} = $ENV{SixApartBase} = "$FindBin::Bin/../..";
}

use LWP::UserAgent;
use Encode;
use Encode::JP;
use strict;
use utf8;

my $CONF_NAME = "$ENV{TypePadBase}/typecast/conf/docomo-spec.yaml";
my $SPEC_URL = 'http://www.nttdocomo.co.jp/p_s/imode/spec/ryouiki.html';

my $ua = LWP::UserAgent->new;
my $res = $ua->get($SPEC_URL);
if (!$res->is_success) {
    die "$0: cannot update $CONF_NAME: ". $res->status_line;
}

my $body = $res->content;
utf8::downgrade($body);
$body = Encode::decode('Shift_JIS', $body);
$body =~ s/\r?\n+/\n/g;
$body =~ tr/０-９/0-9/;
my $reg = regexp();
my %map;
while ($body =~ m{$reg}gis)
{
    my ($model, $width, $height, $color, $depth) = ($1, $2, $3, $4, $5);
    $map{lc $model} = {
        width  => $width,
        height => $height,
    };
}

open my $out, '>', $CONF_NAME or die "$0: cannot open $CONF_NAME: $!";
binmode($out=>':encoding(utf8)');
print $out <<__HANDLER__;
handler: TypeCast::AgentSpec::add_spec

data:
__HANDLER__
for my $m (sort keys %map) {
    printf $out qq{    - name: %s
      width: %d
      height: %d

},
        $m,
        $map{$m}->{width},
        $map{$m}->{height};
}
close $out;
exit;


sub regexp {
    return <<'RE';
<TD><FONT SIZE="2">([A-Z]+\d+\w*)</FONT></TD>
<TD><FONT SIZE="2">.*?</FONT></TD>
<TD><FONT SIZE="2">.*?</FONT></TD>
<TD><FONT SIZE="2">(.*?)×(.*?)</FONT></TD>
<TD><FONT SIZE="2">.*?</FONT></TD>
<TD><FONT SIZE="2">.*?</FONT></TD>
RE
    ;
}
