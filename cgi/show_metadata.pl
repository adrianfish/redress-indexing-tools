#!/usr/bin/perl -w

#File: add_content.pl

use Carp;

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

# Setup the db connection

my $db = Redress::DB->new('redressadmin','esc1ence');

my $identifier = param('identifier');
#$identifier='http://redress.lancs.ac.uk';

unless(defined($identifier))
{
	$identifier = 'new_url';
	print_form();
}

my ($result , %metadata) = $db->get_metadata_for_url($identifier);

unless ($result eq 0)
{
	print_error_and_exit($result);
}

my $language = '';

# If the pre-requisites have not been supplied, show the form
#print_form() if defined($identifier);
print_form();

exit 0;

sub print_error_and_exit
{
	my $message = shift;

	print header,
			start_html('Error'),
			h3("Error: $message"),
			end_html;

	exit 1;
}

sub print_form
{
	my @all_categories = $db->get_possible_category_names();
	
	my $creators = $metadata{'creators'};
	
	my $publishers = $metadata{'publishers'};

	#printf "title: %s\n",$metadata{'title'};
	#printf "subject: %s\n",$metadata{'subject'};
	#printf "description: %s\n",$metadata{'description'};
	#printf "format: %s\n",$metadata{'format'};
	#printf "redress_difficulty: %d\n",$metadata{'redress_difficulty'};
	#printf "creators: %s\n",$creators;
	#printf "publishers: %s\n",$publishers;
	#
	my $categories = [];

	if(defined($metadata{'categories'}))
	{
		$categories = $metadata{'categories'};
	}

	#foreach my $category (@$categories)
	#{
	#	print "Selected Category: $category\n";
	#}

	print header(),
			start_html('Catalogue Content Form'),
			a({href => '/index.html'},'Menu'),
			'<br />',
			h1("Metadata for $identifier"),
			'<i>Required fields are marked with an *</i>',
			'<br /><br />',
			start_form(-method => 'POST',
						-action => 'update_metadata.pl'),
			'Url:        ',textfield(-name => 'identifier',-default => $identifier),' *',
			'<br /><br />',
			'Title:      ',textfield(-name => 'title',-default => $metadata{'title'}),
			'<br /><br />',
			'Keywords:   ',textfield(-name => 'subject',-default => $metadata{'subject'}),
			'<br /><br />',
			'Language:   ',textfield(-name => 'language',-default => $metadata{'language'}),
			'<br /><br />',
			'Description:',
			'<br />',
			textarea(-name => 'description', -default => $metadata{'description'},-cols => 40),
			'<br /><br />',
			'Enter the name(s) of the author(s) in last,first format. Separate them by a | character.',
			'<br />',
			textfield(-name => 'creators',-default => $creators),
			'<br />',
			'<br />',
			'Enter the name(s) of the publisher(s). Separate them by a | character.',
			'<br />',
			textfield(-name => 'publishers',-default => $publishers),
			'<br />',
			'<br />',
			'Categories: *',
			'<br />',
			scrolling_list(-name => 'categories',
							-values => \@all_categories,
							-defaults => $categories,
							-size => 10,
							-multiple => 'true'),
			'<br />',
			'<br />',
			'Uploader:   ',textfield(-name => 'uploader',-default => $metadata{'uploader'}),
			'<br />',
			'<br />',
			'Leave blank if a new resource or update if desired.',
			'<br />',
			'Date:   ',textfield(-name => 'date',-default => $metadata{'date'}),
			'<br /><br />',
			'<br />',
			submit('Update Metadata'),
			end_form,
			end_html;

	exit 0;
}
