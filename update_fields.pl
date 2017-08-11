#!/usr/bin/perl

use Redress::DB;

my $db = Redress::DB->new('redressadmin','esc1ence');

my $dbh = $db->get_db_handle;

my $content_rows = $dbh->selectall_arrayref('SELECT content_id,identifier from content');

foreach my $content_row (@$content_rows)
{
	my $content_id = $content_row->[0];

	my $creator_rows = $dbh->selectall_arrayref("SELECT creator FROM content_creator WHERE content_id = $content_id");

	my $creators = '';

	foreach my $creator_row (@$creator_rows)
	{
		$creators .= $creator_row->[0];

		unless($creator_row eq @$creator_rows->[-1]) 
		{
			$creators .= '|';
		}
	}

	unless(length($creators) eq 0)
	{
		#print "$content_id:$creators\n";
		$dbh->do("UPDATE content SET creators = '$creators' WHERE content_id = $content_id");
	}

	my $publisher_rows = $dbh->selectall_arrayref("SELECT publisher FROM content_publisher WHERE content_id = $content_id");

	my $publishers = '';

	foreach my $publisher_row (@$publisher_rows)
	{
		$publishers .= $publisher_row->[0];

		unless($publisher_row eq @$publisher_rows->[-1]) 
		{
			$publishers .= '|';
		}
	}

	unless(length($publishers) eq 0)
	{
		#print "$content_id:$publishers\n";
		$dbh->do("UPDATE content SET publishers = '$publishers' WHERE content_id = $content_id");
	}
}


exit 0;
