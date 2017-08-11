#!/usr/bin/perl

use FindBin qw($Bin);
use lib "$Bin/lib";

use Redress::Utils;

my %stopwords = load_stopwords();
#my %stopwords = load_stopwords();

foreach my $word (keys(%stopwords))
{
	print $word;
}
