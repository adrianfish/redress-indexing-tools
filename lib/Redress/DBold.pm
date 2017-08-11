package Redress::DB;

use strict;
use warnings;

use DBI;

use Carp;

sub new
{
	my ($class,$username,$password) = @_;

	# Setup the db connection
	my $dbh = DBI->connect('DBI:Pg:dbname=REDRESS;host=localhost;port=5432',
                 		$username,
						$password,
                        {AutoCommit => 0,RaiseError => 1})
                        	or die "Failed to connect to database";

	my $self = { DBH => $dbh };

	bless($self,$class);

	return $self;
}

sub DESTROY
{
	my ($self) = @_;

	my $dbh = $self->{DBH};

	if(defined($dbh))
	{
		$dbh->disconnect;
	}
}

sub get_catalogue_category_totals
{
	my ($self) = @_;

	my $dbh = $self->{DBH};

	my $rows = {};

	eval
	{
		$rows = $dbh->selectall_hashref("select count(*) as total,name from content,content_category,category where source = 'manual' and content.content_id = content_category.content_id and content_category.category_id = category.category_id group by name",'name');
	};

	if($@)
	{
		return $@, undef;
	}

	my %category_totals = ();

	foreach my $row (values %$rows)
	{
		$category_totals{$row->{'name'}} = $row->{'total'};
	}

	return 0,%category_totals;
}

sub get_harvested_category_totals
{
	my ($self) = @_;

	my $dbh = $self->{DBH};

	my $rows = {};

	eval
	{
		$rows = $dbh->selectall_hashref("select count(*) as total,name from content,content_category,category where source = 'harvested' and content.content_id = content_category.content_id and content_category.category_id = category.category_id group by name",'name');
		if(keys %$rows <= 0)
		{
			carp "No rows !!!!!!!";
			my ($result,@categories) = $self->get_category_names();

			$rows = {};

			foreach my $category (@categories)
			{
				#carp $category;
				$rows->{$category} = {'name' => $category, 'total' => 0};
			}
		}
	};

	if($@)
	{
		return $@, undef;
	}

	my %category_totals = ();

	foreach my $row (values %$rows)
	{
		$category_totals{$row->{'name'}} = $row->{'total'};
	}

	return 0,%category_totals;
}


sub get_db_handle
{
	my $self = shift;
	return $self->{DBH};
}

=item get_metadata_for_url

Builds and returns a hashmap containing the metadata for the supplied URL

