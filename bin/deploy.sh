#!/bin/bash

# Plum's settings
siteperl=/usr/local/lib/site_perl
cgi=/usr/local/apache/cgi-bin
www=/usr/local/www/e-science/content/redress/catalogue-tools

#siteperl=/Library/Perl/perl

# Adrian's laptop settings
#siteperl=/usr/local/lib/site_perl
#cgi=/usr/lib/cgi-bin
#www=/var/www

if [ ! -d $siteperl ]
then
	echo "Creating $siteperl ..."
	mkdir $siteperl
elif [ -d $siteperl/Redress ]
then
	echo "Deleting $siteperl/Redress ..."
	rm -rf $siteperl/Redress
fi

echo "Copying the Redress modules into $siteperl ..."
cp -r lib/Redress $siteperl

echo "Changing the ownership of $siteperl/Redress to root ..."
chown -R root $siteperl/Redress


echo "Making the Redress modules executable ..."
chmod a+x $siteperl/Redress
chmod a-xw $siteperl/Redress/*.pm
chmod a+r $siteperl/Redress/*.pm

echo "Copying the html files into $www ..."
cp -r html/* $www

echo "Copying the cgi scripts  and property files into $cgi ..."
cp -r cgi/*.pl $cgi
cp -r cgi/reports.properties $cgi

echo 'Done'
