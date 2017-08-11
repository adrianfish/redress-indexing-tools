#!/usr/bin/perl

#File: catalogue_importer.pl

use strict;

use XML::Parser;
#use DBI;
use LWP::UserAgent;
use Redress::Parsers;
use Redress::Utils;
use Redress::DifficultyEstimator;
use Redress::DB;

use CGI qw/:standard/;

use Carp;

use Getopt::Long;

my $catalogue_file = 'redress_catalogue.xml';

GetOptions("f=s" => \$catalogue_file);

unless (-r $catalogue_file)
{
	print "$catalogue_file must be readable\n";
	exit 1;
}

my @broken_links = ();

my $parsers = Redress::Parsers->new();

# Setup the db connection
my $db = Redress::DB->new('redressadmin','esc1ence');
my $dbh = $db->get_db_handle;

$db->delete_catalogue;

my $ua = LWP::UserAgent->new;
$ua->timeout(5);
$ua->env_proxy;

my $estimator = Redress::DifficultyEstimator->new();

my $current_category = 'none';

my $in_content = 0;my $in_identifier = 0;my $in_title = 0;my $in_creator = 0;my $in_publisher = 0;my $in_description = 0;my $in_language = 0;my $in_subject = 0;my $in_difficulty = 0;

my $identifier = '';my $title = '';my $subject = '';my $description = '';my $language = '';my $difficulty = '';
my @creator_list = ();
my @publisher_list = ();

my @path = ();

my $parser = XML::Parser->new(Handlers => {Start => \&start_handler,
											Char => \&char_handler,
											End => \&end_handler});

$parser->parsefile($catalogue_file);

# Now import the additional material from more_catalogue_content.txt
open MORE_FILE , 'more_catalogue_content.txt';

while(<MORE_FILE>)
{
	chomp;

	split /\$/;
	my $url = $_[0];

	my $response = $ua->get($url);

	if($response->is_error)
	{
		carp(sprintf "%s failed. Status: %s\n",$url,$response->status_line);
		push(@broken_links,$url);
		next;
	}

	my $redress_difficulty = undef;
	my $format = undef;

	set_difficulty_and_format($url,\$response,\$redress_difficulty,\$format);

	my $sql = "INSERT INTO content (identifier,format,title,description,subject,language,ims_difficulty,redress_difficulty,source) values('$url','$format','$title','$description','$subject','$language','$difficulty',$redress_difficulty,'manual')";
	#print "$sql\n";
	$dbh->do($sql);

	# Get the id set by the sequence
	my @id_row = $dbh->selectrow_array("SELECT currval('content_content_id_seq')");
	my $catalogue_content_id = $id_row[0];

	my @categories = split /\|/ , $_[1];

	foreach my $category (@categories)
	{
		print "Category: $category\n";
		my $statement = "SELECT category_id FROM category WHERE name = '$category'";
		#print "$statement\n";

		my @category_id_row = $dbh->selectrow_array($statement);
		my $category_id = $category_id_row[0];
		my $sql = "INSERT INTO content_category values($catalogue_content_id,$category_id)";
		#print "SQL: $sql\n";
		$dbh->do($sql);
	}
}

close MORE_FILE;

$dbh->disconnect();

open(BROKEN,'>broken.txt');

print BROKEN start_html('Broken Catalogue Links'),
				h2('Broken Catalogue Links');

foreach my $broken (@broken_links)
{
	print BROKEN a({href => $broken},$broken),'<br />';
}

print BROKEN end_html();

close(BROKEN);

exit 0;

sub start_handler
{
	my $element = $_[1];

	if($element eq 'category')
	{
		my $name = $_[3];
		my $category_description = $_[5];

		#print "Category Name: $name\n";

		$dbh->do("INSERT INTO category (name,category_description) values('$name','$category_description')");

		my @row = $dbh->selectrow_array("SELECT currval('category_category_id_seq')");

		my $child_id = $row[0];

		#print "Child ID: $child_id\n";

		#The last node on the path, if defined, must be the parent
		my $parent_category = $path[-1];

		if(defined($parent_category))
		{
			#print "The parent category of $name is $parent_category\n";
			
			@row = $dbh->selectrow_array("SELECT category_id FROM category WHERE name = '$parent_category'") or die "Shit!";

			my $parent_id = $row[0];
			#print "Parent ID: $parent_id\n";
			$dbh->do("INSERT INTO category_hierarchy values($parent_id,$child_id)");
		}

		$current_category = $name;

		push(@path,$name);
	}

	$in_content = 1 if($element eq 'content');

	$in_identifier = 1 if($element eq 'dcmi:identifier');

	$in_title = 1 if($element eq 'dcmi:title');

	$in_description = 1 if($element eq 'dcmi:description');

	$in_subject = 1 if($element eq 'dcmi:subject');

	$in_creator = 1 if($element eq 'dcmi:creator');

	$in_publisher = 1 if($element eq 'dcmi:publisher');

	$in_language = 1 if($element eq 'dcmi:language');

	$in_difficulty = 1 if($element eq 'imsmd:difficulty');

	#print "Element: $element\n";
}

