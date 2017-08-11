package Redress::PowerpointParser;

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

	my $document_text = get_text($content);

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
	#my $info = readpipe "pdfinfo test.pdf";

	#$info =~ /^Title:\s*(.*)$/i;
	#$self->{METADATA}->{'title'} = $1;

	#$info =~ /^Keywords:\s*(.*)$/i;
	#$self->{METADATA}->{'subject'} = $1;

	#$info =~ /^Creator:\s*(.*)$/i;
	#$self->{METADATA}->{'author'} = $1;

	#$info =~ /^CreationDate:\s*(.*)$/i;
	#$self->{METADATA}->{'date'} = $1;

	# NOTE: Can we get the citations from PDFs?

	return $self->{METADATA};
}

sub get_text
{
	my ($self,$content) = @_;

	# Get the container flag

	carp "Redress::PowerpointParser::get_text()\n";

	carp "Content: $content\n";

	$self->{TEXT} = '';
	$self->find_text_records($content,0);

	my $text = $self->{TEXT};

	return \$text;
}

sub find_text_records
{
	# 8 byte record header format
	#
	# container_flag | option_field | record_type | record_length
	#     4 bits     |     12 bits  |   16 bits   |    32 bits
	#

	my ($self,$content,$start) = @_;

	my $data = substr($$content,$start);

	# Get the first 4 bits. This indicates whether this is a container or atom
	if($data & 0x0f)
	{
		# It is a container. Find the end of it and recurse.
		# Move the cursor by 8 bytes
		$start = $start << 64;
		find_text_records($content,$start);
	}
	else
	{
		# It is an atom. Skip the next 12 bits as they have the vague 'option' data
		if(($data << 16) & 0x4418) # 0x4418 is the hex code for a text record
		{
			# This is a text record. Get the length
			my $length
		}
	}
}

1;
