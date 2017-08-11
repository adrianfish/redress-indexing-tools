#!/usr/bin/perl -w

use strict;
use warnings;
#
use Redress::Reports;
use CGI qw/:standard -debug/;

use Carp;

my $reports = Redress::Reports->new();

my $data;

my $chart = $reports->create_harvested_chart(\$data);

print header(-type => 'image/png');

binmode STDOUT;
print $data;

exit 0;
