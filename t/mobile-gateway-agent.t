#!/usr/bin/perl
use strict;
use FindBin qw($Bin);
use lib "$Bin/../../cpan-lib";

use Test::More tests => 13;
use YAML;

my %ok_agent = (
    nttdocomo => [
        q{DoCoMo/2.0 N900i(c100;TB;W24H12)},
        q{DoCoMo/1.0/N505i/c20/TB/W20H10},
        q{Mozilla/4.08 (N903i;FOMA;c300;TB;W24H12)},
    ],
    vodafone => [
        q{SoftBank/1.0/910T/TJ001 Browser/NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1},
        q{Vodafone/1.0/V904SH/SHJ001 Browser/VF-NetFront/3.3 Profile/MIDP-2.0 Configuration/CLDC-1.1},
        q{J-PHONE/4.0/J-SH51/SN SH/0001a Profile/MIDP-1.0 Configuration/CLDC-1.0},
        q{Mozilla/4.08 (910SH;SoftBank) NetFront/3.3},
    ],
    au => [
        q{KDDI-SA31 UP.Browser/6.2.0.7.3.129 (GUI) MMP/2.0},
        q{Mozilla/4.0 (compatible; MSIE 6.0; KDDI-HI38) Opera 8.5 [ja]},
    ],
    willcom => [
        q{Mozilla/3.0(DDIPOCKET;KYOCERA/AH-K3001V/1.0/1.0/C100) Opera/7.0},
        q{Mozilla/3.0(WILLCOM;KYOCERA/WX301K/1.0/1.0/C100) Opera 7.0},
        q{Mozilla/4.0 (compatible; MSIE 6.0; Windows CE; SHARP/WS003SH; PPC; 480x640) Opera 8.5 [ja]},
        q{Mozilla/4.08(MobilePhone; NMCS/3.3) NetFront/3.3},
    ],
);

my $file   = "$Bin/../conf/mobile_gateway.yaml";
my $config = YAML::LoadFile($file);
for my $op (qw(nttdocomo vodafone au willcom)) {
    for my $agent (@{ $ok_agent{$op} }) {
        ok(is_valid_ua($op, $agent), "$agent");
    }
}

sub is_valid_ua {
    my ($op, $agent) = @_;
    for my $regexp (@{ $config->{$op}{ua_regexp} }) {
        return 1 if $agent =~ m/$regexp/;
    }
    return;
}
