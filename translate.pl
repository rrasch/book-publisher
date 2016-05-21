#!/usr/bin/env perl
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use MODS;
use MyConfig;
use MyLogger;
use Node;
use SourceEntityMETS;
use Util;

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

our ($opt_f, $opt_r);
getopts('fr:');

my $wip_dir = ($opt_r || $ENV{RSTAR_DIR} || config('rstar_dir')) . "/wip/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

for my $id (@ids)
{
	$log->info("Processing $id");
	
	my $handle_file = "$wip_dir/$id/handle";
	my $data_dir    = "$wip_dir/$id/data";
	my $mets_file   = "$data_dir/${id}_mets.xml";

	my $mets = SourceEntityMETS->new($mets_file);
	my $mods_file = $mets->get_mods_file;

	$log->debug("MODS file: $mods_file");

	my $mods = MODS->new($mods_file);
	my $langs_avail = $mods->get_languages();

	if (!$langs_avail->{Arab})
	{
		$log->warn("Arabic script does not exist in MODS.");
		next;
	}

	$mods->set_language("Latn");
	my $mods_en = $mods;
	my $mods_ar = MODS->new($mods_file, "Arab");

	$log->debug('Arabic subjects:', join(',', $mods_ar->subject), '.');

	my $book_en = Node->new(obj => { identifier => $id });
	$log->debug(Dumper($book_en));

	if ($book_en->{node}{language} eq 'und')
	{
		$log->info("Changing the language of book $id from und to en.");
		$book_en->update({node_lang => 'en'});	
	}

	if (!$book_en->{node}{tnid})
	{
		$log->info("Setting tnid for book $id.");
		$book_en->update({tnid => $book_en->nid});
	}

	my $node = $book_en->{node};

	my $partner_nid = $node->{field_partner}{und}[0]{nid};
	my $partner = Node->new_from_nid($partner_nid);
	$log->debug("Partner nid: ", $partner->auto_nid());

	my $collection_nid = $node->{field_collection}{und}[0]{nid};
	my $collection = Node->new_from_nid($collection_nid);
	$log->debug("Collection nid: ", $collection->auto_nid());

	my $handle_link = {
		url => "http://hdl.handle.net/" . Util::get_handle($handle_file)
	};

	for my $field (sort keys %$node)
	{
		next unless $field =~ /^field_/;
		next unless ref($node->{$field}) eq "HASH";
		next unless exists($node->{$field}{en});
		$log->debug("$field");
	}

	my @pdf_fids = map { $_->{fid} } @{$node->{field_pdf_file}{en}};
	
	my $img_fid = $node->{field_representative_image}{en}[0]{fid};
	
	my $book_ar = {
		tnid                  => $book_en->nid,
		node_lang             => 'ar',
		node_type             => 'dlts_book',
# 		path                  => "books/$id",
		title                 => $mods_ar->title,
		pdf_file_fid          => [@pdf_fids],
		identifier            => $id,
		partner_ref           => $partner->auto_nid,
		collection_ref        => $collection->auto_nid,
		isbn                  => "",
		handle                => [$handle_link],
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
		representative_image_fid => [$img_fid],
		ocr_text                 => "",
	};

	$book_ar = Node->new(obj => $book_ar);
	$book_ar->update({node_lang => 'ar'});

	sleep(3);
}

