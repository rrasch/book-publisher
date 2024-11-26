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
use lib "/content/prod/rstar/etc/content-publishing/book";
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

my $host = hostname();

# find directory where this script resides
my $app_home = dirname(abs_path($0));

my $kdurc_file = "$app_home/conf/kdurc";

our $opt_f;  # force removal of output files
our $opt_q;  # quiet mode
our $opt_s;  # use sip directory
our $opt_x;  # use xip directory
our $opt_n;  # does nothing; option compatible with create-pdf.pl
our $opt_o;  # does nothing; option compatible with create-pdf.pl
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my @args = @ARGV;
my $success = getopts('fqsxnor:t:');
if (!$success)
{
	$log->logdie("Problem parsing command line args '@args'.");
}

# quiet mode
if ($opt_q)
{
	MyLogger->get_logger('Util')->level($WARN);
	$log->level($WARN)
}

my $tmpdir_base = $opt_t || config('tmpdir') || "/tmp";
my $tmpdir = tempdir(DIR => $tmpdir_base, CLEANUP => 1);
$log->debug("Temp directory: $tmpdir");
$ENV{TMPDIR} = $tmpdir;

my $subdir;
if ($opt_s) {
	$subdir = "sip";
} elsif ($opt_x) {
	$subdir = "xip";
} else {
	$subdir = "wip";
}

my $wip_dir =
  ($opt_r || $ENV{RSTAR_DIR} || config('rstar_dir')) . "/$subdir/se";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

# chdir($bin_dir) or $log->logdie("Can't chdir $bin_dir: $!");

for my $id (@ids)
{
	$log->info("Processing $id");
	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $resolution;

# 	my @deriv_mkrs = sort(glob("$data_dir/$id*d.tif"));
	my @deriv_mkrs = sort(glob("$data_dir/*d.tif"));

	if (!@deriv_mkrs)
	{
		$log->debug("No TIFF images, looking for JPEG 2000 files.");
		@deriv_mkrs = grep(!/_2up_/, sort(glob("$data_dir/*o.jp2")));
		$resolution = 400;
	}

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

	if (!$resolution)
	{
		if ($stat->count() == 1) {
			($resolution) = $stat->get_data();
		} elsif (!defined($stat->mode())) {
			$resolution = $stat->min();
		} else {
			$resolution = $stat->mode();
		}
	}

	$log->info("Setting resolution to $resolution.");

	for (my $i = 0; $i < @deriv_mkrs; $i++)
	{
		my $basename = basename($deriv_mkrs[$i]);
		$basename =~ s/(d\.tif|o\.jp2)$//;

		my $tif_file   = "$aux_dir/${basename}d.tif";
		my $jp2_file   = "$aux_dir/${basename}d.jp2";
		my $jpg_file   = "$aux_dir/${basename}s.jpg";
		my $hires_file = "$aux_dir/${basename}hires.tif";
		my $lores_file = "$aux_dir/${basename}lores.tif";

# 		sys("exiftool $deriv_mkrs[$i]");
		delete $exif_data[$i]->{PhotoshopThumbnail};
		$log->debug(Dumper($exif_data[$i]));

		my $orig_depth = ${$exif_data[$i]}{BitsPerSample}
		  || ${$exif_data[$i]}{BitsPerComponent};
		($orig_depth) = split(/\s+/, $orig_depth);
		$log->debug("Original color depth: $orig_depth bit");

		my $new_depth;
		$new_depth = 8 if $orig_depth > 8;

		my $params = {
			resolution => $resolution,
			depth      => $new_depth,
		};

		convert($deriv_mkrs[$i], $tif_file, $params);

		for my $img_file ($jp2_file, $jpg_file, $hires_file, $lores_file)
		{
			convert($tif_file, $img_file, $params);
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
			$convert .= " -strip";
			$convert .= " -auto-orient";
			$convert .= " -density $params->{resolution}";
			$convert .= " -units PixelsPerInch";
			$convert .= " -alpha off";
			$convert .= " -colorspace sRGB -type TrueColor";
			$convert .= " -depth $params->{depth}" if $params->{depth};
		} elsif ($output_file =~ /\.jpg$/) {
			$convert .= " -resize 960x720\\> -quality 75";
		} elsif ($output_file =~ /hires\.tif$/
				&& $params->{resolution} > 200) {
			$convert .= " -resample 200";
		} elsif ($output_file =~ /lores\.tif$/
				&& $params->{resolution} > 96) {
			$convert .= " -resample 96";
		} else {
			$convert = "ln -s $input_file";
		}
	}
	$convert .= " $tmp_file";
	sys($convert);
	$log->info("Moving $host:$tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}

