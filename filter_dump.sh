#!/bin/sh

sed -e "/^SUCCESS.*/p" -n dump.txt > successful_categorisations.txt
sed -e "/^FAILURE.*/p" -n dump.txt > failed_categorisations.txt

