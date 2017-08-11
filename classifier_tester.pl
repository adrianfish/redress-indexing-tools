#!/usr/bin/perl
#
use strict;
use warnings;

use LWP::UserAgent;
use URI;
use Redress::Parsers;
use Redress::DB;

use CGI;

use Getopt::Long;

my $parsers = Redress::Parsers->new({ CATEGORIZE => 1, TYPE => 'KNN' });

my $db = Redress::DB->new('redressadmin','esc1ence');

# Create a ReDReSS agent
my $ua = LWP::UserAgent->new('ReDReSS Metadata Indexer');
$ua->timeout(30);
$ua->env_proxy;

my $map = $db->get_category_document_map();

my @blacklist = ('Introductory Material and Support','Examples from e-Social Science Projects','Agenda Setting Workshops','UK e-Science Programme','Motivation and Background','Social Shaping');

foreach my $category (keys %$map)
{
	if(grep(/$category/,@blacklist))
	{
		# Crap category
		print "Skipping crap category: $category ...\n";
		next;
	}

	#print "Category: $category\n";

	my $document_map = $map->{$category};

	foreach my $identifier (keys %$document_map)
	{
		#print "Document: $identifier\n";

		next unless($identifier ne '0');

		my $metadata = get_metadata(URI->new($identifier));

		next unless defined($metadata);

		#foreach my $label (keys %$metadata)
		#{
	#		printf "$label=%s\n",$metadata->{$label};
		#}

		my $categories = $metadata->{'categories'};

		my $classified_as = join('|',@$categories);

		if(defined($classified_as) and ($classified_as =~ $category))
		{
			print "SUCCESS on $identifier: Catalogue Category: $category. Classified as: $classified_as\n";
		}
		else
		{
			print "FAILURE on $identifier: Catalogue Category: $category. Classified as: $classified_as\n";
		}
	}
}

exit 0;

sub get_metadata
{
	my $uri = shift;

	# Extract the scheme and hostname portions of the url
	my $scheme = $uri->scheme;

	if($scheme ne 'http')
	{
		print "Scheme $scheme not permitted. Skipping $uri ...\n";
		return;
	}

	my $host = $uri->host;
	my $path = $uri->path;
	my $fragment = $uri->fragment;

	my $url = $uri->as_string;

	# Issue the HTTP request
	my $response = $ua->get($url);

	if($response->is_error)
	{
		#printf ("Failed to get contents for url %s. Status : %s. Skipping ...\n",$url,$response->status_line); 
		return;
	}

	my $content_type = $response->content_type;

	$content_type =~ /^(\w*\/[\w\.-]*)/i;

	my $format = $1;

	my $content = $response->content;

	my %metadata = ();

	if($content_type =~ /text\/html/)
	{
		%metadata = $parsers->parse_html(\$content);
	}
	elsif($content_type =~ /application\/pdf/)
	{
		%metadata = $parsers->parse_pdf(\$content);
	}
	else
	{
		warn "$content_type not handled (yet!). Returning ...\n";
		return;
	}

	$metadata{'identifier'} = $url;
	$metadata{'format'} = $format;

	return \%metadata;
}

exit 0;