sub end_handler
{
	my $element = $_[1];

	pop(@path) if($element eq 'category');

	if($element eq 'content')
	{
		#print "Identifier: $identifier\n";
		#print "Description: $description\n";

		if(defined($identifier))
		{
			my $response = $ua->get($identifier);

			if($response->is_error)
			{
				printf "Failed to retrieve %s. Status: %s. I will not add it to the catalogue database\n" , $identifier , $response->status_line;
				push(@broken_links,$identifier);
				return;
			}

			# These are set by set_difficulty_and_format
			my $redress_difficulty = undef;
			my $format = undef;

			set_difficulty_and_format($identifier,\$response,\$redress_difficulty,\$format);

			unless(defined($redress_difficulty))
			{
				print "Failed to get the redress_difficulty, setting it to 0\n";
				$redress_difficulty = 0;
			}

			unless(defined($format))
			{
				print "The document format (mime type) as not set. DB insert cancelled\n";
				return;
			}

			my $creators = join('|',@creator_list);

			my $publishers = join('|',@publisher_list);

			my $sql = "INSERT INTO content (identifier,format,title,creators,publishers,description,subject,language,ims_difficulty,redress_difficulty,source) values('$identifier','$format','$title','$creators','$publishers','$description','$subject','$language','$difficulty',$redress_difficulty,'manual')";
			#print "$sql\n";
			$dbh->do($sql);

			my @id_row;

			if(defined($dbh->errstr) and $dbh->errstr =~ /duplicate key/i)
			{
				# This content identifier is already in the table. Get its id so we can add the category mappings.
				@id_row = $dbh->selectrow_array("SELECT content_id FROM content WHERE identifier = '$identifier'");
			}
			else
			{
				# Get the id set by the sequence
				@id_row = $dbh->selectrow_array("SELECT currval('content_content_id_seq')");
			}

			my $catalogue_content_id = $id_row[0];

			my $statement = "SELECT category_id FROM category WHERE name = '$current_category'";
			#print $statement;

			my @category_id_row = $dbh->selectrow_array($statement);
			my $current_category_id = $category_id_row[0];

			#print "INSERT INTO catalogue_content_category values($catalogue_content_id,$current_category_id)";
			$dbh->do("INSERT INTO content_category values($catalogue_content_id,$current_category_id)");
		}

		$in_content = 0;

		$identifier = $title = $subject = $description = $language = $difficulty = undef;

		@creator_list = ();
		@publisher_list = ();
	}

	$in_identifier = 0 if($element eq 'dcmi:identifier');

	if($element eq 'dcmi:title')
	{
		$in_title = 0;
	}

	if($element eq 'dcmi:description')
	{
		$in_description = 0;
	}

	if($element eq 'dcmi:subject')
	{
		$in_subject = 0;
	}

	if($element eq 'dcmi:creator')
	{
		$in_creator = 0;
	}

	if($element eq 'dcmi:publisher')
	{
		$in_publisher = 0;
	}

	if($element eq 'dcmi:language')
	{
		$in_language = 0;
	}

	if($element eq 'imsmd:difficulty')
	{
		$in_difficulty = 0;
	}

	#print "Element: $element\n";
}

sub char_handler
{
	my $text = $_[1]; # First element is Expat reference

	$identifier = escape($text) if($in_identifier eq 1);
	$title = escape($text) if($in_title eq 1);
	$subject = escape($text) if($in_subject eq 1);
	push(@creator_list,escape($text)) if($in_creator eq 1);
	push(@publisher_list,escape($text)) if($in_publisher eq 1);
	$language = escape($text) if($in_language eq 1);
	$description = escape($text) if($in_description eq 1);
	$difficulty = escape($text) if($in_difficulty eq 1);
}

sub escape
{
	my $text = shift;

	$text =~ s/(["'])/\\$1/g;

	return $text;
}

sub set_difficulty_and_format
{
	my ($url,$response,$difficulty,$format) = @_;

	my $ct = $$response->header('Content-Type');

	$ct =~ /^(\w*\/[\w\.-]*)/i;
	$$format = $1;

	my %metadata_map = ();

	if($$format eq 'text/html')
	{
		print "HTML\n";

		my $content = $$response->content;

		%metadata_map = $parsers->parse_html(\$content); # Ditto
		$metadata_map{'identifier'} = $url;

		$$difficulty = $metadata_map{'redress_difficulty'};
	}
	elsif($$format eq 'application/pdf')
	{
		print "PDF\n";

		my $content = $$response->content;

		%metadata_map = $parsers->parse_pdf(\$content);
		$metadata_map{'identifier'} = $url;

		$$difficulty = $metadata_map{'redress_difficulty'};
	}
	else
	{
		sprintf "Unhandled type: %s\n",$$format;
	}
}
