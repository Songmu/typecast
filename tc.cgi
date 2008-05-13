#!perl
use strict;
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/lib"    : 'lib';
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/mtlib"  : 'mtlib';
use MT::Bootstrap App => 'TypeCast::App';
