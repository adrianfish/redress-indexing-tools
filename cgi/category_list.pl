#!/usr/bin/perl

use strict;
use warnings;
use CGI qw/:header -debug/;
use Redress::DB;

# Setup the db connection
my $db = Redress::DB->new('redressadmin','esc1ence');

print_error("Failed to connect to database") unless(defined($db));

my @categories = $db->get_category_names;

my $categories = join('|',@categories);

print header(-status => '200',
				-type => 'text/plain',
				-Content_length => length($categories));

print $categories;

exit 0;

sub print_error
{
	my $message = $_[0];

	print header(-status => "500 $message",
				-Content_length => length($message));

	print qq(
	<html>
		<body>
			<h2>$message</h2>
		</body>
	</html>
	);

	exit 1;
}
