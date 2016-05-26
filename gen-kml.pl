#!/usr/bin/env perl
#
# Map books using KML.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use Data::Dumper;
use File::Copy;
use Getopt::Std;
use JSON;
use Log::Log4perl::Level;
use MODS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Util;
use XML::LibXML;


my $log = MyLogger->get_logger();

our $opt_q;  # quiet logging
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory base
our $opt_w;  # www directory
getopts('qr:t:w:');

# quiet mode
if ($opt_q)
{
	MyLogger->get_logger('Util')->level($WARN);
	$log->level($WARN)
}

my $tmpdir_base = $opt_t || config('tmpdir') || "/tmp";
my $tmpdir = tempdir(DIR => $tmpdir_base, CLEANUP => 1);
$log->debug("Temp directory: $tmpdir");

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

my $num_placemarks;

for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";
	if (!-f $mets_file)
	{
		$log->warn("METS file $mets_file doesn't exist.");
		next;
	}
	my $mets = SourceEntityMETS->new($mets_file);
	my $mods_file = $mets->get_mods_file;
	$log->debug("MODS file: $mods_file");
	my $mods = MODS->new($mods_file);
	my $mods_lang = $mods->get_languages();
	$mods->set_language("Latn") if $mods_lang->{Latn};

	my $tmp_file = "$tmpdir/${id}_geo_coord.json";
	my $coord_file = "$aux_dir/${id}_geo_coord.json";
	$log->debug("Coordinates file: $coord_file");
	my $coord;
	my $out;
	if (-f $coord_file)
	{
		local $/ = undef;
		open(my $in, "<$tmp_file")
		  or $log->logdie("can't open $tmp_file: $!");
		$coord = from_json(<$in>);
		close($in);
		move($tmp_file, $coord_file)
		  or $log->logdie("can't move $tmp_file to $coord_file: $!");
	}
	else
	{
		my $coord_list = $mods->geo_coordinates();
		if (!$coord_list)
		{
			$log->warn("Can't find coordinates for $id");
			next;
		}
		$log->debug(Dumper($coord_list));
		$coord = $coord_list->[0];
		my $json = to_json($coord, {utf8 => 1, pretty => 1});
		open($out, ">$coord_file")
		  or $log->logdie("can't open $coord_file: $!");
		print $out $json;
		close($out);
	}

	$num_placemarks++;
	
	my $lat = $coord->{latitude};
	my $lng = $coord->{longitude};
	$log->debug("Coordinates: $lat,$lng");

	my $placemark = $xml->createElement("Placemark");
	$document->appendChild($placemark);

	my $style_url = $xml->createElement("styleURL");
	$style_url->appendTextNode('#theBalloonStyle');
	my $name_placemark  = $xml->createElement("name");
	$name_placemark->appendTextNode($mods->title);
	my $description  = $xml->createElement("description");

	my $title = $mods->title;
	my $authors = join(' - ', $mods->author);
	my $publisher = $mods->publisher;
	my $location = $mods->pub_loc;
	my $date = $mods->pub_date_formatted;
	my $lang = $mods->language;
	my $desc_str = $mods->description || "";
	my $call_num = $mods->call_number || "";
	my $handle = Util::get_handle("$wip_dir/$id/handle");

	my $www_dir = $opt_w || $aux_dir;
	$tmp_file = "$tmp_dir/${id}_gmaps.html";
	my $maps_html_file = "$aux_dir/${id}_gmaps.html";
	$log->debug("Google maps html file: $maps_html_file");
	open($out, ">$tmp_file")
	  or $log->logdie("Can't open $tmp_file: $!");
	print $out <<EOF;
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="initial-scale=1.0, user-scalable=no">
    <meta charset="utf-8">
    <title>Info windows</title>
    <style>
      html, body {
        height: 100%;
        margin: 0;
        padding: 0;
      }
      #map {
        height: 100%;
      }
    </style>
  </head>
  <body>
    <div id="map"></div>
    <script>

      // This example displays a marker at the center of Australia.
      // When the user clicks the marker, an info window opens.

      function initMap() {
        var coord = {lat: $coord->{latitude}, lng: $coord->{longitude}};
        var map = new google.maps.Map(document.getElementById('map'), {
          zoom: 4,
          center: coord,
	      mapTypeId: google.maps.MapTypeId.HYBRID
        });

        var contentString = '<div id="content">'+
            '<div id="siteNotice">'+
            '</div>'+
            '<h1 id="firstHeading" class="firstHeading">$title</h1>'+
            '<div id="bodyContent">'+
            '<div>$desc_str</div>'+
            '<div>Author: $authors</div>'+
            '<div>Publisher: $publisher</div>'+
            '<div>Date: $date</div>'+
            '<div>Language: $lang</div>'+
            '<div>Call Number: $call_num</div>'+
            '<a href="http://hdl.handlle.net/$handle">Handle</a>'+
            '</div>'+
            '</div>';

        var infowindow = new google.maps.InfoWindow({
          content: contentString
        });

        var marker = new google.maps.Marker({
          position: coord,
          map: map,
          title: '$title'
        });
        marker.addListener('click', function() {
          infowindow.open(map, marker);
        });
      }
    </script>
    <script async defer
    src="https://maps.googleapis.com/maps/api/js?callback=initMap">
    </script>
  </body>
</html>
EOF
	close($out);
	move($tmp_file, $maps_html_file)
	  or $log->logdie("can't move $tmp_file to $maps_html_file: $!");

	# XXX: Google Maps API strips out CSS so figure out
	# hpw to circumvent this
# 	my $desc_html = <<EOF;
# 
#         <div class="left">
#           Title<br/>
#           Author<br/>
#           Publisher<br/>
#           Place of Publication<br/>
#           Publication Date<br/>
#           Language<br/>
#           Description<br/>
#           Call Number<br/>
#         </div>
#         <div>
#           <a href="http://hdl.handlle.net/$handle">$title</a><br/>
#           $authors<br/>
#           $publisher<br/>
#           $location<br/>
#           $date<br/>
#           $lang<br/>
#           $desc_str<br/>
#           $call_num<br/>
#         </div>
# EOF

	my $desc_html = <<EOF;
        <div>$desc_str</div>
        <div>
          <table>
            <tr>
              <td>Handle</td>
              <td><a href="http://hdl.handlle.net/$handle">$handle</a></td>
            </tr>
            <tr>
              <td>Author</td>
              <td>$authors</td>
            </tr>
            <tr>
              <td>Publisher</td>
              <td>$publisher, $location, $date</td>
            </tr>
            <tr>
              <td>Language</td>
              <td>$lang</td>
            </tr>
            <tr>
              <td>Call Number</td>
              <td>$call_num</td>
            </tr>
            <tr>
              <td>Geo Subject</td>
              <td>$coord->{location}</td>
            </tr>
          </table>
        </div>
EOF

	my $cdata_desc = $xml->createCDATASection($desc_html);
	$description->appendChild($cdata_desc);
	
	my $point = $xml->createElement("Point");
	my $coordinates = $xml->createElement("coordinates");
	$coordinates->appendTextNode("$lng,$lat,0");
	$point->appendChild($coordinates);

	$placemark->appendChild($style_url);
	$placemark->appendChild($name_placemark);
	$placemark->appendChild($description);
	$placemark->appendChild($point);
}

$xml->setDocumentElement($kml);

if ($num_placemarks)
{
	print $xml->toString(1);
}

