#!/usr/bin/env perl
#
# $Id: stitch-pages.pl 14613 2015-02-08 14:38:37Z rr102 $
#
# Concatenate book pages horizontally.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use Cwd qw(abs_path getcwd);
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);
use Getopt::Std;
use Log::Log4perl::Level;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Sys::Hostname;
use Util qw(getval sys);

$SIG{HUP} = 'IGNORE';

my $djatoka_dir = "/usr/local/adore-djatoka-1.1/bin";

# Compression ratio for JPEG2000 files
my $jp2_compression_ratio = 1 / 100;

my $convert_args = "-colorspace sRGB -type TrueColor";

my $log = MyLogger->get_logger();

our $opt_f;  # force removal of output files
our $opt_q;  # quiet logging
our $opt_s;  # use sip directory
our $opt_x;  # use xip directory
our $opt_o;  # does nothing; option compatible with create-pdf.pl
our $opt_b;  # border width in pixels
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory base

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my @args = @ARGV;
my $success = getopts('fqsxob:r:t:');
if (!$success)
{
	$log->logdie("Problem parsing command line args '@args'.");
}

$opt_b ||= '0';

if ($opt_b && $opt_b !~ /^\d+$/)
{
	print STDERR "\nUsage: $0 [-f] [ -b border_width ] ";
	print STDERR "[ -r rstar_dir ] [ book_id ]...\n\n";
	print STDERR "\tborder_width must be a number.\n\n";
	exit 1;
}

$convert_args .= " -background black";
$convert_args .= " -splice ${opt_b}x0" if $opt_b;
$convert_args .= " +append";
$convert_args .= " -chop ${opt_b}x0" if $opt_b;

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

my $host = hostname();

# find directory where this script resides
my $app_home = dirname(abs_path($0));

my $kdurc_file = "$app_home/conf/kdurc";

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

	my $mets_file = "$data_dir/${id}_mets.xml";

	if (!-f $mets_file)
	{
		$log->warn("Source entity mets file $mets_file doesn't exist.");
		next;
	}

	my $mets = SourceEntityMETS->new($mets_file, $log);

	# find source SE id
	my $id = $mets->get_id();
	$log->debug("Source Entity ID = $id");

	my $aux_dir = "$wip_dir/$id/aux";

	# get binding orientation, scan order, read order info
	my %scan_data = $mets->scan_data();
	for my $k (keys %scan_data)
	{
		$log->debug("$k: $scan_data{$k}");
	}

	my $is_right2left = $scan_data{read_order} =~ /right(_to_|2)left/i;
	$log->debug("Is right to left?: ", $is_right2left ? "true" : "false");

	# get list of file ids in book
	my @file_ids = $mets->get_file_ids();

	# Simply copy cover and back of book
	for my $i (0, $#file_ids)
	{
		my $page_num = $i + 1;

		my $jp2_file = "$aux_dir/${file_ids[$i]}_d.jp2";

		my $out_file =
		  "$aux_dir/" . stitch_basename($id, $page_num, $page_num) . ".jp2";

		if (!$opt_f && -f $out_file)
		{
			$log->warn("file $out_file already exists.");
			next;
		}

		$log->debug("Copying $host:$jp2_file to $host:$out_file");
		copy($jp2_file, $out_file)
		  or $log->logdie("Can't copy $jp2_file to $out_file: $!");
	}

	for (my $i = 1 ; $i < $#file_ids ; $i += 2)
	{
		my $page_num = $i + 1;

		my @input_tifs =
		  map { "$aux_dir/${_}_d.tif" } @file_ids[$i, $i + 1];

		if ($is_right2left)
		{
			@input_tifs = reverse(@input_tifs);
		}

		my $basename     = stitch_basename($id, $page_num, $page_num + 1);
		my $tmp_tif_file = "$tmpdir/$basename.tif";
		my $tmp_jp2_file = "$tmpdir/$basename.jp2";
		my $out_file     = "$aux_dir/$basename.jp2";

		if (!$opt_f && -f $out_file)
		{
			$log->warn("file $out_file already exists.");
			next;
		}

		# tile left and right page images horizontally
		sys("convert $input_tifs[0]\[0] $input_tifs[1]\[0] "
			. "$convert_args $tmp_tif_file");

		# compress the uncompressed tiled tif to jp2
# 		sys("convert $tmp_tif_file -define jp2:rate="
# 			. "$jp2_compression_ratio $tmp_jp2_file");
# 		my $cwd = getcwd;
# 		chdir($djatoka_dir)
# 		  or $log->logdie("Can't chdir $djatoka_dir: $!");
# 		sys("./compress.sh -i $tmp_tif_file -o $tmp_jp2_file");
# 		chdir($cwd) or $log->logdie("Can't chdir $cwd: $!");
		sys("kdu_compress -s $kdurc_file "
			. "-i $tmp_tif_file -o $tmp_jp2_file");

		# move jp2 file to destination directory
		$log->debug("Moving $host:$tmp_jp2_file to $host:$out_file");
		move($tmp_jp2_file, $out_file)
		  or $log->logdie("can't move $tmp_jp2_file to $out_file: $!");

		sys("exiftool $out_file");

		unlink($tmp_tif_file)
		  or $log->warn("Can't unlink $tmp_tif_file: $!");
	}
}


sub stitch_basename
{
	my ($book_id, $page_num_1, $page_num_2) = @_;
	return "${book_id}_2up_"
	  . join("_", map(Util::zeropad($_), $page_num_1, $page_num_2));
}

