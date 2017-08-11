#!/usr/bin/perl

=head1 IMS Content Package Generator
A CGI script that generates a IMS Content Packaging XML document using document
references from the database, based on criteria supplied in the params. It
searches across, and aggregates results from, both the catalogue_content and
web content databases.
=cut

use strict;
use warnings;
use Redress::Searcher;
use Redress::DB;
use CGI qw/:standard -debug/;

my $type = param('type');
unless(defined($type)) { $type = 'text'; }

my $title = param('title');
my $creator = param('creator');
my $description = param('description');
my $publisher = param('publisher');
my $subject = param('subject');
my $category = param('category');

#$keywords = 'administration';

unless(defined($subject) or defined($category))
{
	print_form();
}

my $searcher = Redress::Searcher->new('redressadmin','esc1ence');

# Returns an array of hashrefs
my @records = $searcher->search({
								'title' => $title,
								'creator' => $creator,
								'description' => $description,
								'publisher' => $publisher,
								'subject' => $subject,
								'category' => $category
								});

if($type eq 'xml')
{
	my $xml = qq(<?xml version="1.0" encoding="UTF-8"?>
<xml xmlns="http://www.imsglobal.org/xsd/imscp_v1p1"
		xmlns:dc="http://www.dcmi.org/dtd"
		xmlns:rd="http://e-science.lancs.ac.uk/redress">);

	my $organizations = qq(
	<organizations>
		<organization>);

	my $resources = qq(
	<resources>);

	my $resource_index = 1;

	foreach my $record (@records)
	{
		# Swap & for its entitity. Otherwise XML parser will complain
		my $url = convert($record->{'identifier'});

		$organizations .= qq(
			<item identifier="ITEM.$resource_index" identifierref="RESOURCE.$resource_index"/>
			);

		$resources .= qq(
		<resource name="RESOURCE.$resource_index" type="webcontent" href="$url">
			<metadata>
			);

		if(defined($record->{'title'}))
		{
			my $title = convert($record->{'title'});
			$resources .= qq(
				<dc:title>$title</dc:title>);
		}

		if(defined($record->{'subject'}))
		{
			my $subject = convert($record->{'subject'});
			$resources .= qq(
				<dc:subject>$subject</dc:subject>);
		}

		if(defined($record->{'description'}))
		{
			my $description = convert($record->{'description'});
			$resources .= qq(
				<dc:description>$description</dc:description>);
		}

		if(defined($record->{'format'}))
		{
			$resources .= qq(
				<dc:format>$record->{'format'}</dc:format>);
		}

		if(defined($record->{'language'}))
		{
			$resources .= qq(
				<dc:language>$record->{'language'}</dc:language>);
		}

		if(defined($record->{'redress_difficulty'}))
		{
			$resources .= qq(
				<rd:difficulty>$record->{'redress_difficulty'}</rd:difficulty>);
		}

		if(defined($record->{'ims_difficulty'}))
		{
			$resources .= qq(
				<imsmd:difficulty>$record->{'ims_difficulty'}</imsmd:difficulty>);
		}

		$resources .= qq(
			</metadata>
		</resource>);

		$resource_index++;
	}

	$organizations .= qq(
		</organization>
	</organizations>);

	$resources .= qq(
	</resources>);

	$xml .= qq(
		$organizations
	$resources
</xml>);

	print header(-type => 'text/xml',
						-status => '200',
						-Content_length => length($xml));

	print $xml;
}
elsif($type eq 'text')
{
	my $text = "";

	foreach my $record (@records)
	{
		my $url = $record->{'identifier'};
		$text .= $url;

		if($record ne $records[-1]) { $text .= '|'; }
	}

	print header(-type => 'text/plain',
						-status => '200',
						-Content_length => length($text));

	print $text;
}
elsif($type eq 'html')
{
	my $html = start_html('Search Results') 
					. h2('Search Results') 
					. a({href => '/cgi-bin/build_tutorial.pl'},'Search Again')
					. "\n<br /><br />\n";

	foreach my $record (@records)
	{
		my $url = $record->{'identifier'};
		$html .= a({href => $url},$url) . "\n<br />\n";
	}

	$html .= end_html();

	print header(-type => 'text/html',
						-status => '200',
						-Content_length => length($html));

	print $html;
}
else
{
	print header(-type => 'text/html',
					-status => '400 Bad Request'),
			start_html('Tutorial Builder - Bad Request'),
			h3("400 Bad Request. Type $type is unrecognised"),
			end_html();
}

exit 0;

sub convert
{
	my $source = shift;

	$source =~ s/&/&amp;/g;

	return $source;
}

sub print_form
{
	my $db = Redress::DB->new('redressadmin','esc1ence');

	my @categories = $db->get_category_names;

	print header,
			start_html('Tutorial Builder'),
			h1('Tutorial Builder'),
			'<i>Please specify at least one criterion</i>',
			'<br /><br />',
			start_form(-method => 'POST',
						-action => 'build_tutorial.pl'),
			'Title:',textfield('title'),
			'<br /><br />',
			'Description:',textfield('description'),
			'<br /><br />',
			'Creator:',textfield('creator'),
			'<br /><br />',
			'Publisher:',textfield('publisher'),
			'<br /><br />',
			'Keywords (space separated) :' ,textfield('subject'),
			'<br /><br />',
			'Select the category of document that you are looking for:',
			'<br />',
			scrolling_list(-name => 'category',
							-values => \@categories,
							-size => 10,
							-multiple => 'false'),
			'<br /><br />',
			'Response Type:',popup_menu(-name => 'type',
						-values => ['xml','html','text']),
			'<br /><br />',
			submit('Build'),
			end_form(),
			end_html();

	exit 0;
}
