#!/usr/bin/env perl
#
# Script to import books into generic books drupal site via services module.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use utf8;
use Cwd qw(abs_path);
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use File::Basename;
use File::Copy;
use Getopt::Std;
use HTML::TreeBuilder;
use IntellectualEntityMETS;
use MARC;
use METSRights;
use MODS;
use MyConfig;
use MyLogger;
use Node;
use RStar;
use SourceEntityMETS;
use Util qw(getval);


$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub { $log->logdie(@_) };

our ($opt_p, $opt_r);
getopts('pr:');
my $rstar_dir = $opt_r || $ENV{RSTAR_DIR} || config('rstar_dir');

my $wip_dir = "$rstar_dir/wip";

my @ie_ids = @ARGV ? @ARGV : Util::get_dir_contents("$wip_dir/ie");

# Connect to rstar collection info api
my $rstar = RStar->new(
	user            => config('rstar_api_user'),
	pass            => config('rstar_api_pass'),
	partner_file    => "$rstar_dir/../partner_url",
	collection_file => "$rstar_dir/collection_url",
);

my $partner_info = $rstar->get_partner_info();

my $partner = {
	node_type  => 'dlts_partner',
	path       => "partner/$partner_info->{id}",
	title      => $partner_info->{name},
	identifier => $partner_info->{id},
	code       => $partner_info->{code},
	name       => $partner_info->{name},
};

$partner = Node->new(obj => $partner);
my $partner_nid = mknid($partner);

my $collection_info = $rstar->get_collection_info();

my $collection = {
	node_type   => 'dlts_collection',
	path        => "collection/$collection_info->{id}",
	title       => $collection_info->{name},
	identifier  => $collection_info->{id},
	code        => $collection_info->{code},
	name        => $collection_info->{name},
	partner_ref => $partner_nid,
};

$collection = Node->new(obj => $collection);
my $collection_nid = mknid($collection);

