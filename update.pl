#!/usr/bin/env perl
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
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

my $rstar_dir = $opt_r || config('rstar_dir');

my $wip_dir = "$rstar_dir/wip/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

my $partner;
my $collection;

for my $id (@ids)
{

	$log->info("Processing $id");
	
	my $handle_file = "$wip_dir/$id/handle";

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir =  "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";

	my $mets = SourceEntityMETS->new($mets_file);

	my $rights_file = $mets->get_rights_file;

	$log->debug("METSRights file: $rights_file");

	my $rights = METSRights->new($rights_file);

	$log->debug($rights->declaration);

	my $mods_file = $mets->get_mods_file;
	
	$log->debug("MODS file: $mods_file");

	my $mods = MODS->new($mods_file);
	my $mods_lang = $mods->get_languages();
	$mods->set_language("Latn") if $mods_lang->{Latn};

	my @authors = $mods->author;
	$log->debug("Authors: ", @authors);

	my @subjects = $mods->subject;

	my $title = $mods->title;

	my $book = Node->new(obj => { identifier => $id });

	my $lang = $book->{node}{language};

	$log->debug(Dumper($book));

# 	my $field_pdf = $book->{node}{field_pdf_file}{$lang};
# 	my $num_pdfs = @$field_pdf;
# 	$log->debug("Num pdfs: $num_pdfs");
# 	if ($num_pdfs == 2)
# 	{
# 		$log->info("Skipping $id");
# 		next;
# 	}
# 
# 	my $fid = $field_pdf->[0]{fid};
# 	$log->debug("Fid: $fid");

	my @pdf_files = map { "$aux_dir/${id}_${_}.pdf" } qw(hi lo);

# 	if (!$partner)
# 	{
# 		my $coll_nid = $book->{node}{field_collection}{und}[0]{nid};
# 		$collection = Node->new_from_nid($coll_nid);
# 		my $partner_nid = $collection->{node}{field_partner}{und}[0]{nid};
# 		$partner = Node->new_from_nid($partner_nid);
# 	}
# 
# 	my $handle = Util::get_handle($handle_file);
# 	my $handle_desc = "$title Book Handle";
# 
# 	my $handle_link = {
# 		url   => "http://hdl.handle.net/$handle",
# 		title => $handle_desc,
# 	};

	my $vals = {
		files_subdir               => $id,
# 		node_lang                  => 'en',
# 		partner_ref                => $partner->auto_nid,
# 		collection_ref             => $collection->auto_nid,
# 		author_list                => [(undef) x 5],
# 		author_list                => [$mods->author],
# 		publisher_list             => [(undef) x 5],
# 		publisher_list             => [$mods->publisher],
# 		subject                    => [],
# 		subject                    => [$mods->subject],
# 		title                      => $title,
# 		subtitle                   => $mods->subtitle,
# 		handle                     => [$handle_link],
# 		rights                     => $rights->declaration,
# 		publication_date           => $mods->pub_date_valid,
# 		publication_date_text      => $mods->pub_date,
# 		publication_location       => $mods->pub_loc,
# 		read_order_select          => $book->get_field("read_order"),
# 		scan_order_select          => $book->get_field("scan_order"),
# 		binding_orientation_select => $book->get_field("binding_orientation"),
# 		pdf_file_fid               => [ $fid, $fid + 1 ],
# 		pdf_file_fid               => [(undef) x 5],
		pdf_file_filelist          => [@pdf_files],
	};

	$log->debug("Updating book $id");
	$book->update($vals);

	sleep(2);
}

