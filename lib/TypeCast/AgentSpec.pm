package TypeCast::AgentSpec;
use strict;
use warnings;

our (%DocomoSpec);

sub new {
    my $class = shift;
    my $query = shift;
    bless {
        query => $query,
    }, $class;
}

sub get_device_size {
    my $self = shift;
    my $q = $self->{query};

    my ($x, $y);
    if ($q->header_in('x-jphone-display')) {
        if ($self->_get_jphone_cache_size <= 6) {
            ($x, $y) = (120, 120);
        }
        else {
            ($x, $y) = $self->_get_jphone_device_size;
        }
    }
    elsif ($q->header_in('x-up-devcap-screenpixels')) {
        ($x, $y) = $self->_get_ezweb_device_size;
    }
    elsif ($q->header_in('User-Agent') =~ m{^PDXGW/}) {
        ($x, $y) = $self->_get_airh_device_size;
    }
    else {
        ($x, $y) = $self->_get_docomo_device_size;
    }

    if (!$x || !$y) {
        return (160, 160);
    }
    return ($x, $y);
}

sub _get_jphone_device_size {
    my $self = shift;
    my $q = $self->{query};

    return split /\*/, $q->header_in('x-jphone-display');
}

sub _get_ezweb_device_size {
    my $self = shift;
    my $q = $self->{query};
    return split /,/, $q->header_in('x-up-devcap-screenpixels');
}

sub _get_airh_device_size {
    my $self = shift;
    my $q = $self->{query};
    if ($q->header_in('User-Agent') =~ m{^PDXGW/\d\.\d\s*\(([^)]+)\)}) {
        my %spec = map {(split /=/, $_)} split /;/, $1;
        return ($spec{GX}, $spec{GY}) if exists $spec{GX} && exists $spec{GY};
    }
    elsif ($q->header_in('User-Agent') =~ m{^PDXGW/\d\.\d}) {
        return (72, 36);
    }
    return ();
}

sub _get_docomo_device_size {
    my $self = shift;
    my $q = $self->{query};

    my $ua = $q->header_in('User-Agent');
    return if $ua !~ m{^DoCoMo/\d\.\d[/ ]([^/(]+)};
    my $model = lc $1;
    my ($w, $h);
    if ($DocomoSpec{$model}) {
        ($w, $h) = ($DocomoSpec{$model}->{width}, $DocomoSpec{$model}->{height});
    }
    elsif ($ua =~ m{^DoCoMo/2\.0 }) {
        ($w, $h) = (240, 240);
    }
    return $w, $h;
}

sub add_spec {
    my $class = shift;
    my $data = shift;

    for my $spec (@$data) {
        $DocomoSpec{$spec->{name}} = {
            width  => $spec->{width},
            height => $spec->{height},
        };
    }
}

sub get_cache_size {
    my $self = shift;
    my $q = $self->{query};

    my $size;
    if ($q->header_in('x-jphone-display')) {
        $size = $self->_get_jphone_cache_size;
    }
    elsif ($q->header_in('x-up-devcap-screenpixels')) {
        $size = $self->_get_ezweb_cache_size;
    }
    elsif ($q->header_in('User-Agent') =~ m{^DoCoMo/}) {
        $size = $self->_get_docomo_cache_size;
    }

    return ($size || 20) * 1024;
}

sub _get_jphone_cache_size {
    my $self = shift;
    my $ua = $self->{query}->header_in('User-Agent');
    if ($ua !~ /^(?:Vodafone|MOT-)/ && (split '/', $ua)[1] =~ /^[23]\./) {
        return 5;
    }
    return 12;
}

sub _get_ezweb_cache_size {
    my $self = shift;
    my ($x) = $self->_get_ezweb_device_size;
    return $x >= 240 ? 20 : 9;
}

sub _get_docomo_cache_size {
    my $self = shift;
    my ($x) = $self->_get_docomo_device_size;
    return $x >= 240 ? 20 : 10;
}

1;
__END__
