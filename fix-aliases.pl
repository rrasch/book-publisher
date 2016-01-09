#!/usr/bin/perl
#
# Fix url aliases for stitched pages.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use strict;
use warnings;
use DBI;
use MyConfig;
use MyLogger;

my $log = MyLogger->get_logger();

my $dsn =
  "DBI:mysql:database=" . config('dbname') . ';host=' . config('dbhost');
my $dbh = DBI->connect($dsn, config('dbuser'), config('dbpass'))
  or $log->logdie($DBI::errstr);

my $alias_table = config('dbprefix') . "url_alias";

my $select = $dbh->prepare(qq{
	SELECT pid, source, alias
	FROM $alias_table
	WHERE alias LIKE 'books%-%' ORDER BY source
}) or die $dbh->errstr;

my $update = $dbh->prepare(qq{
	UPDATE $alias_table
	SET alias = ?
	WHERE pid = ?
}) or die $dbh->errstr;

$select->execute;

my $i = 1;
while (my ($pid, $src, $alias) = $select->fetchrow_array)
{
	my $left = $i;
	my $right;
	if ($i == 1 || $i == 446) {
		$right = $i;
		$i++;
	} else {
		$right = $i + 1;
		$i += 2;
	}
	my $new_alias = "books/book000001/$left-$right";

	print "$pid $src $alias $new_alias\n";

	$update->execute($new_alias, $pid);
}

$select->finish;
$update->finish;

$dbh->disconnect;

