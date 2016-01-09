#!/usr/bin/env perl
#
# Author: Rasan Rasch

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use Data::Dumper;
use Getopt::Std;
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

my $doc = XML::LibXML::Document->new("1.0", "UTF-8");

my $root = $doc->createElement("kml");

my $doc_tag = $doc->createElement("Document");
$root->appendChild($doc_tag);

my $name_tag = $doc->createElement("name");
$name_tag->appendTextNode("Name");
$doc_tag->appendChild($name_tag);

for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";

	my $mets_file = "$data_dir/${id}_mets.xml";
	my $mets = SourceEntityMETS->new($mets_file);
	my $mods_file = $mets->get_mods_file;
	my $mods = MODS->new($mods_file);

	my $foo = $mods->geo_coordinates();
	my $lat = ${$foo}[0]{latitude};
	my $lng = ${$foo}[0]{longitude};
	$log->debug("Coordinates: $lat,$lng");
	
	my $placemark = $doc->createElement("Placemark");
	$doc_tag->appendChild($placemark);


	my $name  = $doc->createElement("name");
	$name->appendTextNode($mods->title);
	my $desc  = $doc->createElement("description");
	$desc->appendTextNode($mods->description);
	my $point = $doc->createElement("Point");
	my $coord = $doc->createElement("coordinates");
	$coord->appendTextNode("$lng,$lat,0");
	$point->appendChild($coord);
	
	$placemark->appendChild($name);
	$placemark->appendChild($desc);
	$placemark->appendChild($point);

	last;

}


$doc->setDocumentElement($root);

print $doc->toString(1);
