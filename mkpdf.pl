#!/usr/bin/env perl
#
# Create pdf out of set of images in alphabetical order.
#
# Author: Rasan Rasch <rasan@nyu.edu>


use FindBin;
use lib "$FindBin::Bin/lib";
use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Path;
use File::Temp qw(tempdir);
use Sys::Hostname;
use MyConfig;
use MyLogger;
use Util;

my $comp_cfg = {
	hi => {
		resolution   => 200,
		jpeg_quality => 85,
	},
	lo => {
		resolution   => 96,
		jpeg_quality => 70,
	},
};

################################################

my @comp_profiles = sort keys %$comp_cfg;

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

my $tmpdir = tempdir(CLEANUP => 1);

my $host = hostname();

my $wip_dir = config('rstar_dir') . "/wip";

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

for my $id (@ids)
{
	$log->info("Processing $id");

	my $aux_dir = "$wip_dir/$id/aux";
	$log->info("Aux dir: $aux_dir");

	my @imgs = Util::get_dir_contents($aux_dir);

	my $files;

	for my $profile (@comp_profiles)
	{
		$files->{$profile}{input} = [];
		$files->{$profile}{output} = "$aux_dir/${id}_$profile.pdf";
	}

	for my $img (@imgs)
	{
		next unless $img =~ /d.tif$/;

		my $basename = $img;
		$basename =~ s/_?d\.tif$//;

		for my $profile (@comp_profiles)
		{
			my $tif_file = "$aux_dir/${basename}_${profile}res.tif";
			my $pdf_file = "$aux_dir/${basename}_${profile}res.pdf";

			if (! -f $tif_file) {
				$log->logdie("$tif_file doesn't exists.");
			}

			if (! -f $pdf_file) {
				tiff2pdf($tif_file, $pdf_file, $profile);
			} else {
				$log->warn("pdf $pdf_file already exists.");
			}

			push(@{$files->{$profile}{input}}, $pdf_file);
		}
	}

	for my $profile (@comp_profiles)
	{
		$log->debug("Merging $profile pdfs");
		merge_pdfs($files->{$profile}{input}, $files->{$profile}{output});
	}

}


sub merge_pdfs
{
	my ($input_files, $output_file) = @_;
	my $tmp_file = "$tmpdir/" . basename($output_file);
	sys("pdftk " . join(" ", @{$input_files}) . " cat output $tmp_file");
	$log->info("Moving $tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}


sub tiff2pdf
{
	my ($input_file, $output_file, $profile) = @_;

	my $tmp_file = "$tmpdir/" . basename($output_file);

	# Now convert downsampled to pdf
# 	sys("convert $input_file -compress JPEG -quality $comp_cfg->{$profile}{jpeg_quality} $tmp_file");
	sys("tiff2pdf4 -o $tmp_file -j -q $comp_cfg->{$profile}{jpeg_quality} $input_file");
# 	sys("sed -i 's/ColorTransform 0/ColorTransform 1/' $tmp_pdf_file");

	$log->info("Moving $tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}


