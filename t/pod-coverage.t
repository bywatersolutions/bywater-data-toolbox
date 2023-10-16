#!/usr/bin/perl

use Modern::Perl;

use Test::More;
use Test::Pod::Coverage;

use FindBin;
use lib "$FindBin::Bin/..";

use Module::Find;

my @found = useall ToolBox::Mungers;

plan tests => scalar @found;
pod_coverage_ok( $_, "$_ is covered" ) for @found;
