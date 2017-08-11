package Redress::Utils;

use strict;
use Exporter;
use Lingua::EN::Fathom;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Document;
use AI::Categorizer::Hypothesis;
use Algorithm::NaiveBayes;
use Carp;

use vars qw(@ISA @EXPORT);

@ISA = ('Exporter');
@EXPORT = qw(&get_redress_difficulty &get_best_category &load_stopwords &load_acronyms);

sub get_redress_difficulty
{
	my $text = $_[0];

	my $fathomer = Lingua::EN::Fathom->new();

	# Run Fathom across the accumulated document text now
	my $accumulate = 1;
	$fathomer->analyse_block($$text,1);

	my $word_count = $fathomer->num_words;

	return unless $word_count > 0;

	my @acronyms = load_acronyms();

	my $acronym_count = 0;

	foreach my $acronym (@acronyms)
	{
		$acronym_count++ while($$text =~ /$acronym/g);
	}

	my $acronym_ratio = $acronym_count / $word_count;

	my $acronym_index = ($acronym_ratio / 1) * 0.003333;

	my $fog = $fathomer->fog;
	my $flesch = $fathomer->flesch;
	my $kincaid = $fathomer->kincaid;

	carp "Fog: $fog. Flesch: $flesch. Kincaid: $kincaid\n";

	my $average = ($fog + $kincaid) / 2.0;

	my $schooling_index = ($average / 14.5) * 0.3333;

	my $adjusted_flesch = (100 - $flesch) * 0.003333;

	return ($schooling_index + $adjusted_flesch + $acronym_index);
}

sub get_best_category
{
	my ($text) = $_[0];

	unless(defined($text))
	{
		carp "No text supplied.\n";
		return;
	}

	my $classification_set = 'classification-set';

	unless(-r "$classification_set/self")
	{
		carp "$classification_set/self is not readable\n";
		return;
	}

	# Setup the naive Bayes categorizer. Hopefully this has been pre-trained on the
	# redress catalogue content.
	
	my $nb = AI::Categorizer::Learner::NaiveBayes->new();
	$nb->restore_state($classification_set);

	my %stopwords = load_stopwords();

	carp "Categorizing ...\n";

	my $hypothesis = $nb->categorize(AI::Categorizer::Document->new(name => 'test',content => $$text,stopwords => \%stopwords));

	return $hypothesis->best_category();
}

=item load_stopwords

Reads all the words from a file called stopwords.txt in the working directory
(one word per line please) and adds them to a hash as the keys. Returns the hash.

=cut

sub load_stopwords
{
	carp "Loading stopwords ...\n";

	my $filename = 'stopwords.txt';

	my %stopwords = ();

	# Try and load some stopwords from the working directory
	unless(-r $filename)
	{
		warn "$filename either not present or unreadable\n";
		return %stopwords;
	}

	open STOPFILE , $filename;

	$stopwords{$_} = '' while(<STOPFILE>);

	close STOPFILE;

	return %stopwords;
}

=item load_acronyms

Reads all the words from a file called acronyms.txt in the working directory
(one word per line please) and adds them to a list. Returns the list.

=cut

sub load_acronyms
{
	carp "Loading acronyms ...\n";

	my $filename = 'acronyms.txt';

	my @acronyms = ();

	# Try and load some stopwords from the working directory
	unless(-r $filename)
	{
		warn "$filename either not present or unreadable\n";
		return @acronyms;
	}

	open ACRFILE , $filename;

	push(@acronyms,$_) while(<ACRFILE>);

	close ACRFILE;

	return @acronyms;
}

1;
