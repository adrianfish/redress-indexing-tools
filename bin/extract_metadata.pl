#!/usr/bin/perl
#
use strict;
use warnings;

use Redress::Parsers;
use Getopt::Long;

my $filename = 'test.pdf';

my $result = GetOptions("f=s" => \$filename);

my $mimetype = 'application/pdf';

if($filename =~ /\.pdf$/)
{
	$mimetype = 'application/pdf';
}
elsif($filename =~ /\.htm.?$/)
{
	$mimetype = 'text/html';
}
elsif($filename =~ /\.doc$/)
{
	$mimetype = 'application/msword';
}
else
{
	die "Unrecognized file suffix on $filename";
}

die "$filename is unreadable!" unless( -r $filename);

open TESTFILE , $filename;
local $/; # Slurp mode
my $contents = <TESTFILE>;
close TESTFILE;

#print $contents;
my $parser = Redress::Parsers->new({ CATEGORIZE => 1,TYPE => 'SVM' });

my %metadata = $parser->parse(\$contents,$mimetype);

#print $metadata;

foreach my $label (keys %metadata)
{
	my $value = $metadata{$label};

	if($value =~ /ARRAY/)
	{
		foreach my $element (@$value)
		{
			print "$label = $element\n";
		}
	}
	else
	{
		print "$label = $value\n";
	}
}
