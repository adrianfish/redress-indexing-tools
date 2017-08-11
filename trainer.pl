#!/usr/bin/perl
#
# Build a list of Category objects, populated with Document objects
# Build a list of Document objects populated with Category objects

use strict;
use warnings;

use AI::Categorizer::Category;
use AI::Categorizer::Document;
use AI::Categorizer::KnowledgeSet;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Learner::SVM;
use AI::Categorizer::Learner::KNN;
use LWP::UserAgent;

use Redress::Utils;
use Redress::DB;
use Redress::HtmlParser;
use Redress::PdfParser;
use Redress::MSWordParser;
#use Redress::PowerpointParser;

my $ua = LWP::UserAgent->new();
$ua->timeout(30);
$ua->env_proxy;

my %stopwords = load_stopwords();

#my $document_text = '';

my @broken_urls = ();

# The only thing we need the parser for is text extraction
#my $parser = HTML::Parser->new(api_version => 3,
#								text_h => [	sub
#											{
#												$document_text .= shift;
#											}
#											,"dtext" ]);

my $db = Redress::DB->new('redressadmin','esc1ence');

my @documents = ();

my @blacklist = ('Introductory Material and Support','Examples from e-Social Science Projects','Agenda Setting Workshops','UK e-Science Programme','Motivation and Background','Social Shaping');
my @categories = build_categories();

print "Creating knowledge set ...\n";
my $ks = new AI::Categorizer::KnowledgeSet(
											categories => \@categories,
											documents => \@documents,
											features_kept => 0 # Keep all features
											);

#printf "KnowledgeSet has %s categories and %s documents\n", scalar($ks->categories) , scalar($ks->documents);

print "Training ...\n";
my $learner = new AI::Categorizer::Learner::NaiveBayes();
#my $learner = new AI::Categorizer::Learner::KNN();
$learner->train( knowledge_set => $ks);

# Test it
my $test = 'This is a test string';
my $testdoc = new AI::Categorizer::Document(name => 'test',content => $test);
my $h = $learner->categorize($testdoc);
printf "Best Category: %s\n",$h->best_category;

# Save it
print "Saving categorizer ...\n";
$learner->save_state('classification-set');

# Write the broken urls into the broken file
open BROKEN,'+>broken.txt';

foreach my $broken_url (@broken_urls)
{
	print BROKEN "$broken_url\n";
}

close BROKEN;

sub build_categories
{
	my ($result,@category_names) = $db->get_category_names;

	unless($result eq 0)
	{
		print "Failed to get category names from database. Error: $result\n";
		exit 1;
	}

	for my $name (@category_names)
	{
		if(grep(/$name/,@blacklist))
		{
			# Crap category
			print "Skipping crap category: $name ...\n";
			next;
		}

		my $category = AI::Categorizer::Category->new(name => $name);
		set_documents_for_category(\$category);

		#printf "Category: %s has %s documents\n" ,$category->name, scalar($category->documents);
		push(@categories,$category);
	}

	return @categories;
}

sub set_documents_for_category
{
	#print "get_documents_for_category\n";

	my $category = $_[0]; # Reference to a Category object

	my $name = $$category->name;

	my ($result1,@urls) = $db->get_documents_for_category($name,'manual');

	unless($result1 eq 0)
	{
		print "Failed to get documents for category '$name' from database. Error: $result1\n";
		exit 1;
	}

	my $pdf_parser = Redress::PdfParser->new();
	my $word_parser = Redress::MSWordParser->new();
	my $html_parser = Redress::HtmlParser->new();
	#my $powerpoint_parser = Redress::PowerpointParser->new();

	foreach my $url (@urls)
	{
		#printf "%s is in category %s\n" , $url , $name;
		
		# Download the document and parse it
		my $response = $ua->get($url);

		unless($response->is_success)
		{
			printf "Failed to retrieve %s with status: %s. Skipping ...\n" , $url , $response->status_line;
			push @broken_urls , $url;
			next;
		}

		my $ct = $response->header('Content-Type');

		my $document_text = undef;

		my$content = $response->content;

		#$parser->parse($content) if($ct =~ /text\/html/);
		#$document_text = do_pdf(\$content) if($ct =~ /application\/pdf/);
		eval
		{
			if($ct =~ /application\/pdf/)
			{
				$document_text = $pdf_parser->get_text(\$content);
			}
			elsif($ct =~ /application\/msword/)
			{
				$document_text = $word_parser->get_text(\$content);
			}
			#elsif($ct =~ /application\/mspowerpoint/)
			#{
			#	$document_text = $powerpoint_parser->get_text(\$content);
			#}
			elsif($ct =~ /text\/html/)
			{
				$document_text = $html_parser->get_text(\$content);
			}
			else
			{
				print "Content Type: $ct not recognised. Skipping $url ...\n";
				next;
			}
		};

		if($@)
		{
			print "Caught exception when processing url $url\n";
			next;
		}

		# Get the categories that this Document belongs in
		my ($result2,@category_names) = $db->get_categories_for_document($url);

		unless($result2 eq 0)
		{
			print "Failed to get categories for document '$url' from database. Error: $result2\n";
			exit 1;
		}

		my @doc_categories = ();

		foreach my $category_name (@category_names)
		{
			if(grep(/$category_name/,@blacklist))
			{
				# Crap category
				print "Skipping crap category: $category_name ...\n";
				next;
			}

			push(@doc_categories,AI::Categorizer::Category->new(name => $category_name));
		}

		my $document = new AI::Categorizer::Document(name => $url,
														content => $$document_text,
														stopwords => \%stopwords,
														categories => \@doc_categories);

		# Put the document on the collapsed list
		push(@documents,$document);

		# Add it to the current category
		$$category->add_document($document);
	}
}
