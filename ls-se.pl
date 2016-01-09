#!/usr/bin/env perl
#
# List source entity ids for an intellectual entity.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use Getopt::Std;
use IntellectualEntityMETS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

our ($opt_r);
getopts('r:');
my $rstar_dir = $opt_r || $ENV{RSTAR_DIR} || config('rstar_dir');

my $wip_dir = "$rstar_dir/wip";

my @ie_ids = @ARGV ? @ARGV : Util::get_dir_contents("$wip_dir/ie");

for my $ie_id (@ie_ids)
{
	my $ie_data_dir = "$wip_dir/ie/$ie_id/data";
	my $ie_mets_file = "$ie_data_dir/${ie_id}_mets.xml";
	if (!-f $ie_mets_file)
	{
		$log->warn(
			"Intellectual entity mets file $ie_mets_file doesn't exist.");
		next;
	}
	my $ie_mets = IntellectualEntityMETS->new($ie_mets_file);
	my @se_mets_files = ();
	for my $se ($ie_mets->get_source_entities())
	{
		push(@se_mets_files, $se->{mets_file});
	}
	for my $se_mets_file (@se_mets_files)
	{
		if (!-f $se_mets_file)
		{
			$log->warn("Source entity mets file $se_mets_file doesn't exist.");
			next;
		}
		my $se_mets = SourceEntityMETS->new($se_mets_file);
		print $se_mets->get_id(), "\n";
	}
}

