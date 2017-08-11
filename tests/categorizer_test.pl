#!/usr/bin/perl

use strict;

use FindBin qw($Bin);
use lib "$Bin/lib";

use HTML::Parser;

use Redress::Utils;

# Get the filename from the first argument.
my $filename = $ARGV[0];

unless(-r $filename)
{
	die "Usage: categorizer_test.pl test_file";
}

print "Filename: $filename.\n";

$filename =~ /\.(\w+)$/;

my $type = $1;

unless($type =~ /htm/i or $type =~ /pdf/i)
{
	print "Only html or pdf currently handled.\n";
	exit 1;
}

# Set by the html parser's text handler
my $document_text;

do_html() if($type =~ /htm/i);
do_pdf() if($type =~ /pdf/i);

my $category = get_best_category(\$document_text);

print "Category: $category\n";

exit 0;

sub do_html
{
	open DOC , $filename;

	print <DOC>;

	my $content = '';

	$content .= $_ while(<DOC>);

	close DOC;

	# Setup the HTML parser
	my $html_parser = HTML::Parser->new(api_version => 3,
									text_h => [	sub
												{
													$document_text .= shift;
												}
												,"dtext"]);

	$html_parser->parse($content);
}

sub do_pdf
{
	$document_text = readpipe("pdftotext $filename -");
}

