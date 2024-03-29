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
use warnings FATAL => qw[uninitialized];
use Cwd qw(abs_path getcwd);
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);
use Getopt::Std;
use JSON;
use Log::Log4perl::Level;
use Math::Trig;
use MODS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Util;
use XML::LibXML;

# use constant RADIUS_EARTH = 3963.1906; # miles
use constant RADIUS_EARTH => 6378.1370; # km

use constant LENGTH_AT_EQUATOR => (2 * pi * RADIUS_EARTH) / 360;

my $icon_url = "http://maps.google.com/mapfiles/kml/paddle";

my $highlight = {
	"Asia, Central" => 1,
	"Assyria" => 1,
	"Babylonia" => 1,
	"Kōs (Greece : Municipality)" => 1,
	"Middle East" => 1,
};

my $scale = {
	Egypt => 1.0,
	Iran => 1.0,
};

my $log = MyLogger->get_logger();

our $opt_f;  # force removal of coordinates file
our $opt_g;  # use google for geocoder
our $opt_q;  # quiet logging
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory base
our $opt_w;  # www directory
our $opt_c;  # pin color
getopts('fgqr:t:w:c:');

if ($opt_g && !$ENV{MAPS_API_KEY})
{
	$log->logdie("Must set envar MAPS_API_KEY for geocoder");
}

# quiet mode
if ($opt_q)
{
	MyLogger->get_logger('Util')->level($WARN);
	$log->level($WARN)
}

my $app_home = dirname(abs_path($0));

my $tmpdir_base = $opt_t || config('tmpdir') || "/tmp";
my $tmpdir = tempdir(DIR => $tmpdir_base, CLEANUP => 1);
$log->debug("Temp directory: $tmpdir");

my $rstar_dir = $opt_r || $ENV{RSTAR_DIR} || config('rstar_dir');

my @wip_dirs = map { "$_/wip/se" } split(/:/, $rstar_dir);

my @wip_ids = @ARGV;

if (@wip_dirs > 1 && @wip_ids)
{
	$log->logdie("Can't set wip ids if specifying multiple rstar dirs.");
}

my $agent = WWW::Mechanize->new();
$agent->max_redirect(0);

my $api_key = config('gmaps_api_key') || "";

my $xml = XML::LibXML::Document->new("1.0", "UTF-8");

my $kml = $xml->createElementNS("http://www.opengis.net/kml/2.2", "kml");

my $document = $xml->createElement("Document");
$kml->appendChild($document);

my $name_document = $xml->createElement("name");
$name_document->appendTextNode("Book KML");
$document->appendChild($name_document);

# my $style = $xml->createElement("Style");
# $style->setAttribute("id", "theBalloonStyle");
# my $balloon_style = $xml->createElement("BalloonStyle");
# my $text = $xml->createElement("text");
# my $cdata_style = $xml->createCDATASection(
# 	'<div class="maps-balloon">$[description]</div>');
# 
# $text->appendChild($cdata_style);
# $balloon_style->appendChild($text);
# my $color = $xml->createElement("color");
# $color->appendTextNode('ffffff');
# $balloon_style->appendChild($color);
# $style->appendChild($balloon_style);
# $document->appendChild($style);

# my @colors = qw(red blu grn ylw purple pink);
my @colors = qw(red blu grn purple pink);
for my $color (@colors, "ylw")
{
	$document->appendChild(new_style($xml, $color));
}

my $num_placemarks = 0;

