#!/usr/bin/env perl
#
# Map books using KML.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
use JSON;
use MODS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Util;
use XML::LibXML;


our $opt_r;  # rstar directory
getopts('r:');

my $log = MyLogger->get_logger();

my $wip_dir = ($opt_r || $ENV{RSTAR_DIR} || config('rstar_dir')) . "/wip/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

my $xml = XML::LibXML::Document->new("1.0", "UTF-8");

my $kml = $xml->createElement("kml");

my $document = $xml->createElement("Document");
$kml->appendChild($document);

my $name_document = $xml->createElement("name");
$name_document->appendTextNode("Book KML");
$document->appendChild($name_document);

my $style = $xml->createElement("Style");
$style->setAttribute("id", "theBalloonStyle");
my $balloon_style = $xml->createElement("BallonStyle");
my $text = $xml->createElement("text");
my $cdata_style = $xml->createCDATASection(
	'<div class="maps-balloon">$[description]</div>');

$text->appendChild($cdata_style);
$balloon_style->appendChild($text);
$style->appendChild($balloon_style);
$document->appendChild($style);


for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";
	my $mets = SourceEntityMETS->new($mets_file);
	my $mods_file = $mets->get_mods_file;
	my $mods = MODS->new($mods_file);
	my $mods_lang = $mods->get_languages();
	$mods->set_language("Latn") if $mods_lang->{Latn};

	my $coord_file = "$aux_dir/${id}_geo_coord.json";
	my $coord;
	if (-f $coord_file)
	{
		local $/ = undef;
		open(my $in, "<$coord_file")
		  or $log->logdie("can't open $coord_file: $!");
		$coord = from_json(<$in>);
		close($in);
	}
	else
	{
		my $coord_list = $mods->geo_coordinates();
		$log->debug(Dumper($coord_list));
		$coord = $coord_list->[0];
		my $json = to_json($coord, {utf8 => 1, pretty => 1});
		open(my $out, ">$coord_file")
		  or $log->logdie("can't open $coord_file: $!");
		print $out $json;
		close($out);
	}
	
	my $lat = $coord->{latitude};
	my $lng = $coord->{longitude};
	$log->debug("Coordinates: $lat,$lng");

	my $placemark = $xml->createElement("Placemark");
	$document->appendChild($placemark);

	my $style_url = $xml->createElement("styleURL");
	$style_url->appendTextNode('#theBalloonStyle');
	my $name_placemark  = $xml->createElement("name");
	$name_placemark->appendTextNode($mods->title);
	my $desc  = $xml->createElement("description");

	my $title = $mods->title;
	my $authors = join(' - ', $mods->author);
	my $publisher = $mods->publisher;
	my $location = $mods->pub_loc;
	my $date = $mods->pub_date_formatted;
	my $lang = $mods->language;
	my $desc_str = $mods->description || "";
	my $call_num = $mods->call_number || "";
	my $handle = Util::get_handle("$wip_dir/$id/handle");

	my $desc_html = <<EOF;

        <div class="left">
          Title<br/>
          Author<br/>
          Publisher<br/>
          Place of Publication<br/>
          Publication Date<br/>
          Language<br/>
          Description<br/>
          Call Number<br/>
        </div>
        <div>
          <a href="http://hdl.handlle.net/$handle">$title</a><br/>
          $authors<br/>
          $publisher<br/>
          $location<br/>
          $date<br/>
          $lang<br/>
          $desc_str<br/>
          $call_num<br/>
        </div>
EOF

	my $cdata_desc = $xml->createCDATASection($desc_html);
	$desc->appendChild($cdata_desc);
	
	my $point = $xml->createElement("Point");
	my $coordinates = $xml->createElement("coordinates");
	$coordinates->appendTextNode("$lng,$lat,0");
	$point->appendChild($coordinates);

	$placemark->appendChild($style_url);
	$placemark->appendChild($name_placemark);
	$placemark->appendChild($desc);
	$placemark->appendChild($point);
}

$xml->setDocumentElement($kml);

print $xml->toString(1);

