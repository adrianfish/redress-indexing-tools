#!/usr/bin/perl
#
use strict;
use warnings;

use LWP::RobotUA;
use URI;
use HTML::LinkExtor;
use Redress::Parsers;
use Redress::DB;

use CGI;

require WWW::RobotRules;

use Getopt::Long;

my $filename = 'urls.txt';
my $depth_limit = 5;

my $result = GetOptions("f=s" => \$filename,
						"d=i" => \$depth_limit);

print "Filename: $filename. Depth: $depth_limit\n";

if($filename eq 1) { $filename = 'urls.txt'; }

unless(-r $filename)
{
	print STDERR "$filename is not readable\n";
	exit 1;
}

open URLFILE,$filename;

my @url_list = ();

while(<URLFILE>)
{
	chomp;
	push(@url_list,$_);
}

close URLFILE;

my $parsers = Redress::Parsers->new({ CATEGORIZE => 1,TYPE => 'SVM' });

my $db = Redress::DB->new('redressadmin','esc1ence');

# Setup the robot rules parser
my $robotrules = WWW::RobotRules->new('ReDReSS Metadata Indexer');

# Create a ReDReSS agent
my $ua = LWP::RobotUA->new('ReDReSS Metadata Indexer','a.fish@lancaster.ac.uk');
$ua->delay(1/60); # 1 second delay between requests
$ua->timeout(15);
$ua->env_proxy;

# Make sure we don't do the same url twice
my @done_list;

my $current_host;

# This contains urls sourced from the robots.txt file at the current host
my @disallowed;

# Hostnames on which timeouts occurred are stored here
my @broken;

my $depth;

foreach my $url (@url_list)
{
	$depth = 0;
	my $uri = URI->new($url);
	do_url($uri);
}