for my $wip_dir (@wip_dirs)
{
	my @ids = @wip_ids ? @wip_ids : Util::get_dir_contents($wip_dir);

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
		my $mets      = SourceEntityMETS->new($mets_file);
		my $mods_file = $mets->get_mods_file;
		$log->debug("MODS file: $mods_file");
		if (!-f $mods_file)
		{
			$log->warn("MODS file $mods_file doesn't exist.");
			next;
		}
		my $mods      = MODS->new($mods_file);
		my $mods_lang = $mods->get_languages();
		$mods->set_language("Latn") if $mods_lang->{Latn};

		my $handle = Util::get_handle("$wip_dir/$id/handle");
		my $handle_url = "http://hdl.handle.net/$handle";
		my $res = $agent->get($handle_url);
		my $loc = $res->header('location') || "";
		if ($loc =~ /object-in-processing/)
		{
			$log->debug("$id is object-in-processing ... Skipping");
			next;
		}

		my $tmp_file   = "$tmpdir/${id}_geo_coord.json";
		my $coord_file = "$aux_dir/${id}_geo_coord.json";
		$log->debug("Coordinates file: $coord_file");
		my $coord;
		my $out;

		if ($opt_f && -f $coord_file)
		{
			$log->debug("Removing $coord_file.");
			unlink($coord_file)
				or $log->logdie("Can't unlink $coord_file: $!");
		}

# 		if (-f $coord_file)
# 		{
# 			$coord = read_coords_from_file($coord_file);
# 		}
# 		else
# 		{
# 			my $coord_list = $mods->geo_coordinates();
# 			if (!$coord_list)
# 			{
# 				$log->warn("Can't find coordinates for $id");
# 				next;
# 			}
# 			$log->debug(Dumper($coord_list));
# 			$coord = $coord_list->[0];
# 			my $json = to_json($coord, {utf8 => 1, pretty => 1});
# 			open($out, ">$tmp_file")
# 			  or $log->logdie("can't open $tmp_file: $!");
# 			print $out $json;
# 			close($out);
# 			move($tmp_file, $coord_file)
# 			  or $log->logdie("can't move $tmp_file to $coord_file: $!");
# 		}

		if (! -f $coord_file)
		{
			my $geo_cmd = "$app_home/geo-coords.py";
# 			$geo_cmd .= " --debug" unless $opt_q;
			$geo_cmd .= " -g google" if $opt_g;
			$geo_cmd .= " $mods_file $coord_file";
			my $output = sys($geo_cmd, {warnErrors => 1});
		}

		if (! -f $coord_file)
		{
			$log->debug("Couldn't find coordinates. Skipping ...");
			next;
		}

		$coord = read_coords_from_file($coord_file);

		my $area = sys("$app_home/lookup-area.py",
			$coord->{location}, {warnErrors => 1}) || 0;

		$log->debug("Area $coord->{location}: $area");

		# Calculate max jitter as 1/3 of radius of
		# circle with area equal to that of the location
		my $max_jitter = int(sqrt($area / pi) / 3);

		my $lat = $coord->{latitude};
		my $lng = $coord->{longitude};

		$log->debug("Coordinates: $lat,$lng");

# 		$lat = jitter($lat, $scale->{$coord->{location}});
# 		$lng = jitter($lng, $scale->{$coord->{location}});

		$lat = jitter_latlong($lat, "lat", $lat, $max_jitter);
		$lng = jitter_latlong($lng, "lng", $lat, $max_jitter);

		$log->debug("Jittered Coordinates: $lat,$lng");

		my $pin_color;
		if ($opt_c) {
			$pin_color = $opt_c;
		} elsif ($highlight->{$coord->{location}}) {
			$pin_color = "ylw";
		} else {
			$pin_color = $colors[$num_placemarks % @colors];
		}

		my $placemark = $xml->createElement("Placemark");
		$placemark->setAttribute('id', $id);
		$document->appendChild($placemark);
		my $style_url = $xml->createElement("styleUrl");
		$style_url->appendTextNode("#${pin_color}pin");
		my $name_placemark = $xml->createElement("name");
		$name_placemark->appendTextNode($mods->title);
		my $description = $xml->createElement("description");

		my $title     = $mods->title;
		my $subtitle  = $mods->subtitle || "";
		my $authors   = join(' - ', $mods->author);
		my $publisher = $mods->publisher || "";
		my $location  = $mods->pub_loc || "";
		my $date      = $mods->pub_date_formatted;
		my $lang      = $mods->language;
		my $desc_str  = $mods->description || "";
		my $call_num  = $mods->call_number || "";
		my $geo_subj  = $mods->geo_subject;

		my $www_dir = $opt_w || $aux_dir;
		$tmp_file = "$tmpdir/${id}_gmaps.html";
		my $maps_html_file = "$www_dir/${id}_gmaps.html";
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
            '<div>Handle: '+
            '<a target="_blank" rel="noopener noreferrer" '+
            'href="http://hdl.handle.net/$handle">$handle</a>'+
            '</div>'+
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
    src="https://maps.googleapis.com/maps/api/js?callback=initMap&key=$api_key">
    </script>
  </body>
</html>
EOF
		close($out);
		move($tmp_file, $maps_html_file)
		  or $log->logdie("can't move $tmp_file to $maps_html_file: $!");

# 		# XXX: Google Maps API strips out CSS so figure out
# 		# hpw to circumvent this
# 		my $desc_html = <<EOF;
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
#           <a href="http://hdl.handle.net/$handle">$title</a><br/>
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
              <td>Title</td>
              <td><a href="http://hdl.handle.net/$handle">$title</a></td>
            </tr>
            <tr>
              <td>Subtitle</td>
              <td>$subtitle</td>
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
              <td>$geo_subj</td>
            </tr>
            <tr>
              <td>ID</td>
              <td>$id</td>
            </tr>
          </table>
        </div>
EOF

		my $cdata_desc = $xml->createCDATASection($desc_html);
		$description->appendChild($cdata_desc);

		my $point       = $xml->createElement("Point");
		my $coordinates = $xml->createElement("coordinates");
		$coordinates->appendTextNode("$lng,$lat,0");
		$point->appendChild($coordinates);

		$placemark->appendChild($style_url);
		$placemark->appendChild($name_placemark);
		$placemark->appendChild($description);
		$placemark->appendChild($point);

		$num_placemarks++;
	}
}

