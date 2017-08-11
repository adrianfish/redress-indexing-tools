package Redress::PdfParser;

use strict;
use warnings;

use Carp;

use Redress::DifficultyEstimator;
use Redress::Categorizer;

sub new
{
	my ($class,$args) = @_;

	my $self = {
				METADATA => {},
				ESTIMATOR => Redress::DifficultyEstimator->new()
				};

	bless($self,$class);

	if(defined($args->{CATEGORIZE}) and $args->{CATEGORIZE} eq 1)
	{
		$self->{CATEGORIZER} = Redress::Categorizer->new();
	}

	return $self;
}

sub parse
{
	my ($self,$content) = @_;

	unless(defined($content))
	{
		print STDERR "You must supply some content.\n";
		return;
	}

	#carp "CONTENT: $$content";

	# Seed the random number generator
	srand(time() ^($$ + ($$ <<15)));

	# Create a 'unique' file path for the pdf file
	my $filepath = '/tmp/' . rand() . '.pdf';

	my $document_text = $self->get_text($content,$filepath);

	my $redress_difficulty = $self->{ESTIMATOR}->estimate($document_text);

	carp "Redress Difficulty: $redress_difficulty";

	$self->{METADATA}->{'redress_difficulty'} = $redress_difficulty;

	if($self->{CATEGORIZER})
	{
		my $categories = $self->{CATEGORIZER}->categorize($document_text);
		#carp "Category: $category";
		
		# Set the category label
		#my @categories = ($category);

		$self->{METADATA}->{'categories'} = $categories;
		#$parser->{METADATA}->{'categories'} = \@categories;
	}

	# Call pdfinfo (from Xpdf suite) and grab the output
	my $info = readpipe "pdfinfo $filepath";

	# Delete the file
	unlink $filepath;

	$info =~ /^Title:\s*(.*)$/i;
	$self->{METADATA}->{'title'} = $1;

	$info =~ /^Keywords:\s*(.*)$/i;
	$self->{METADATA}->{'subject'} = $1;

	$info =~ /^Creator:\s*(.*)$/i;
	$self->{METADATA}->{'author'} = $1;

	$info =~ /^CreationDate:\s*(.*)$/i;
	$self->{METADATA}->{'date'} = $1;

	# NOTE: Can we get the citations from PDFs?

	return $self->{METADATA};
}

sub get_text
{
	my ($self,$content,$filepath) = @_;

	carp "Redress::PdfParser::get_text()\n";

	unless(defined($filepath))
	{
		# Seed the random number generator
		srand(time() ^($$ + ($$ <<15)));

		# Create a 'unique' file path for the pdf file
		$filepath = '/tmp/' . rand() . '.pdf';
	}

	open(TESTPDF,"+>$filepath");
	binmode(TESTPDF);
    	print TESTPDF $$content;
    	close TESTPDF;

	unless( -r $filepath)
	{
		print STDERR "$filepath is not readable or does not exist\n";
		return \'';
	}

	unless( -x '/usr/bin/pdftotext')
	{
		print STDERR "/usr/bin/pdftotext not found on this system\n";
		return \'';
	}

	# Call pdftotext (from Xpdf suite) and grab the output
	my $text = readpipe "/usr/bin/pdftotext $filepath -";


	return \$text;
}

1;
