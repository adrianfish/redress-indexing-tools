package Redress::Reports;

use strict;
use warnings;

use GD::Graph::bars;
use Redress::DB;

use Carp;

sub new
{
	my $class = shift;

	my $db = Redress::DB->new('redressadmin','test');

	my @blacklist = (
				'Introductory Material and Support',
				'Examples from e-Social Science Projects',
				'Agenda Setting Workshops',
				'UK e-Science Programme',
				'Motivation and Background',
				'Social Shaping');

	my $self = {DBH => $db,BLACKLIST => \@blacklist};

	bless($self,$class);

	return $self;
}

sub create_catalogue_chart
{
	my $self = shift;
	my $data_ref = shift;

	my $db = $self->{DBH};

	carp "create_catalogue_chart()";

	my ($result,%category_totals) = $db->get_catalogue_category_totals;

	unless($result eq 0)
	{
		carp "Failed to draw catalogue png. Error: $result";
		exit 1;
	}

	my @marks = ();
	# Remove any of the blacklisted categories
	foreach my $name (keys %category_totals)
	{
		my $blacklist = $self->{BLACKLIST};

		if(grep(/$name/i,@$blacklist))
		{
			#print "Marking $name for deletion ...\n";
			push @marks,$name;
		}
	}

	foreach my $mark (@marks)
	{
		delete($category_totals{$mark}); 
	}

	# Get the sorted category names
	my @names = sort keys(%category_totals);

	my @values = ();

	foreach my $name (@names)
	{
		push @values , $category_totals{$name};
	}

	my @data = (\@names, # x
				\@values); # values

	eval
	{
		my $graph = GD::Graph::bars->new(600,600);

		$graph->set(x_label => 'Category',
				y_label => 'No. Documents',
				x_labels_vertical => 1,
				title => 'ReDReSS Catalogue Document Distribution')
					or die $graph->error;

		my $gd = $graph->plot(\@data) or die $graph->error;

		$$data_ref = $gd->png;

		#return $gd->png;
	};

	if($@)
	{
		carp $@;
	}
}

sub create_harvested_chart
{
	my $self = shift;

	my $data_ref = shift;

	my $db = $self->{DBH};

	carp "print_harvested_png()";

	my ($result,%category_totals) = $db->get_harvested_category_totals;

	unless($result eq 0)
	{
		carp "Failed to print harvested png. Error: $result"; 
		exit 1;
	}

	my @marks = ();
	# Remove any of the blacklisted categories
	foreach my $name (keys %category_totals)
	{
		my $blacklist = $self->{BLACKLIST};

		if(grep(/$name/i,@$blacklist))
		{
			#print "Marking $name for deletion ...\n";
			push @marks,$name;
		}
	}

	foreach my $mark (@marks)
	{
		delete($category_totals{$mark}); 
	}

	# Get the sorted category names
	my @names = sort keys(%category_totals);

	my @values = ();

	foreach my $name (@names)
	{
		push @values , $category_totals{$name};
	}

	my @data = (\@names, # x
			\@values); # values

	eval
	{
		my $graph = GD::Graph::bars->new(600,600);

		$graph->set(x_label => 'Category',
			y_label => 'No. Documents',
			x_labels_vertical => 1,
			title => 'ReDReSS Harvested Document Distribution')
				or die $graph->error;

		my $gd = $graph->plot(\@data) or die $graph->error;

		$$data_ref = $gd->png;
	};

	if($@)
	{
		carp $@;
	}
}

1;
