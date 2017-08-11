package Redress::DifficultyEstimator;

use strict;
use warnings;

use Lingua::EN::Fathom;
use Carp;

sub new
{
	my $self = {};
	my @acronyms = _load_acronyms();
	$self->{ACRONYMS}  = \@acronyms;
	$self->{FATHOMER} = Lingua::EN::Fathom->new();
    	bless($self);           # but see below
   	return $self;
}
	
sub estimate
{
	my ($self,$text) = @_;

	my $fathomer = $self->{FATHOMER};
	my $acronyms = $self->{ACRONYMS};

	# Run Fathom across the accumulated document text now
	my $accumulate = 1;
	$fathomer->analyse_block($$text,1);

	my $word_count = $fathomer->num_words;

	return unless $word_count > 0;

	my $acronym_count = 0;

	foreach my $acronym (@$acronyms)
	{
		$acronym_count++ while($$text =~ /$acronym/g);
	}

	my $acronym_ratio = $acronym_count / $word_count;

	my $acronym_index = ($acronym_ratio / 1) * 0.003333;

	my $fog = $fathomer->fog;
	my $flesch = $fathomer->flesch;

	#carp "Fog: $fog. Flesch: $flesch\n";

	if($fog > 17)
	{
		$fog = 17;
	}
	elsif($fog < 0)
	{
		$fog = 0;
	}

	if($flesch > 100)
	{
		$flesch = 100;
	}
	elsif($flesch < 0)
	{
		$flesch = 0;
	}

	my $adjusted_fog = ($fog / 17) * 0.3333;

	my $inverted_flesch = (100 - $flesch) * 0.003333;

	#carp "Adjusted Fog: $adjusted_fog. Inverted Flesch: $inverted_flesch. Acronym Index: $acronym_index\n";

	return ($adjusted_fog + $inverted_flesch + $acronym_index);
}

=item _load_acronyms

Reads all the words from a file called acronyms.txt in the working directory
(one word per line please) and adds them to a list. Returns the list.

=cut

sub _load_acronyms
{
	#carp "Loading acronyms ...\n";

	my $filename = 'acronyms.txt';

	# Try and load some stopwords from the working directory
	unless(-r $filename) {warn "$filename either not present or unreadable\n";}

	open ACRFILE , $filename;

	my @acronyms = ();

	push(@acronyms,$_) while(<ACRFILE>);

	close ACRFILE;

	return @acronyms;
}

1;
