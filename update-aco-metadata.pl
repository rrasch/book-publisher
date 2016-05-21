#!/usr/bin/env perl
#
# Update metadata for NYU ACO
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use utf8;
use Data::Dumper;
use Getopt::Std;
use METSRights;
use MODS;
use MyConfig;
use MyLogger;
use Node;
use SourceEntityMETS;
use Util;

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

our $opt_r;
getopts('r:');

my $rstar_dir = $opt_r || $ENV{RSTAR_DIR} || config('rstar_dir');

my $wip_dir = "$rstar_dir/wip/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);


for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir =  "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";
	my $mets = SourceEntityMETS->new($mets_file);

	my @file_ids = $mets->get_file_ids();
	
	# get binding orientation, scan order, read order info
	# XXX: Put this in a method
	my %scan_data = $mets->scan_data();
	for my $k (keys %scan_data)
	{
		$log->debug("$k: $scan_data{$k}");
	}
	my $orientation =
	  $scan_data{binding_orientation} =~ /^horizontal$/i ? 1 : 0;
	my $read_order =
	  $scan_data{read_order} =~ /^right(2|_to_)left$/i ? 1 : 0;
	my $scan_order =
	  $scan_data{scan_order} =~ /^right(2|_to_)left$/i ? 1 : 0;

	my $rights_file = $mets->get_rights_file;
	$log->debug("METSRights file: $rights_file");

	my $rights = METSRights->new($rights_file);
	$log->debug($rights->declaration);

	my $mods_file = $mets->get_mods_file;
	$log->debug("MODS file: $mods_file");

	my $mods_en = MODS->new($mods_file);
	my $langs_avail = $mods_en->get_languages();
	$mods_en->set_language("Latn") if $langs_avail->{Latn};

	my $book_en = Node->new(obj => {identifier => $id});
	$log->debug(Dumper($book_en));

	my $vals = {
		title                      => $mods_en->title,
		isbn                       => "",
		rights                     => $rights->declaration,
		subtitle                   => $mods_en->subtitle,
		description                => $mods_en->description,
		sequence_count             => scalar(@file_ids),
		page_count                 => scalar(@file_ids),
		dimensions                 => "",
		author_list                => [$mods_en->author],
		creator_list               => [],
		editor_list                => [],
		contributor_list           => [],
		publisher_list             => [$mods_en->publisher],
		publication_date           => $mods_en->pub_date_valid,
		publication_date_text      => $mods_en->pub_date,
		publication_location       => $mods_en->pub_loc,
		subject                    => [$mods_en->subject],
		topic                      => "",
		language_code              => $mods_en->lang_code,
		language                   => $mods_en->language,
		other_version              => "",
		call_number                => $mods_en->call_number,
		read_order_select          => $read_order,
		scan_order_select          => $scan_order,
		scan_date                  => "",
		scanning_notes             => "",
		binding_orientation_select => $orientation,
		ocr_text                   => "",
	};

	$log->debug("Updating en book $id");
	$book_en->update($vals);

	if (!$langs_avail->{Arab})
	{
		$log->warn("Arabic script does not exist for $id.");
		next;
	}

	my $mods_ar = MODS->new($mods_file, "Arab");
	
	my $book_ar = Node->new(
		obj => {
			identifier => $id,
			node_lang  => 'ar',
		}
	);
	$log->debug(Dumper($book_ar));

	$vals = {
		title                 => $mods_ar->title,
		isbn                  => "",
		rights                => $book_en->get_field('rights'),
		subtitle              => $mods_ar->subtitle,
		description           => $mods_en->description,
		sequence_count        => $book_en->get_field('sequence_count'),
		page_count            => $book_en->get_field('page_count'),
		dimensions            => "",
		author_list           => [$mods_ar->author],
		creator_list          => [],
		editor_list           => [],
		contributor_list      => [],
		publisher_list        => [$mods_ar->publisher],
		publication_date      => $mods_en->pub_date_valid,
		publication_date_text => $mods_en->pub_date,
		publication_location  => $mods_ar->pub_loc,
		subject               => [$mods_en->subject],
		topic                 => "",
		language_code         => $mods_en->lang_code,
		language              => $mods_en->language,
		other_version         => "",
		call_number           => "",
		read_order_select     => $book_en->get_field('read_order'),
		scan_order_select     => $book_en->get_field('scan_order'),
		scan_date             => "",
		scanning_notes        => "",
		binding_orientation_select =>
		  $book_en->get_field('binding_orientation'),
		ocr_text                 => "",
	};

	sleep(2);

	$log->debug("Updating ar book $id");
	$book_ar->update($vals);
}

