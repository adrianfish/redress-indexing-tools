package Redress::HtmlParser;

use strict;
use warnings;

use HTML::Parser;

#use vars qw(@ISA);

#@ISA = ("HTML::Parser");

use Carp;
use Redress::DifficultyEstimator;
use Redress::Categorizer;

# Extract citations for later analysis ???

# Supply the single argument of 1 if you want the parser to also categorize
sub new
{
	my ($class,$args) = @_;

	my $self = {};

	bless($self,$class);

	$self->{PARSER} = HTML::Parser->new(api_version => 3,
						start_h => [\&start,"tagname,attr,self"],
						end_h => [\&end,"tagname,self"],
						text_h => [\&text,"dtext,self"]
						);

	#$self->{PARSER} = HTML::Parser->new(api_version => 3,
	#					start_h => [ sub { carp shift; } ,"tagname,attr"]);

	#carp "Redress::HtmlParser::new called\n";
	#
	#

	carp sprintf "Self: %s\n",ref($self);

	# Flag used during html parsing so that text callback can add the contents
	# of the <title> tag as the title metadata label. This label will be
	# overwritten wwith the contents of a <meta tag with the DC.title name, if
	# found.
	#$self->{TITLE_FLAG} = 0;
	#$self->{TEXT} = '';
	#$self->{METADATA} = {};
	#$self->{ESTIMATOR} = Redress::DifficultyEstimator->new();

	$self->{PARSER}->{TITLE_FLAG} = 0;
	$self->{PARSER}->{TEXT} = '';
	$self->{PARSER}->{METADATA} = {};
	$self->{PARSER}->{ESTIMATOR} = Redress::DifficultyEstimator->new();

	if(defined($args->{CATEGORIZE}) and $args->{CATEGORIZE} eq 1)
	{
		#$self->{CATEGORIZER} = Redress::Categorizer->new();
		$self->{PARSER}->{CATEGORIZER} = Redress::Categorizer->new($args->{TYPE});
	}

	#$self->SUPER::init();

	return $self;
}

=item parse

 Extracts the metadata from the html content (passed by reference) and sticks
 it in a hash. The hash is then returned.

=cut

sub parse
{
	carp "Redress::HtmlParser::parse called";

	#my ($self,$content) = @_;
	my $self = shift;

	if(@_)
	{
		my $content = shift;

		#my $derefcontent = $$content;

		#carp "Content: START $$content END";

		#$self->{TEXT} = '';
		#$self->{METADATA} = {};

		$self->{PARSER}->{TEXT} = '';
		$self->{PARSER}->{METADATA} = {};

		#$self->SUPER::parse($$content);
		$self->{PARSER}->parse($$content);
	}

	#carp "Calling parse on parser ...";
	#$self->{PARSER}->parse($$content);
	#$self->parse($$content);

	carp "Redress::HtmlParser::parse finished";

	return $self->{PARSER}->{METADATA};
}

# Text handler for HTML::Parser
sub text
{
	my ($text,$self) = @_;

	chomp $text;

	if($self->{TITLE_FLAG} eq 1)
	{
		$self->{METADATA}->{'title'} = $text;
	}
	else
	{
		$self->{TEXT} .= $text;
	}
}

# Start handler for HTML::Parser
sub start
{
	my ($tagname,$attr,$parser) = @_;

	if($tagname eq 'title')
	{
		# We set this so that the text handler can set the title metadata label
		$parser->{TITLE_FLAG} = 1;
	}

	if($tagname eq 'meta')
	{
		my $name = $attr->{name};

		unless(defined($name))
		{
			carp "No name attribute for <meta> tag. Skipping meta tag ...";
			return;
		}

		if($name eq 'keywords')
		{
			my $content = $attr->{content};

			unless(defined($content))
			{
				carp "No content attribute for <meta> tag. Skipping ...\n";
				return;
			}

			$parser->{METADATA}->{'subject'} = $content;
		}
		
		# Dublin core block to handle metadata elements with the DC.labelname
		# name format
		if($name =~ /^DC\.([a-zA-Z]+)$/i)
		{
			my $content = $attr->{content};

			unless(defined($content))
			{
				carp "No content attribute for <meta> tag. Skipping ...";
				return;
			}

			#print "name=\"$1\" content=\"$content\"/>\n";

			if($1 eq 'subject')
			{
				if(defined($parser->{METADATA}->{'subject'}))
				{
					$parser->{METADATA}->{'subject'} .= $content;
				}
			}
			elsif($1 eq 'creator')
			{
				unless(defined($parser->{METADATA}->{'creators'}))
				{
					$parser->{METADATA}->{'creators'} = [];
				}

				my $creators = $parser->{METADATA}->{'creators'};
				push(@$creators,$content);
			}
			elsif($1 eq 'publisher')
			{
				unless(defined($parser->{METADATA}->{'publishers'}))
				{
					$parser->{METADATA}->{'publishers'} = [];
				}

				my $publishers = $parser->{METADATA}->{'publishers'};
				push(@$publishers,$content);
			}
			elsif($1 eq 'bibliographicCitation')
			{
				unless(defined($parser->{METADATA}->{'citations'}))
				{
					$parser->{METADATA}->{'citations'} = [];
				}

				my $citations = $parser->{METADATA}->{'citations'};
				push(@$citations,$content);
			}
			else
			{
				$parser->{METADATA}->{"$1"} = $content;
			}
		}
	}
}

# End tag handler for HTML::Parser
sub end
{
	my ($tagname,$parser) = @_;

	$parser->{TITLE_FLAG} = 0 if($tagname eq 'title');

	return unless($tagname eq 'html');

	my $document_text = $parser->{TEXT};

	my $redress_difficulty = $parser->{ESTIMATOR}->estimate(\$document_text);

	carp "Redress Difficulty: $redress_difficulty";

	$parser->{METADATA}->{'redress_difficulty'} = $redress_difficulty;

	# Sometimes we may not want to categorize. When we are parsing documents from
	# the training set for example.
	if($parser->{CATEGORIZER})
	{
		my $categories = $parser->{CATEGORIZER}->categorize(\$document_text);
		#carp "Category: $category";
		
		# Set the category label
		#my @categories = ($category);

		$parser->{METADATA}->{'categories'} = $categories;
		#$parser->{METADATA}->{'categories'} = \@categories;
	}
}

sub get_text
{
	my ($self,$content) = @_;

	carp "Redress::HtmlParser::get_text()\n";

	$self->parse($content);

	my $text = $self->{PARSER}->{TEXT};

	#carp "Text: $text\n";

	return \$text;
}

1;
