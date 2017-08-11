#!/usr/bin/perl -w

use strict;
#use warnings;

use Redress::DB;

my $db = Redress::DB->new('redressadmin','esc1ence');

my $map = $db->get_category_document_map();

my $xml = qq{
<?xml version="1.0"?>
<catalogue>};

foreach my $category_name (keys %$map)
{
	my $category_description = $db->get_category_description($category_name);

	$xml .= qq{
	<category name="$category_name" description="$category_description">};

	my $documents = $map->{$category_name};

	foreach my $identifier (keys %$documents)
	{
		my $metadata = $documents->{$identifier};

		$xml .= qq{
		<content identifier="$identifier">
			<metadata>};

		foreach my $label (keys %$metadata)
		{
			my $value = $metadata->{$label};

			next unless(defined($value));

			next unless(length($value) > 0);

			# Test if the value is an arrayref
			$value = join('|',@$value) if(ref($value) eq 'ARRAY');

			$xml .= qq{
				<$label>$value</$label>};
		}

		$xml .= qq{
			<metadata>
		</content>};
	}

	$xml .= qq{
	</category>};
}

$xml .= qq{
</catalogue>};

print $xml;
