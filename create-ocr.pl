#!/usr/bin/env perl
#
# Use Tesseract to generate OCR from book pages.
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Temp;
use Getopt::Std;
use Log::Log4perl::Level;
use MODS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Sys::Hostname;
use Util;

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

my $tmpdir = File::Temp::tempdir(
	CLEANUP => 1,
	DIR     => "/tmp",
);

our $opt_f;  # force removal of output files
our $opt_q;  # quiet logging
our $opt_r;  # rstar directory
getopts('fqr:');

# quiet mode
if ($opt_q)
{
	MyLogger->get_logger('Util')->level($WARN);
	$log->level($WARN)
}

my $host = hostname();

my $wip_dir = ($opt_r || $ENV{RSTAR_DIR} || config('rstar_dir')) . "/wip/se";

$log->debug("wip dir: $wip_dir");

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

my ($version) = sys("tesseract -v") =~ /^tesseract (\d+\.\d+)/;
$log->debug("Tesseract version: $version");

my @output_ext = "txt";
push(@output_ext, $version >= 3.03 ? "hocr" : "html");

for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";
	$log->debug("Source entity METS file: $mets_file");
	if (!-f $mets_file)
	{
		$log->warn("Source entity METS file $mets_file doesn't exist.");
		next;
	}
	my $mets = SourceEntityMETS->new($mets_file);

	my $mods_file = $mets->get_mods_file;
	$log->debug("MODS file: $mets_file");
	my $mods = MODS->new($mods_file);

	my $lang = $mods->lang_code();
	$log->debug("Language = $lang");

	my @tifs = sort(glob("$data_dir/$id*d.tif"));

	for my $tif_file (@tifs)
	{
		my $basename = basename($tif_file);
		$basename =~ s/_?d\.tif$//;
		my $output_base = "$tmpdir/${basename}_ocr";

		for my $ext (@output_ext)
		{
			my $tmp_file    = "$output_base.$ext";
			my $output_file = "$aux_dir/${basename}_ocr.$ext";

			if (!$opt_f && -f $output_file)
			{
				$log->warn("ocr file $output_file already exists.");
				next;
			}

			my $cmd = "tesseract $tif_file $output_base -l $lang";
			$cmd .= " hocr" if $ext =~ /^(html|hocr)$/;
			my $output = sys($cmd);
			$log->info("Moving $tmp_file to $host:$output_file");
			move($tmp_file, $output_file)
			  or $log->logdie("can't move $tmp_file to $output_file: $!");
		}
	}
}

