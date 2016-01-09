#!/usr/bin/env perl
#
# Script to update handles for books.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use Data::Dumper;
use File::Find;
use MyConfig;
use MyLogger;
use Node;

####################################################################

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

my $wip_dir = config('rstar_dir') . "/wip";

chdir($wip_dir) or $log->logdie("Can't chdir $wip_dir: $!");

my @handle_files = ();

find(sub { push(@handle_files, $File::Find::name) if /^handle$/ }, ".");

for my $handle_file (sort @handle_files)
{
	$log->debug("Handle file: $handle_file");

	my ($dot, $ent_type, $id, $hdl) = split(/\//, $handle_file);

	$log->info("Processing $id");

	my $node  = Node->new(obj => {identifier => $id});
	my $nid   = $node->nid;
	my $title = $node->title;
	(my $node_type = $node->get_attr('type')) =~ s/^dlts_//;

	my $handle = Util::get_handle($handle_file);
	my $handle_desc = "$id $title Handle";

	my $url = $ent_type =~ /ie/ ? "/$node_type/$id" : "/books/$id/1";

	$log->debug("Updating handle $handle to $url");
	Util::update_handle($handle, $url, $handle_desc);
	$log->debug("done");

	sleep(1);
}

