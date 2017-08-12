#!/usr/bin/env perl
use strict;
use warnings;
use 5.010;

use Test::Simple tests => 3;

my @usage = `sh virtualmin-install.sh --help`;
ok( grep { /^Usage:/ } @usage );

@usage = `sh virtualmin-install.sh -h`;
ok( grep { /^Usage:/ } @usage );

@usage = `sh virtualmin-install.sh --invalid-option`;
ok( grep { /^Usage:/ } @usage );
