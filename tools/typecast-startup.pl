use strict;
use warnings;

use File::Spec;
#
# Apache + mod_perl memory tuning w/ GTopLimit
#
use Apache::GTopLimit;

# Set max process size to 35MB
$Apache::GTopLimit::MAX_PROCESS_SIZE = 35840;

# Set min shared mem per proc to 3MB -- not needed
#$Apache::GTopLimit::MIN_PROCESS_SHARED_SIZE = 3072;

$Apache::GTopLimit::CHECK_EVERY_N_REQUESTS = 10;

#
# TypeCast libs
#
BEGIN {
    my $BASE = $MT::SixApartBase;
    require lib;
    lib->import(File::Spec->catdir($BASE, 'core', 'lib'));
    require TypeCore::Bootstrap;
    TypeCore::Bootstrap->import(app => 'typecast');
}

## Load this at startup. Will it fix tempfile errors?
use File::Temp;

### Force XML::Simple to do it's startup routines
use XML::Simple ();
my $x = XML::Simple::XMLin("<bleck/>");

### Force typepad.log
MT->log_filename('typecast');

### Randomize the seed
use TypeCore::Util::Crypto ();
Apache->push_handlers(PerlChildInitHandler => sub {
                          srand(unpack('N', TypeCore::Util::Crypto->urandom( Size => 4)));
                      } );

## load the TypeCast app
use TypeCast::App;


1;


