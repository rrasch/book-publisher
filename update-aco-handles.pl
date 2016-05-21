#!/usr/bin/env perl
#
# Script to update handles for books.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use MyConfig;
use MyLogger;
use Node;

####################################################################

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

my $wip_dir = config('rstar_dir') . "/wip/se";

for my $id (sort @ARGV)
{
	$log->info("Processing $id");

	my $handle_file = "$wip_dir/$id/handle";
	$log->debug("Handle file: $handle_file");

	my $node  = Node->new(obj => {identifier => $id});
	my $nid   = $node->nid;
	my $title = $node->title;

	my $handle = Util::get_handle($handle_file);
	my $handle_desc = "$id $title Handle";

	my $url = config('baseurl') . "/book/$id";

	$log->debug("Updating handle $handle to $url");
	Util::update_handle($handle, $url, $handle_desc);
	$log->debug("done");

	sleep(1);
}

