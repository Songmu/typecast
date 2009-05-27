#!/usr/bin/env perl
use strict;
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/lib"       : 'lib';
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/extlib"    : 'extlib';
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/mt/lib"    : 'mt/lib';
use lib $ENV{TC_HOME} ? "$ENV{TC_HOME}/mt/extlib" : 'mt/extlib';
use MT::Bootstrap App => 'TypeCast::App';
