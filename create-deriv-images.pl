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
use Data::Dump qw(dump);
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);
use File::Which;
use Getopt::Long;
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

my $convert_bin = which("magick") || "/usr/bin/convert";

my $log = MyLogger->get_logger();

my $host = hostname();

# find directory where this script resides
my $app_home = dirname(abs_path($0));

my $kdurc_file = "$app_home/conf/kdurc";

our $opt_f;  # force removal of output files
our $opt_q;  # quiet mode
our $opt_s;  # use sip directory
our $opt_x;  # use xip directory
our $opt_m;  # flag to only create new sanitized dmakers
our $opt_n;  # does nothing; option compatible with create-pdf.pl
our $opt_o;  # does nothing; option compatible with create-pdf.pl
our $opt_p;  # only generate tifs files used make pdfs
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory

my @args = @ARGV;

Getopt::Long::Configure(
	"bundling",          # allow short-option bundling like -qi
	"no_auto_abbrev",    # require full long option names
	"no_ignore_case",    # make option names case-sensitive
);

GetOptions(
	'f|force'    => \$opt_f,
	'q|quiet'    => \$opt_q,
	's|sip'      => \$opt_s,
	'x|xip'      => \$opt_x,
	'm|dmakers'  => \$opt_m,
	'p|pdf-tifs' => \$opt_p,
	'n|no-mets'  => \$opt_n,
	'o|ocr'      => \$opt_o,
	'r|rstar=s'  => \$opt_r,
	't|tmp=s'    => \$opt_t,
	'h|help'     => sub { print_usage(); exit(0); },
  )
  or do { print_usage(); exit(1); };

# Die on warnings
$SIG{__WARN__} = sub {
	local $Log::Log4perl::caller_depth = $Log::Log4perl::caller_depth + 1;
	$log->logdie(@_);
};

if ($opt_m && $opt_p)
{
	$log->logdie("Can't set both -m/--dmakers and --p/--pdf-tifs");
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

for my $id (@ids)
{
	$log->info("Processing $id");
	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

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
		$basename =~ s/(d\.tif|o\.jp2)$//;

		my $tif_file   = "$aux_dir/${basename}d.tif";
		my $jp2_file   = "$aux_dir/${basename}d.jp2";
		my $jpg_file   = "$aux_dir/${basename}s.jpg";
		my $hires_file = "$aux_dir/${basename}hires.tif";
		my $lores_file = "$aux_dir/${basename}lores.tif";

		$log->debug(dump($exif_data[$i]));

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

		# create new dmaker
		convert($deriv_mkrs[$i], $tif_file, $params);

		# skip if we are only creating new dmakers
		next if $opt_m;

		my @derivs = ($hires_file, $lores_file);
		unless ($opt_p)
		{
			unshift(@derivs, $jp2_file, $jpg_file);
		}

		for my $img_file (@derivs)
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
		$convert = "$kdu_compress -s $kdurc_file -i $input_file -o";
	} else {
		$convert = "$convert_bin $input_file\[0]";
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


sub print_usage
{
	print STDERR <<"END_USAGE";
Usage: $0 [options]

Options:
  -f, --force          Force removal of output files
  -q, --quiet          Quiet mode
  -s, --sip            Use sip directory
  -x, --xip            Use xip directory
  -m, --dmakers        Only create new sanitized dmakers
  -p  --pdf-tifs       Only generate tifs files used make pdfs
  -n, --no-mets        Does nothing; option compatible with create-pdf.pl
  -o, --ocr            Does nothing; option compatible with create-pdf.pl
  -r, --rstar <dir>    Rstar directory
  -t, --tmp <dir>      Temporary directory
  -h, --help           Show this help message and exit
END_USAGE
}
