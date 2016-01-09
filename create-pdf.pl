#!/usr/bin/env perl
#
# Create pdf from book images.
#
# Author: Rasan Rasch <rasan@nyu.edu>


use FindBin;
use lib "$FindBin::Bin/lib";
use lib "/etc/content-publishing/book";
use strict;
use warnings;
use File::Basename;
use File::Copy;
use File::Temp qw(tempdir);
use File::Which;
use Getopt::Std;
use Log::Log4perl::Level;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Sys::Hostname;
use Util;

$SIG{HUP} = 'IGNORE';

my $log = MyLogger->get_logger();

my $tmpdir = tempdir(
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

my @ids = @ARGV ? @ARGV : Util::get_dir_contents($wip_dir);

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

my @comp_profiles = sort keys %$comp_cfg;

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

	my $files;
	for my $profile (@comp_profiles)
	{
		$files->{$profile}{input} = [];
		$files->{$profile}{output} = "$aux_dir/${id}_$profile.pdf";
		
		if (!$opt_f && -f $files->{$profile}{output})
		{
			$log->warn("pdf $files->{$profile}{output} already exists.");
			next;
		}

		for my $file_id ($mets->get_file_ids())
		{
			my $input_file = "$aux_dir/${file_id}_${profile}res.tif";
			my $output_file = "$aux_dir/${file_id}_${profile}.pdf";
			if ($opt_f || ! -f $output_file) {
				tiff2pdf($input_file, $output_file, $profile);
			} else {
				$log->warn("pdf $output_file already exists.");
			}
			push(@{$files->{$profile}{input}}, $output_file);
		}

		$log->debug("Merging $profile pdfs");
		merge_pdfs($files->{$profile}{input}, $files->{$profile}{output});
	}
}


sub merge_pdfs
{
	my ($input_files, $output_file) = @_;
	my $tmp_file = "$tmpdir/" . basename($output_file);
	if (which("pdftk")) {
		sys("pdftk "
			. join(" ", @{$input_files})
			. " cat output $tmp_file");
	} else {
		my @libs = qw(pdfbox commons-logging);
		sys("java -Xms512m -Xmx512m -cp "
			. join(':', map("/usr/share/java/${_}.jar", @libs))
			. " org.apache.pdfbox.PDFMerger "
			. join(" ", @{$input_files}, $tmp_file));
	}
	$log->info("Moving $tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
	# Delete intermediate pdf files
	for my $file (@{$input_files})
	{
		unlink($file) or $log->logdie("Can't unlink $file: $!");
	}
}


sub tiff2pdf
{
	my ($input_file, $output_file, $profile) = @_;

	my $tmp_tif_file = "$tmpdir/" . basename($input_file);
	my $tmp_pdf_file = "$tmpdir/" . basename($output_file);

	# Now convert downsampled to pdf
# 	sys("convert $tmp_tif_file -compress JPEG -quality $comp_cfg->{$profile}{jpeg_quality} $tmp_pdf_file");
	sys("tiff2pdf -o $tmp_pdf_file -j -q $comp_cfg->{$profile}{jpeg_quality} $input_file");
	sys("sed -i 's/ColorTransform 0/ColorTransform 1/' $tmp_pdf_file");
	sys("pdfinfo $tmp_pdf_file");

	$log->info("Moving $tmp_pdf_file to $host:$output_file");
	move($tmp_pdf_file, $output_file)
	  or $log->logdie("can't move $tmp_pdf_file to $output_file: $!");
}

