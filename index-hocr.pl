#!/usr/bin/perl
#
# Script to index hOCR files into Solr.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use strict;
use warnings;
use HTML::TreeBuilder;
use WebService::Solr;
use XML::LibXML;
use MyConfig;
use MyLogger;
use Util qw(getval);

my $book_id = "book000001";

my $log = MyLogger->get_logger();

my $solr_url = config('solr_url');

my $solr = WebService::Solr->new($solr_url);

if (!$solr->ping()) {
	$log->logdie("Can't ping solr at $solr_url");
}

# $solr->delete_by_query('*:*');

my $wip_dir = config('rstar_dir') . "/wip";

my $aux_dir  = "$wip_dir/$book_id/aux";

my $xpc = XML::LibXML::XPathContext->new();
$xpc->registerNs("b", "http://dlib.nyu.edu/rstar");

my $struct_file = "$wip_dir/$book_id/$book_id-struct.xml";
$log->debug("Struct map file: $struct_file");

my $struct = XML::LibXML->load_xml(location => $struct_file);

my $slot_path =
  "/b:book-srcs/b:book-src[\@label='$book_id']/b:book-slots/b:book-slot";

for my $slot ($xpc->findnodes($slot_path, $struct))
{
	my $label = getval($xpc, './@label', $slot);
	my $img_num = getval($xpc, './@imaging-num', $slot);

	my $hocr_file = "$aux_dir/${label}_ocr.html.new";
	$log->debug("hocr file: $hocr_file");

	my $tree = HTML::TreeBuilder->new;

	$tree->parse_file($hocr_file);

	my ($page) = $tree->find_by_attribute('class', 'ocr_page');
	my $page_title = $page->attr('title') || "";
	if ($page_title !~ /bbox 0 0 (\d+) (\d+)$/) {
		$log->logdie("Can't find image dimensions");
	}
	my ($width, $height) = ($1, $2);

	my @words = $tree->find_by_attribute('class', 'ocr_word');

	for my $word (@words)
	{
		my $doc = WebService::Solr::Document->new;

		my $id = $word->attr('id');
		$id =~ s/^word_1_/${book_id}_${img_num}_/;

		my $word_text   = $word->as_text;
		utf8::encode($word_text);
		my $cleaned_word = $word_text;
		$cleaned_word =~ tr/a-zA-Z0-9//cd;
		if (!$cleaned_word)
		{
			$log->trace("Skipping word: '$word_text'");
			next;
		}

		my $tess_cords  = $word->attr('title');
		$tess_cords =~ s/bbox\s+//;

		my $ol_cords = calc_openlayers_coords($tess_cords, $height);

		$doc->add_fields(new_field("id",                $id));
		$doc->add_fields(new_field("word",              $word_text));
		$doc->add_fields(new_field("tesseract_coords",  $tess_cords));
		$doc->add_fields(new_field("openlayers_coords", $ol_cords));
		$doc->add_fields(new_field("collection",        "books"));
		$doc->add_fields(new_field("type",              "books"));
		$doc->add_fields(new_field("item_id",           $book_id));
		$doc->add_fields(new_field("seq_num",           $img_num));

		$log->trace($doc->to_xml());

		$log->trace("Indexing word: '$word_text'");
		$solr->add($doc);
	}

}


sub new_field
{
	WebService::Solr::Field->new(@_);
}


sub calc_openlayers_coords
{
	my ($tess_coords, $height) = @_;
	my @coords = split(" ", $tess_coords);
	return join(" ",
		$coords[0], $height - $coords[3],
		$coords[2], $height - $coords[1]);
}

