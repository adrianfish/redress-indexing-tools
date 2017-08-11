#!/usr/bin/perl -w

use strict;
#
use Redress::Reports;
use CGI qw/:standard -debug/;

use Carp;

my $htmlbase = undef;
my $reportdir = undef;

open PROPS,'reports.properties';

while(<PROPS>)
{
	next if(/^#.*$/ or /^$/);

	my @pair = split('=');
	die "Invalid properties file" unless(scalar(@pair) eq 2);

	$reportdir = $pair[1] if($pair[0] eq 'reportdir');
	$htmlbase = $pair[1] if($pair[0] eq 'htmlbase');
}

close PROPS;

unless(defined($reportdir) and defined($htmlbase))
{
	print_error_and_exit("Unable to initialise 'reportdir' variabl from properties file.");
}

chomp($reportdir);
chomp($htmlbase);

my $reports = Redress::Reports->new();

my $catalogue_chart;
$reports->create_catalogue_chart(\$catalogue_chart);
my $catalogue_file = "$reportdir/catalogue.png";
open(CATALOGUE,"+>$catalogue_file");
binmode CATALOGUE;
print CATALOGUE $catalogue_chart;
close(CATALOGUE);

my $harvested_chart;
$reports->create_harvested_chart(\$harvested_chart);
my $harvested_file = "$reportdir/harvested.png";
open(HARVESTED,"+>$harvested_file");
binmode HARVESTED;
print HARVESTED $harvested_chart;
close(HARVESTED);

print header(-type => 'text/html'),
		start_html(-head => meta({-http_equiv => 'refresh',-content => '5'}),
					-title => 'Charts',
					-xbase => $htmlbase),
		h3({-align => 'center'},'This page is refreshed every 5 seconds'),
		'<br />',
		img({-src => 'catalogue.png'}),
		img({-src => 'harvested.png'}),
		end_html();

exit 0;

sub print_error_and_exit
{
	my $message = shift;

	print header(),
			start_html('Error'),
			h1($message),
			end_html();

	exit 0;
}