#
# Extracts the metadata from the url and sticks it in the database. Extracts the
# links and recurses for each one.
#
sub do_url
{
	print "do_url()\n";

	print "Current Depth: $depth\n";

	# Have we reached the depth limit?
	if($depth >= $depth_limit)
	{
		print "Depth limit reached or exceeded. Returning ...\n";
		return;
	}

	my $uri = shift;

	# Extract the scheme and hostname portions of the url
	my $scheme = $uri->scheme;

	if($scheme ne 'http')
	{
		print "Scheme $scheme not permitted. Skipping $uri ...\n";
		return;
	}

	my $host = $uri->host;
	my $path = $uri->path;
	my $fragment = $uri->fragment;

	#print "Scheme: $scheme. Host: $host. Path: $path. Fragment: $fragment\n";

	#print "Press enter to continue\n";
	#getc;

	my $url = $uri->as_string;

	if(grep(/$host/,@broken))
	{
		print "$host is in the broken list. Skipping ...\n";
		return;
	}

	# Test if this url is in the done list
	foreach my $done (@done_list)
	{
		if($done eq $url)
		{
			print "$url has been done already. Skipping ...\n";
			return;
		}
	}

	# Now increment the depth
	$depth++;

	# If the current host has changed, reload the list of disallowed urls from
	# robots.txt
	if(defined($current_host) and ($host ne $current_host))
	{
		my $robots_uri = URI->new("$scheme://$host/robots.txt");

		set_robot_rules($robots_uri);

		$current_host = $host;
	}

	#print "Current Host: $current_host\n";

	# Issue the HTTP request
	my $response = $ua->get($url);

	if($response->is_error)
	{
		#printf ("Failed to get contents for url %s. Status : %s. Skipping ...\n",$url,$response->status_line); 
		return;
	}

	my $content_type = $response->content_type;

	$content_type =~ /^(\w*\/[\w\.-]*)/i;

	my $format = $1;

	my $content = $response->content;

	my %metadata = ();

	eval
	{
		if($content_type =~ /text\/html/)
		{
			%metadata = $parsers->parse_html(\$content);
		}
		elsif($content_type =~ /application\/pdf/)
		{
			%metadata = $parsers->parse_pdf(\$content);
		}
		elsif($content_type =~ /application\/msword/)
		{
			%metadata = $parsers->parse_word(\$content);
		}
		else
		{
			warn "$content_type not handled (yet!). Returning ...\n";
			return;
		}
	};

	if($@)
	{
		warn "Exception  caught whilst parsing $url. Returning ...\n";
		return;
	}

	$metadata{'identifier'} = $url;
	$metadata{'format'} = $format;

	insert_into_db(\%metadata);

	# Mark this url as having been done
	push(@done_list,$url);

	my $base_url;

	#my $base_url = $scheme . '://' . $host . $uri->path;
	#
	
	#printf ("Path: %s\n",$uri->path);

	if($url =~ /^(.*\/)[a-zA-Z-_0-9\.]+$/) # If it ends with a filename, strip it off
	{
		$base_url = $1;
	}
	elsif($uri =~ /\/$/) # If it ends with a slash
	{
		$base_url = $url;
	}
	elsif($uri =~ /\/[#a-zA-Z0-9\-]+$/) # If it ends with a fragment
	{
		$base_url = $url . "/";
	}

	#print "Base URL: $base_url\n";

	# Now get the links on this page. Ths list will content URI instances
	my @list = build_link_list($base_url,$content);

	# and recurse through each

	unless($depth >= $depth_limit)
	{
		foreach my $link (@list)
		{
			my $current_depth = $depth;
		
			# Ok. Recurse.
			do_url($link);

			$depth = $current_depth;
		}
	}
}

#
# Parses the supplied content for uris and returns a list of URI objects
#
sub build_link_list
{
	my ($base_url,$content) = @_;

	my @list = ();

	my $extor = HTML::LinkExtor->new(
							sub
							{
								my ($tag,%attr) = @_;

								return unless($tag eq 'a');

								my $url = $attr{'href'};

								push(@list,URI->new($url));
							}
							,$base_url);

	$extor->parse($content);

	return @list;
}

sub insert_into_db
{
	my $metadata = $_[0]; # hash reference

	my $identifier 			= $metadata->{'identifier'};
	my $format 				= $metadata->{'format'};
	my $title 				= $metadata->{'title'};
	my $creators 			= $metadata->{'creator'}; # Array ref
	my $description 		= $metadata->{'description'};
	my $subject 			= $metadata->{'subject'};
	my $categories 			= $metadata->{'categories'}; # Array ref
	my $publishers 			= $metadata->{'publishers'}; # Array ref
	my $redress_difficulty 	= $metadata->{'redress_difficulty'};

	#foreach my $category (@$categories)
	#{
	#	print "\n\nCATEGORY: $category\n\n\n";
	#}

	$db->update_metadata({
					IDENTIFIER 			=> $identifier,
					FORMAT 				=> $format,
					TITLE 				=> $title,
					SUBJECT 			=> $subject,
					DESCRIPTION 		=> $description,
					REDRESS_DIFFICULTY 	=> $redress_difficulty,
					PUBLISHERS 			=> $publishers,
					CATEGORIES 			=> $categories,
					CREATORS 			=> $creators,
					UPLOADER 			=> 'harvester',
					SOURCE				=> 'harvested'});
}

#
# Parses the robots file at the supplied url and adds the banned urls to the
# disallowed list
#
sub set_robot_rules
{
	print "reload_disallowed_list()\n";

	my $robots_uri = $_[0];

	my $url = $robots_uri->as_string;

	#print "robots.txt URL: $robots_uri\n";

	# Issue the HTTP request
	my $response = $ua->get($url);

	if($response->is_error)
	{
		# Oh well. We tried.
		print $response->status_line;
		if($response->status_line =~ /^500/)
		{
			# Timed out. Add host to the broken list
			push(@broken,$robots_uri->host);
		}
		return;
	}

	my $content = $response->content;

	$robotrules->parse($url,$content);

	$ua->rules($robotrules);
}

exit 0;
