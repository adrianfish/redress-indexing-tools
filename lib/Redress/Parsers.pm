package Redress::Parsers;

=head1 NAME
	Redress::Parsers - contains methods for parsing content, current html and
	pdf.

=head1 SYNOPSIS
	# Parse the html content into a hash containing the metadata key value pairs
	my %metadata = parse_html(\&url,\&content);

	# Parse the pdf content into a hash containing the metadata key value pairs
	my %metadata = parse_pdf(\&url,\&content);

	my $title = $metadata{'title'};
	..etc

=cut

use strict;
use warnings;

use Carp;

use Redress::HtmlParser;
use Redress::PdfParser;
use Redress::MSWordParser;

sub new
{
	carp "Parsers::new called\n";

	my ($class,$args) = @_;

	my $self = {
				HTML_PARSER => Redress::HtmlParser->new($args),
				PDF_PARSER  => Redress::PdfParser->new($args),
				WORD_PARSER  => Redress::MSWordParser->new($args)
				};
				
	bless($self,$class);

	return $self;
}


sub parse
{
	carp "Parsers::parse() called\n";

	my $self = shift;
	my $content = shift;
	my $mimetype = shift;

	#carp $$content;

	my %metadata;

	if($mimetype =~ /text\/html/)
	{
		%metadata = $self->parse_html($content);
	}
	elsif($mimetype =~ /application\/pdf/)
	{
		%metadata = $self->parse_pdf($content);
	}
	elsif($mimetype =~ /application\/msword/)
	{
		%metadata = $self->parse_word($content);
	}
	else
	{
		warn "Unrecognised mime type $mimetype";
	}

	return %metadata;
}
 
=item parse_html

Passes the supplied content (scalar reference) to Redress::HtmlParser. Sets
the identifier key in the returned hash and then then passes the hashref back
to the caller.

Takes a hashref keyed on URL for the url to parse and CONTENT for the content.

Returns a HASH !!!

=cut

sub parse_html
{
	carp "Parsers::parse_html called\n";

	my ($self,$content) = @_;

	unless(defined($content))
	{
		print STDERR "You must supply some content.\n";
		return;
	}

	my $parser = $self->{HTML_PARSER};

	my $metadata = $parser->parse($content);

	carp "Parsers::parse_html finished";

	return %$metadata;
}

=item parse_pdf

 Extracts the metadata from the pdf content and sticks it in a hash. The hash
 is then returned. Takes a scalar for the url, a scalar reference for the
 content and an array reference for the stopwords

=cut

sub parse_pdf
{
	carp "Parsers::parse_pdf called\n";

	my ($self,$content) = @_;

	unless(defined($content))
	{
		print STDERR "You must supply some content.\n";
		return;
	}

	#carp "Content: $$content";

	my $parser = $self->{PDF_PARSER};

	my $metadata = $parser->parse($content);

	return %$metadata;
}

sub parse_word
{
	carp "Parsers::parse_word called\n";

	my ($self,$content) = @_;

	unless(defined($content))
	{
		print STDERR "You must supply some content.\n";
		return;
	}

	carp "Content: $content";

	my $parser = $self->{WORD_PARSER};

	my $metadata = $parser->parse($content);

	return %$metadata;
}

1;