for my $ie_id (@ie_ids)
{
	$log->info("Processing $ie_id");
	
	my $ie_data_dir = "$wip_dir/ie/$ie_id/data";

	my $ie_mets_file = "$ie_data_dir/${ie_id}_mets.xml";

	if (!-f $ie_mets_file)
	{
		$log->warn(
			"Intellectual entity mets file $ie_mets_file doesn't exist.");
		next;
	}
	$log->debug("IE METS file: $ie_mets_file");

	my $ie_mets = IntellectualEntityMETS->new($ie_mets_file);
	
	# Get listing of source entitites in IE mets file
	my @source_entities = $ie_mets->get_source_entities();

	# If there are multiple source entities, that means this is a
	# multi-volume collection.
	my $multivol_id;
	my $multivol_nid;
	if (@source_entities > 1)
	{
		my $handle = Util::get_handle("$wip_dir/ie/$ie_id/handle");
		my $handle_link = {
			url   => "http://hdl.handle.net/$handle",
			title => "Multi-Volume $ie_id Book Handle",
		};
		$multivol_id = $ie_id;
		my $multivol = {
			node_type  => 'dlts_multivol',
			path       => "multivol/$multivol_id",
			identifier => $multivol_id,
			title      => "Multi-Volume $multivol_id",
			handle     => [$handle_link],
		};
		$multivol = Node->new(obj => $multivol);
		$multivol_nid = mknid($multivol);
	}

	for my $se (@source_entities)
	{
		$log->debug("SE METS \#$se->{order_num}: $se->{mets_file}");

		if (!-f $se->{mets_file})
		{
			$log->warn(
				"Source entity mets file $se->{mets_file} doesn't exist.");
			next;
		}

		my $se_mets = SourceEntityMETS->new($se->{mets_file});

		# find source SE id
		my $se_id = $se_mets->get_id();
		$log->debug("Source Entity ID = $se_id");

		my $page_nids = Node::get_page_nodeids($se_id);

		# get list of file ids in book
		my @file_ids = $se_mets->get_file_ids();

		# get binding orientation, scan order, read order info
		my %scan_data = $se_mets->scan_data();
		for my $k (keys %scan_data)
		{
			$log->debug("$k: $scan_data{$k}");
		}

		my $rights_file = $se_mets->get_rights_file;
		my $rights = METSRights->new($rights_file);

		my $mods_file = $se_mets->get_mods_file();
		$log->debug($mods_file);

		my $mods = MODS->new($mods_file);
		my $mods_lang = $mods->get_languages();
		$mods->set_language("Latn") if $mods_lang->{Latn};

		my $title = $mods->title;
		$log->debug("Title: $title");
		
		$log->debug("Author: ", $mods->author);

		my $publisher = $mods->publisher || "";
		$log->debug("Publisher: $publisher");

		my @subjects = $mods->subject;

		my $se_data_dir = "$wip_dir/se/$se_id/data";
		my $se_aux_dir  = "$wip_dir/se/$se_id/aux";

		my @pdf_files = ();
		if (!$opt_p)
		{
			for my $res (qw(hi lo))
			{
				my $pdf_file = "$se_aux_dir/${se_id}_${res}.pdf";
				if (-f $pdf_file) {
					push(@pdf_files, $pdf_file);
				} else {
					$log->warn("PDF file $pdf_file doesn't exist.");
				}
			}
		}

		my $thumb_file = "$se_aux_dir/${se_id}_thumb.jpg";

		my $handle_file = "$wip_dir/se/$se_id/handle";

		my $orientation =
		  $scan_data{binding_orientation} =~ /^horizontal$/i ? 1 : 0;
		my $read_order =
		  $scan_data{read_order} =~ /^right(2|_to_)left$/i ? 1 : 0;
		my $scan_order =
		  $scan_data{scan_order} =~ /^right(2|_to_)left$/i ? 1 : 0;

		$log->debug("Binding Orientation: $orientation");
		$log->debug("Read Order: $read_order");
		$log->debug("Scan Order: $scan_order");

		my $handle      = Util::get_handle($handle_file);
		my $handle_desc = "$title Book Handle";

		my $handle_link = {
			url   => "http://hdl.handle.net/$handle",
			title => $handle_desc,
		};

		if (!-f $thumb_file)
		{
			my $svc_file = "$se_aux_dir/${file_ids[0]}_s.jpg";
			copy($svc_file, $thumb_file)
			  or $log->logdie("can't copy $svc_file to $thumb_file: $!");
		}

		my $book = {
			node_type                  => 'dlts_book',
			files_subdir               => $se_id,
			path                       => "books/$se_id",
			title                      => $title,
			pdf_file_filelist          => [@pdf_files],
			identifier                 => $se_id,
			partner_ref                => $partner_nid,
			collection_ref             => $collection_nid,
			isbn                       => "",
			handle                     => [$handle_link],
			rights                     => $rights->declaration,
			subtitle                   => $mods->subtitle,
			description                => $mods->description,
			sequence_count             => scalar(@file_ids),
			page_count                 => scalar(@file_ids),
			dimensions                 => "",
			author_list                => [$mods->author],
			creator_list               => [],
			editor_list                => [],
			contributor_list           => [],
			publisher_list             => [$mods->publisher],
			publication_date           => $mods->pub_date_sort,
			publication_date_text      => $mods->pub_date_formatted,
			publication_location       => $mods->pub_loc,
			subject                    => [@subjects],
			topic                      => "",
			language_code              => $mods->lang_code,
			language                   => $mods->language,
			other_version              => "",
			call_number                => $mods->call_number,
			read_order_select          => $read_order,
			scan_order_select          => $scan_order,
			scan_date                  => "",
			scanning_notes             => "",
			binding_orientation_select => $orientation,
			representative_image_file  => $thumb_file,
			ocr_text                   => "",
		};

		$book = Node->new(obj => $book);

		if (config('update_handles'))
		{
			$log->debug("Updating handle $handle");
			Util::update_handle($handle, $book->nid(), "");
			$log->debug("done");
		}

		my $book_nid = mknid($book);
		$log->debug("book nid: $book_nid");

		if ($multivol_id)
		{
			my $multivol_book_id = "${multivol_id}_${se_id}";
			my $multivol_book = {
				node_type         => 'dlts_multivol_book',
				path              => "books/$multivol_book_id",
				title             => $title,
				identifier        => $multivol_book_id,
				book_ref          => $book_nid,
				multivol_ref      => $multivol_nid,
				collection_ref    => $collection_nid,
				volume_number     => $se->{order_num},
				volume_number_str => $se->{order_label},
			};
			$multivol_book = Node->new(obj => $multivol_book);
		}

		for my $series_info ($mods->series)
		{
			my $series_id = "series_" . md5_hex($series_info->{name});
			my $series = {
				node_type  => 'dlts_series',
				title      => $series_info->{name},
				path       => "series/$series_id",
				identifier => $series_id,
			};
			$series = Node->new(obj => $series);
			my $series_nid = mknid($series);

			my $series_book_id = "${series_id}_${se_id}";
			my $series_book = {
				node_type          => 'dlts_series_book',
				path               => "books/$series_book_id",
				title              => $title,
				identifier         => $series_book_id,
				book_ref           => $book_nid,
				series_ref         => $series_nid,
				collection_ref     => $collection_nid,
				volume_number      => $series_info->{volume_num},
				volume_number_str  => $series_info->{volume_str},
			};
			$series_book = Node->new(obj => $series_book);
		}

		my $img_num = 0;
		for my $file_id (@file_ids)
		{
			$img_num++;

			if ($page_nids->{$img_num})
			{
				$log->info("Page node already exists for page $img_num.");
				next;
			}

			my $hand_side = $img_num % 2 ? 0 : 1;

			my $jp2_file = "$se_aux_dir/${file_id}_d.jp2";
			my $jpg_file = "$se_aux_dir/${file_id}_s.jpg";

			my $page = {
				node_type           => 'dlts_book_page',
				files_subdir        => $se_id,
				path                => "books/$se_id/$img_num",
				title               => "$title Page Image $img_num",
				book_ref            => $book_nid,
				sequence_number     => $img_num,
				real_page_number    => $img_num,
				page_type_select    => 0,
				hand_side_select    => $hand_side,
				cropped_master_file => $jp2_file,
				service_copy_file   => $jpg_file,
				ocr_text            => "",
				is_part_of          => $se_id,
			};

			$page = Node->new(obj => $page);

			my $page_nid = mknid($page);
			$log->debug("page nid: $page_nid");

		}

		my $i = 0;

		while ($i < @file_ids)
		{
			my $is_cover_or_back = $i == 0 || $i == $#file_ids;

			my $left_img_num = $i + 1;

			my $right_img_num;
			if ($is_cover_or_back)
			{
				$right_img_num = $i + 1;
				$i++;
			}
			else
			{
				$right_img_num = $i + 2;
				$i += 2;
			}

			my $stitch_index = "$left_img_num-$right_img_num";
			if ($page_nids->{$stitch_index})
			{
				$log->info(
					"Stitched page node already exists for page $stitch_index."
				);
				next;
			}

			my $left_page_num  = $left_img_num;
			my $right_page_num = $right_img_num;

			my $stitch_file = "$se_aux_dir/"
			  . stitch_basename($se_id, $left_img_num, $right_img_num) . ".jp2";

			my $stitched_page_title =
			  "$title Stitched Page $left_img_num - $right_img_num";

			my $stitched_page = {
				node_type             => 'dlts_book_stitched_page',
				files_subdir          => $se_id,
				path                  => "books/$se_id/$stitch_index",
				title                 => $stitched_page_title,
				book_ref              => $book_nid,
				sequence_number_left  => $left_img_num,
				sequence_number_right => $right_img_num,
				page_number_left      => $left_page_num,
				page_number_right     => $right_page_num,
				stitch_image_file     => $stitch_file,
				is_part_of            => $se_id,
			};

			$stitched_page = Node->new(obj => $stitched_page);

		}

	}

}


sub get_real_page_num
{
	my $slot = shift;
	my $label = getval('./@label', $slot);
	my $page_num = 0;
	if ($label =~ /_(\d+)(_\d{2})?$/) {
		$page_num = $1 + 0;
	}
	return $page_num;
}


sub mknid
{
	my ($node) = @_;
	my $title = $node->title();
	my $nid = $node->nid();
	return "$title [nid:$nid]";
}


sub stitch_basename
{
	my ($book_id, $page_num_1, $page_num_2) = @_;
	return "${book_id}_2up_"
	  . join("_", map(Util::zeropad($_), $page_num_1, $page_num_2));
}


