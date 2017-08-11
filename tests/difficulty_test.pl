#!/usr/bin/perl

use Redress::DifficultyEstimator;

my $text = qq(
Here is some sample text about complex things like grid computing. Superfluous.);

my $estimator = Redress::DifficultyEstimator->new();

my $redress_difficulty = $estimator->estimate(\$text);

print "Difficulty: $redress_difficulty\n";
