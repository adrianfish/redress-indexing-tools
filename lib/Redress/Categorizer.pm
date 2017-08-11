package Redress::Categorizer;

use strict;
use warnings;
use AI::Categorizer::Learner::NaiveBayes;
use AI::Categorizer::Learner::SVM;
use AI::Categorizer::Learner::KNN;
use AI::Categorizer::Document;
use AI::Categorizer::Hypothesis;
use Algorithm::NaiveBayes;
use Algorithm::NaiveBayes::Model::Frequency;
use Carp;

sub new
{
	my ($class,$type) = @_;

	my $self = {};

	my $classification_set = 'classification-set';

	unless(-r "$classification_set/self")
	{
		carp "$classification_set/self is not readable\n";
		return;
	}

	# Setup the naive Bayes categorizer. Hopefully this has been pre-trained on the
	# redress catalogue content.
	if(defined($type) and $type eq 'SVM')
	{
		$self->{LEARNER} = AI::Categorizer::Learner::SVM->restore_state($classification_set);
	}
	elsif(defined($type) and $type eq 'KNN')
	{
		$self->{LEARNER} = AI::Categorizer::Learner::KNN->restore_state($classification_set);
	}
	else
	{
		$self->{LEARNER} = AI::Categorizer::Learner::NaiveBayes->restore_state($classification_set);
	}

	my %stopwords = _load_stopwords();
	$self->{STOPWORDS} = \%stopwords;

	bless($self,$class);

	return $self;
}

sub categorize
{
	my ($self,$text) = @_;

	unless(defined($text))
	{
		carp "No text supplied.\n";
		return;
	}

	carp "Categorizing ...\n";

	my $stopwords = $self->{STOPWORDS};

	unless(defined($stopwords)) {$stopwords = {};}

	my $document = new AI::Categorizer::Document(name => 'test',content => $$text,stopwords => $stopwords);

	my $hypothesis = $self->{LEARNER}->categorize($document);

	my @categories = $hypothesis->categories;

	return \@categories;
}

=item load_stopwords

Reads all the words from a file called stopwords.txt in the working directory
(one word per line please) and adds them to a hash as the keys. Returns the hash.

=cut

sub _load_stopwords
{
	carp "Loading stopwords ...\n";

	my $filename = 'stopwords.txt';

	# Try and load some stopwords from the working directory
	unless(-r $filename)
	{
		warn "$filename either not present or unreadable\n";
	}

	open STOPFILE , $filename;

	my %stopwords = ();

	$stopwords{$_} = '' while(<STOPFILE>);

	close STOPFILE;

	return %stopwords;
}

1;
