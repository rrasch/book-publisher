#!/usr/bin/env perl
#
# Author: Rasan Rasch <rasan@nyu.edu>

use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/content/prod/rstar/etc/content-publishing/book";
use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path qw(remove_tree);
use File::Temp;
use Getopt::Std;
use Log::Log4perl::Level;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Sys::Hostname;
use Util;

my $ocular_home = "/usr/local/ocular-0.1";

my $ocular_conf = "base.conf";

my $ocular_cmd = "java -mx7g -jar ocular.jar ++conf/$ocular_conf";

my $convert_args = "-resize 75%";

# if ($^O =~ /darwin/i)
# {
# 	$ocular_cmd .= " -emissionEngine OPENCL";
# }

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

my $tmpdir = File::Temp::tempdir(
	"ocular.XXXXXXXXXX",
	CLEANUP => 1,
	DIR     => "/tmp",
);

my $img_dir  = "$tmpdir/imgs";
my $ocr_dir   = "$tmpdir/ocr";
my $font_file = "$tmpdir/learned.fontser";

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

chdir($ocular_home) or $log->logdie("can't chdir $ocular_home: $!");

my $pid = `pgrep Xvfb`;
chomp($pid);
if ($pid) {
	$log->debug("Xvfb already running with pid $pid.");
} else {
	sys("Xvfb :99 -screen 0 1024x768x24 +extension RANDR &");
}
$ENV{DISPLAY} = ":99";

my $memory = get_memory();
$log->debug("System memory: ${memory}GB");
my $is_enough_memory = $memory >= 8;

for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $mets_file = "$data_dir/${id}_mets.xml";
	$log->debug("Source entity METS file: $mets_file");
	my $mets = SourceEntityMETS->new($mets_file);

	for my $dir ($img_dir, $ocr_dir)
	{
		mkdir($dir) or $log->logdie("Can't mkdir $dir: $!");
	}
	
	my @fileids = grep(/_n\d{6}$/, $mets->get_file_ids);
	@fileids = @fileids[0..9];
	for my $fileid (@fileids)
	{
		if ($is_enough_memory)
		{
			my $tif = "$aux_dir/${fileid}_d.tif";
			my $jpg = "$img_dir/${fileid}.jpg";
			sys("convert $tif $convert_args $jpg");
		}
		else
		{
			my $src = "$aux_dir/${fileid}_s.jpg";
			my $dst = "$img_dir/${fileid}.jpg";
			$log->debug("Symlinking $src to $dst");
			symlink($src, $dst)
			  or $log->logdie("can't symlink $src to $dst: $!");
		}
	}

	my $cmd = "$ocular_cmd -learnFont true -inputPath $img_dir ";
	$cmd .= "-outputPath $ocr_dir -outputFont $font_file";
	sys($cmd);
	$log->debug("Finished training $id.");

	remove_tree($ocr_dir);
	mkdir($ocr_dir) or $log->logdie("Can't mkdir $ocr_dir: $!");

	for my $fileid ($mets->get_file_ids)
	{
		if ($is_enough_memory)
		{
			my $tif = "$aux_dir/${fileid}_d.tif";
			my $jpg = "$img_dir/${fileid}.jpg";
			sys("convert $tif $convert_args $jpg") unless -f $jpg;
		}
		else
		{
			my $src = "$aux_dir/${fileid}_s.jpg";
			my $dst = "$img_dir/${fileid}.jpg";
			unless (-l $dst && readlink($dst) eq $src)
			{
				$log->debug("Symlinking $src to $dst");
				symlink($src, $dst)
				  or $log->logdie("can't symlink $src to $dst: $!");
			}
		}
	}

	$cmd = "$ocular_cmd -learnFont false -initFontPath $font_file ";
	$cmd .= "-inputPath $img_dir -outputPath $ocr_dir";
	sys($cmd);

	for my $fileid ($mets->get_file_ids)
	{
		my $src = "$ocr_dir/${fileid}.jpg.iter-0.txt";
		my $dst = "$aux_dir/${fileid}_ocular.txt";
		$log->debug("Moving $src to $dst");
		move($src, $dst) or $log->logdie("can't move $src to $dst: $!");
	}

	remove_tree($img_dir, $ocr_dir);

}


sub get_memory
{
	my $memory;
	if ($^O =~ /darwin/i)
	{
		($memory) = sys("sysctl hw.memsize") =~ /hw.memsize:\s+(\d+)/;
	} else {
		($memory) = sys("free -b") =~ /Mem:\s+(\d+)/;
	}
	return sprintf("%.0f", $memory / (1024 ** 3));
}

