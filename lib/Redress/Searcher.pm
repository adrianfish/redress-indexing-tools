package Redress::Searcher;

use strict;
use warnings;
use DBI;
use Carp;

sub new
{
	my ($class,$dbuser,$dbpassword) = @_;

	my $dbh = DBI->connect('DBI:Pg:dbname=REDRESS;host=localhost;port=5432',
				$dbuser,
				$dbpassword,
				{AutoCommit => 1})
					or die "Failed to connect to database";

	my $self = { DBH => $dbh };

	bless($self,$class);

	return $self;
}

sub search
{
	my ($self,$searchfields) = @_;

	unless(defined($searchfields))
	{
		warn "You must supply a hashref containing the search criteria\n";
		return;
	}

	my $title = $searchfields->{'title'};
	my $description = $searchfields->{'description'};
	my $creator = $searchfields->{'creator'};
	my $publisher = $searchfields->{'publisher'};
	my $subject = $searchfields->{'subject'};
	my $category = $searchfields->{'category'};

	unless(defined($title) || defined($description) || defined($creator) || defined($publisher)
				|| defined($subject) || defined($category))
	{
		warn "Please supply at least one criterion !\n";
		return;
	}

	unless(length($title) > 0 || length($description) > 0 || length($creator) > 0 || length($publisher) > 0
				|| length($subject) > 0 || length($category) > 0)
	{
		warn "Please supply at least one criterion !\n";
		return;
	}
	
	my $sql = "SELECT * FROM content";

	if(defined($category) && length($category) > 0) { $sql .= ',content_category,category'; }
	
	$sql .= " WHERE";

	my $use_and = 0;

	if(defined($title) && length($title) > 0)
	{
		$sql .= " title ILIKE '\%$title\%'";
		$use_and = 1;
	}

	if(defined($description) && length($description) > 0)
	{
		if($use_and eq 1) { $sql .= ' AND'; }

		$sql .= " description ILIKE '\%$description\%'";
		$use_and = 1;
	}

	if(defined($creator) && length($creator))
	{
		if($use_and eq 1) { $sql .= ' AND'; }

		$sql .= " creators ILIKE '\%$creator\%'";
		$use_and = 1;
	}

	if(defined($publisher) && length($publisher))
	{
		if($use_and eq 1) { $sql .= ' AND'; }

		$sql .= " publishers ILIKE '\%$publisher\%'";
		$use_and = 1;
	}

	carp "Keywords: $subject\n";

	my @words = split(/\s/,$subject) if(defined($subject) && length($subject) > 0);

	if(@words)
	{
		if($use_and eq 1) { $sql .= ' AND'; }

		$sql .= " subject ILIKE ";

		foreach my $word (@words)
		{
			$sql .= "'%$word%'";

			if($word ne $words[-1])
			{
				$sql .= " AND subject like ";
			}
		}

		$use_and = 1;
	}

	if(defined($category) && length($category) > 0)
	{
		if($use_and eq 1) { $sql .= ' AND'; }

		$sql .= qq{ content.content_id = content_category.content_id
						AND content_category.category_id = category.category_id
						AND name LIKE '$category'};

		$sql .= " ORDER BY CAST(redress_difficulty as float)";
	}

	my $dbh = $self->{DBH};

	carp "SQL: $sql\n";

	my @records = ();

	carp "SQL: $sql\n";
	#my $rows = $dbh->selectall_hashref($sql,'identifier');
	#
	my $sth = $dbh->prepare($sql);

	$sth->execute;

	while(my $row = $sth->fetchrow_hashref)
	{
		push(@records,$row);
	}

	return @records;
}

1;
