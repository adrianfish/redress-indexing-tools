#!/usr/bin/perl

use FindBin qw($Bin);;
use lib "$Bin/lib";

use Redress::Categorizer;

my $text = qq(
Here is some sample text about complex things like grid computing. Superfluous.);

my $categorizer = Redress::Categorizer->new();

my $category = $categorizer->categorize(\$text);

print "Category: $category\n";
