package Redress::MSWordParser;

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

	my $document_text = $self->get_text($content);

	$self->{TEXT} = $document_text;

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

	carp "Redress::MSWordParser::get_text()\n";

	unless(defined($content))
	{
		if(defined($self->{TEXT}))
		{
			return $self->{TEXT};
		}
		else
		{
			warn "No content supplied to MSWordParser::get_text\n";
			return \'';
		}
	}

	open(TESTDOC,'+>/tmp/test.doc') or return \'';
	binmode(TESTDOC);
    print TESTDOC $$content;
    close TESTDOC;

	unless( -r '/tmp/test.doc')
	{
		print STDERR "/tmp/test.doc is not readable or does not exist\n";
		return $self->{METADATA};
	}

	unless( -x '/usr/bin/lhalw')
	{
		print STDERR "/usr/bin/lhalw not found on this system\n";
		return \'';
	}

	# Call lhalw and grab the dumped file's contents
	system("/usr/bin/lhalw /tmp/test.doc") == 0 or die "lhalw returned an error code";

	# Now slurp the resulting file in and return the contents
	open(TEXTFILE,'test.txt');
	local $/; # Slurp mode !
	my $text = <TEXTFILE>;

	close(TEXTFILE);
	return \$text;
}

1;