my %metadata = get_metadata_for_url('http://www.someplace.org/somedocument.html);

my $title = $metadata{'title'};
my $subject = $metadata{'subject'};
my $format = $metadata{'format'};
my $description = $metadata{'description'};
my $redress_difficulty = $metadata{'redress_difficulty'};
my $creators = $metadata{'creators'}; # Arrayref containing creator names
my $publishers = $metadata{'publishers'}; # Arrayref containing publisher names
my $categories = $metadata{'categories'}; # Arrayref containing categories names

=cut
 
sub get_metadata_for_url
{
	my ($self,$url) = @_;
	
	carp "URL: $url";

	my %metadata = ();

	my $categories = [];

	my $main_row = {};

	eval
	{
		die "No url supplied" unless($url);

		my $dbh = $self->{DBH};
	
		$main_row = $dbh->selectrow_hashref("SELECT * FROM content WHERE identifier = '$url'");

		$categories = $dbh->selectcol_arrayref("SELECT category FROM content_category_view WHERE identifier = '$url'");
	};

	if($@)
	{
		return $@ , undef;
	}
	
	$metadata{'title'} = $main_row->{'title'};
	$metadata{'subject'} = $main_row->{'subject'};
	$metadata{'format'} = $main_row->{'format'};
	$metadata{'language'} = $main_row->{'language'};
	$metadata{'ims_difficulty'} = $main_row->{'ims_difficulty'};
	$metadata{'description'} = $main_row->{'description'};
	$metadata{'creators'} = $main_row->{'creators'};
	$metadata{'publishers'} = $main_row->{'publishers'};
	$metadata{'uploader'} = $main_row->{'uploader'};
	$metadata{'redress_difficulty'} = $main_row->{'redress_difficulty'};

	$metadata{'categories'} = $categories;
	
	return 0 , %metadata;
}

sub delete_catalogue
{
	my $self = shift;
	my $dbh = $self->{DBH};
	$dbh->do("DELETE FROM content WHERE source = 'manual'");
	$dbh->do("DELETE FROM category");
}

sub _escape
{
	my $text = $_[0];

	unless(defined($text)) { return ""; }

	$text =~ s/(["'])/\\$1/g;

	return $text;
}

sub get_categories_for_document
{
	my $self = shift;
	my $identifier = shift;

	my $dbh = $self->{DBH};

	my $categories = [];

	eval
	{
		die "No identifier supplied" unless $identifier;

		$categories = $dbh->selectcol_arrayref("SELECT category FROM content_category_view where identifier = '$identifier'");
	};

	if($@)
	{
		return $@,undef;
	}

	return 0,@$categories;
}

sub get_documents_for_category
{
	my $self = shift;
	my $category = shift;

	my $dbh = $self->{DBH};

	my $rows = [];

	eval
	{
		die "No category supplied" unless $category;

		$rows = $dbh->selectall_arrayref("SELECT identifier FROM content_category_view WHERE category = '$category'");
	};

	if($@)
	{
		return $@,undef;
	}

	my @documents = ();

	foreach my $row (@$rows) { push(@documents,$row->[0]); }

	return 0,@documents;
}

sub get_possible_category_names
{
	my $self = shift;
	my $identifier = shift;

	my $dbh = $self->{DBH};

	my $categories = $dbh->selectcol_arrayref("SELECT name FROM category");

	return @$categories;
}

sub get_category_names
{
	my $self = shift;

	my $dbh = $self->{DBH};

	my $categories = [];

	eval
	{
		#my $rows = $dbh->selectall_arrayref("SELECT name FROM category");
		$categories = $dbh->selectcol_arrayref("SELECT DISTINCT category FROM content_category_view");
	};

	if($@)
	{
		return $@,undef;
	}

	return 0,@$categories;
}

sub update_metadata
{
	my ($self,$fields) = @_;

	my $identifier 			= $fields->{IDENTIFIER};
	my $format 				= $fields->{FORMAT};
	my $language 				= $fields->{LANGUAGE};
	my $uploader 				= $fields->{UPLOADER};
	my $title 				= _escape($fields->{TITLE});
	my $creators 		= $fields->{CREATORS};
	my $description 		= _escape($fields->{DESCRIPTION});
	my $subject 			= _escape($fields->{SUBJECT});
	my $categories 			= $fields->{CATEGORIES}; # Array ref
	my $publishers		= $fields->{PUBLISHERS};
	my $redress_difficulty 	= $fields->{REDRESS_DIFFICULTY};
	my $source 				= $fields->{SOURCE};

	$source = 'harvested' unless defined($source);

	unless(defined($redress_difficulty))
	{
		die "Redress difficulty undefined.\n";
	}
	
	my $dbh = $self->{DBH};

	#$dbh->begin_work;

	eval
	{
		# Is it in the db already ?
		my @test = $dbh->selectrow_array("SELECT content_id FROM content WHERE identifier = '$identifier'");
		my $content_id = $test[0];
		if(defined($content_id))
		{
			# Yes, delete the current data. Triggers will clean up the related tables
			$dbh->do("DELETE FROM content WHERE content_id = $content_id");
		}

		my $sql = qq{
			INSERT INTO content (identifier,format,title,subject,language,description,creators,publishers,uploader,redress_difficulty,source)
				VALUES('$identifier','$format','$title','$subject','$language','$description','$creators','$publishers','$uploader',$redress_difficulty,'$source')};

		carp("SQL: $sql\n");

		$dbh->do($sql);

		my @row = $dbh->selectrow_array("SELECT currval('content_content_id_seq')");
		$content_id = $row[0];

		carp "Content ID: $content_id";

		# Insert into the content_category lookup ...
		foreach my $category (@$categories)
		{
			my $category_id = $self->_get_category_id($category);

			carp "INSERT INTO content_category values($content_id,$category_id)";
			$dbh->do("INSERT INTO content_category values($content_id,$category_id)");
		}

		$dbh->commit;
	};

	my $db_error = 0;

	if($@)
	{
		$db_error = $@;

		eval
		{
			carp "Rolling back ..........";
			$dbh->rollback;
			die "$@";
		};
	}

	return $db_error;
}

sub _get_category_id
{
	my ($self,$name) = @_;

	my $dbh = $self->{DBH};

	my @row = $dbh->selectrow_array("SELECT category_id FROM category WHERE name = '$name'");

	return $row[0];
}

1;
