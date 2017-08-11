#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/lib";

use Redress::Utils;

my @acronyms = load_acronyms();

foreach my $acronym (@acronyms)
{
	print $acronym;
}
