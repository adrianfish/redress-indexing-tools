#!/usr/bin/perl

#File: update_metadata.pl

use Carp;

use URI::Escape;

#BEGIN
#{
#	use CGI::Carp qw(carpout);
#	open(LOG , ">>/var/local/cgi-logs/add_content.log")
#		or die "Unable to open log for appending: $!\n";
#
#	carpout(*LOG);
#}

use strict;
use warnings;

use LWP::UserAgent;
use Redress::Parsers;
use Redress::DB;
use CGI qw/:standard -debug/;

my $parsers = Redress::Parsers->new();

# Setup the db connection

my $db = Redress::DB->new('redressadmin','esc1ence');

my $identifier = param('identifier');

carp "Identifier: $identifier";

$identifier = uri_unescape($identifier);

carp "Un-Escaped Identifier: $identifier";

my $title = param('title');
my $subject = param('subject');
my $description = param('description');
my $language = param('language');
my @categories = param('categories');
my $creators = param('creators');
my $publishers = param('publishers');
my $date = param('date');
my $uploader = param('uploader');


# If the pre-requisites have not been supplied, show the form
print_error_and_exit('You must supply an identifier and category') unless(@categories and defined($identifier));

my $ua = LWP::UserAgent->new;
$ua->timeout(5);
#$ua->env_proxy;
$ua->proxy('http', 'http://wwwcache.lancs.ac.uk:80/');

my $redress_difficulty = undef;
my $format = undef;

set_difficulty_and_format($identifier,\$redress_difficulty,\$format);
$format = 'text/html'; # For offline testing only

unless(defined($redress_difficulty))
{
	warn "Failed to get the redress_difficulty, setting it to -1\n";
	$redress_difficulty = -1;
}

unless(defined($format))
{
	print_error_and_exit("The document format (mime type) for $identifier was not set. DB insert cancelled");
}

#eval
#{
	my $update_error = $db->update_metadata({
				IDENTIFIER 			=> $identifier,
				FORMAT 				=> $format,
				TITLE 				=> $title,
				SUBJECT 			=> $subject,
				DESCRIPTION 		=> $description,
				LANGUAGE		=> $language,
				REDRESS_DIFFICULTY 	=> $redress_difficulty,
				PUBLISHERS 			=> $publishers,
				CATEGORIES 			=> \@categories,
				CREATORS 			=> $creators,
				DATE 			    => $date,
				UPLOADER 			=> $uploader,				
				SOURCE				=> 'manual'});

	carp $update_error;

	if($update_error ne 0)
	{
		print_error_and_exit($update_error);
	}
#};

#if($@)
#{
#	carp "Exception caught !!!!!!!";
#	print_error_and_exit($@);
#}

carp "Printing success page ...\n";

print header(),
		start_html('Catalogue Content Successfully Added'),
		a({href => '/index.html'},'Menu'),
		'<br />',
		h2('Content added successfully'),
		a({-href => "show_metadata.pl?identifier=$identifier"},'View'),
		'<br />',
		a({-href => 'show_metadata.pl'},'Add another'),
		end_html;
				
exit 0;

sub set_difficulty_and_format
{
	my ($url,$redress_difficulty,$format) = @_;

	#carp "Getting $url ...";

	my $response = $ua->get($url);

	if($response->is_error)
	{
		print_error_and_exit(sprintf "Failed to retrieve %s. Status: %s.",$url,$response->status_line);
	}

	#carp "Succesfully retrieved $url ...";

	my $ct = $response->header('Content-Type');

	#carp "Content Type: $ct\n";

	$ct =~ /^(\w*\/[\w\.-]*)/i;
	$$format = $1;

	#carp "Format: $$format\n";

	my %metadata_map = ();

	my $content = $response->content;

	if($$format eq 'text/html')
	{
		#carp "HTML";

		%metadata_map = $parsers->parse_html(\$content); # Ditto
	}
	elsif($$format eq 'application/pdf')
	{
		#carp "PDF\n";

		%metadata_map = $parsers->parse_pdf(\$content);
	}
	else
	{
		#print_error_and_exit("Unhandled type: $$format.");
		carp "Unhandled type: $$format.";
	}

	$$redress_difficulty = $metadata_map{'redress_difficulty'};
}

sub print_error_and_exit
{
	my $message = shift;

	print header,
			start_html('Error'),
			h3("Error: $message"),
			end_html;

	exit 1;
}
