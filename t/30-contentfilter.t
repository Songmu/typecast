use strict;
use Test::More tests => 8;

use_ok('TypeCast::ContentFilter');

isa_ok(
    TypeCast::ContentFilter->new('Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)'),
    'TypeCast::ContentFilter::Base'
);

isa_ok(
    TypeCast::ContentFilter->new('DoCoMo/2.0 N900i(c100;TB;W24H12)'),
    'TypeCast::ContentFilter::DoCoMoFOMA'
);

isa_ok(
    TypeCast::ContentFilter->new('DoCoMo/1.0/N505i/c20/TB/W20H10'),
    'TypeCast::ContentFilter::DoCoMoMova'
);

isa_ok(
    TypeCast::ContentFilter->new('KDDI-KC3A UP.Browser/6.2.0.7.3.129 (GUI) MMP/2.0'),
    'TypeCast::ContentFilter::KDDI'
);

isa_ok(
    TypeCast::ContentFilter->new('SoftBank/1.0/910T/TJ001/SN0123456789 Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1'),
    'TypeCast::ContentFilter::VodafoneXHTML'
);

isa_ok(
    TypeCast::ContentFilter->new('J-PHONE/4.0/J-SH51/SN SH/0001a Profile/MIDP-1.0 Configuration/CLDC-1.0'),
    'TypeCast::ContentFilter::VodafoneHTML'
);

isa_ok(
    TypeCast::ContentFilter->new('Mozilla/3.0(WILLCOM;KYOCERA/WX301K/1.0/1.0/C100) Opera 7.0'),
    'TypeCast::ContentFilter::AirEDGE',
);
