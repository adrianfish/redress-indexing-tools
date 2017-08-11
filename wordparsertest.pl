#!/usr/bin/perl -w

use strict;
use warnings;

use Redress::MSWordParser;

use Getopt::Long;

my $filename;
my $categorizing = 0;

my $result = GetOptions("f=s" => \$filename,
                        "c=i" => \$categorizing);

die "Usage: wordparsertest.pl -f file [-c [0,1]]\n" unless (defined($filename));

open(DOC,$filename);
binmode DOC;
local $/;
my $contents = <DOC>;
close DOC;

my $wp = Redress::MSWordParser->new( { CATEGORIZE => $categorizing } );

my $metadata = $wp->parse(\$contents);

my $text = $wp->get_text();

my $categories = $metadata->{'categories'};

printf "Category: %s\n" , join('|',@$categories);

#printf "TEXT:\n%s\n" , $$text;

exit 0;
