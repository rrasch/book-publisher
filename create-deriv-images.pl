#!/usr/bin/env perl
#
# Create derivative images (jpg, jp2, tifs) from master tif files.
# Script creates jpg thumbnails, jpeg-2000 files to be displayed
# by the hi-res djatoka image viewer, and tif files to be used in
# pdf creation.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use Cwd qw(abs_path);
use Data::Dumper;
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);
use Getopt::Std;
use Image::ExifTool qw(:Public);
use Log::Log4perl::Level;
use MyConfig;
use MyLogger;
use Statistics::Descriptive;
use Sys::Hostname;
use Util;


$SIG{HUP} = 'IGNORE';

my $bin_dir = "/usr/local/adore-djatoka-1.1/bin";

my $kdu_compress = "/usr/bin/kdu_compress";

my $log = MyLogger->get_logger();

$SIG{__WARN__} = sub {
# 	local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
	$log->logdie(@_);
};

my $tmpdir = tempdir(CLEANUP => 1);

my $host = hostname();

# find directory where this script resides
my $app_home = dirname(abs_path($0));

my $kdurc_file = "$app_home/conf/kdurc";

our ($opt_f, $opt_q, $opt_r);
getopts('fqr:');

# quiet mode
if ($opt_q)
{
	MyLogger->get_logger('Util')->level($WARN);
	$log->level($WARN)
}

my $wip_dir = ($opt_r || config('rstar_dir')) . "/wip/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

# chdir($bin_dir) or $log->logdie("Can't chdir $bin_dir: $!");

for my $id (@ids)
{
	$log->info("Processing $id");
	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

# 	my @deriv_mkrs = sort(glob("$data_dir/$id*d.tif"));
	my @deriv_mkrs = sort(glob("$data_dir/*d.tif"));

	if (!@deriv_mkrs)
	{
		$log->warn("There are no images in $data_dir ... skipping $id");
		next;
	}

	my @exif_data;

	my $stat = Statistics::Descriptive::Full->new();

	# Go through each image in the book and find it's resolution.
	# We do this so we can set the most frequently found resolution
	# to each image.  That way we don't have size mismatches when
	# we produce a pdf of all the images
	for (my $i = 0; $i < @deriv_mkrs; $i++)
	{
		my $exif = ImageInfo($deriv_mkrs[$i]);
		if ($$exif{Error})
		{
			$log->logdie("Problem with $deriv_mkrs[$i]: $$exif{Error}");
		}
		push(@exif_data, $exif);
		$stat->add_data($$exif{XResolution});
	}

	my $resolution;
	if ($stat->count() == 1) {
		($resolution) = $stat->get_data();
	} elsif (!defined($stat->mode())) {
		$resolution = $stat->min();
	} else {
		$resolution = $stat->mode();
	}
	$log->info("Setting resolution to $resolution.");

	for (my $i = 0; $i < @deriv_mkrs; $i++)
	{
		my $basename = basename($deriv_mkrs[$i]);
		$basename =~ s/d\.tif$//;

		my $tif_file   = "$aux_dir/${basename}d.tif";
		my $jp2_file   = "$aux_dir/${basename}d.jp2";
		my $jpg_file   = "$aux_dir/${basename}s.jpg";
		my $hires_file = "$aux_dir/${basename}hires.tif";
		my $lores_file = "$aux_dir/${basename}lores.tif";

# 		sys("exiftool $deriv_mkrs[$i]");
		delete $exif_data[$i]->{PhotoshopThumbnail};
		$log->debug(Dumper($exif_data[$i]));

		my ($orig_depth) = split(/\s+/, ${$exif_data[$i]}{BitsPerSample});
		$log->debug("Original color depth: $orig_depth bit");

		my $new_depth;
		$new_depth = 8 if $orig_depth > 8;

		# kdu_compress doesn't seem to hangle CIELab so we
		# need to convert colorspace into sRGB.
		my $colorspace;
		$colorspace = "sRGB"
		  if $exif_data[$i]->{PhotometricInterpretation} eq 'CIELab';

		my $params = {
			resolution => $resolution,
			depth      => $new_depth,
			colorspace => $colorspace,
		};

		convert($deriv_mkrs[$i], $tif_file, $params);

		for my $img_file ($jp2_file, $jpg_file, $hires_file, $lores_file)
		{
			convert($tif_file, $img_file);
		}
	}
}


sub convert
{
	my ($input_file, $output_file, $params) = @_;
	if (!$opt_f && -f $output_file) {
		$log->warn("file $output_file already exists.");
		return;
	}
	my $convert = "";
	my $tmp_file = "$tmpdir/" . basename($output_file);
	if ($output_file =~ /\.jp2$/) {
# 		$convert = "./compress.sh -i $input_file -o";
		$convert = "$kdu_compress -s $kdurc_file -i $input_file -o";
	} else {
		$convert = "convert $input_file\[0]";
		if ($output_file =~ /d\.tif$/) {
			$convert .= " -strip -density $params->{resolution} ";
			$convert .= " -alpha off";
			$convert .= " -colorspace $params->{colorspace}"
			  if $params->{colorspace};
			$convert .= " -depth $params->{depth}" if $params->{depth};
		} elsif ($output_file =~ /\.jpg$/) {
			$convert .= " -resize 960x720\\> -quality 75";
		} elsif ($output_file =~ /hires\.tif$/) {
			$convert .= " -resample 200";
		} else {
			$convert .= " -resample 96";
		}
	}
	$convert .= " $tmp_file";
	sys($convert);
	$log->info("Moving $host:$tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}