$xml->setDocumentElement($kml);

if ($num_placemarks)
{
	print $xml->toString(1);
}


sub read_coords_from_file
{
	my $coord_file = shift;
	local $/ = undef;
	open(my $in, "<$coord_file")
	  or $log->logdie("can't open $coord_file: $!");
	my $coord = from_json(<$in>);
	close($in);
	return $coord;
}


# from perl cookbook
# 2.10. Generating Biased Random Numbers
sub gaussian_rand
{
	my ($u1, $u2);    # uniformly distributed random numbers
	my $w;            # variance, then a weight
	my ($g1, $g2);    # gaussian-distributed numbers

	do
	{
		$u1 = random();
		$u2 = random();
		$w  = $u1 * $u1 + $u2 * $u2;
	} while ($w >= 1 || $w == 0);

	$w  = sqrt((-2 * log($w)) / $w);
	$g2 = $u1 * $w;
	$g1 = $u2 * $w;
	# return both if wanted, else just one
	return wantarray ? ($g1, $g2) : $g1;
}


sub jitter
{
	my ($mean, $dev) = @_;
	$dev ||= 0.5;
	return scalar(gaussian_rand()) * $dev + $mean;
}


sub new_style
{
	my ($xml, $color_name) = @_;

	my $style = $xml->createElement("Style");
	$style->setAttribute("id", "${color_name}pin");

	my $balloon_style = $xml->createElement("BalloonStyle");
	my $text          = $xml->createElement("text");
	my $cdata_style   = $xml->createCDATASection(
		'<div class="maps-balloon">$[description]</div>');
	$text->appendChild($cdata_style);
	$balloon_style->appendChild($text);
	$style->appendChild($balloon_style);

	my $icon_style = $xml->createElement("IconStyle");
# 	my $color = $xml->createElement("color");
# 	$color->appendTextNode('ffffffff');
# 	$icon_style->appendChild($color);
# 	my $scale = $xml->createElement("scale");
# 	$scale->appendTextNode('1.0');
# 	$icon_style->appendChild($scale);
	my $icon = $xml->createElement("Icon");
	my $href = $xml->createElement("href");
	my $pin_url = "$icon_url/$color_name-square.png";
	$href->appendTextNode($pin_url);
	$icon->appendChild($href);
	$icon_style->appendChild($icon);
	$style->appendChild($icon_style);

	return $style;
}


sub random
{
	return 2 * rand() - 1;
}


sub jitter_latlong
{
	my ($coord, $type, $latitude, $km) = @_;
	$latitude = $coord if !defined($latitude) && $type == "lat";
	$km ||= 5;
	my $km_per_degree = length_of_degree($latitude, $type);
	my $degree_per_km = 1 / $km_per_degree;
	return $coord + (random() * $degree_per_km * $km);
}


sub length_of_degree
{
	my ($degree, $type) = @_;
	if ($type eq "lat") {
		return LENGTH_AT_EQUATOR;
	} elsif ($type eq "lng") {
		return cos($degree * (2 * pi) / 360) * LENGTH_AT_EQUATOR;
	}
}

