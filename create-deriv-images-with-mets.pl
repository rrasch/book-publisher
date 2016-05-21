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
use File::Temp qw(tempdir);
use Sys::Hostname;
use MyConfig;
use MyLogger;
use Util qw(getval sys);


my $bin_dir = "/usr/local/adore-djatoka-1.1/bin";

my $log = MyLogger->get_logger();

my $tmpdir = tempdir(CLEANUP => 1);

my $host = hostname();

my $wip_dir = config('rstar_dir') . "/wip";

my @ids = Util::get_dir_contents($wip_dir);

chdir($bin_dir) or $log->logdie("Can't chdir $bin_dir: $!");

my $xpc = XML::LibXML::XPathContext->new();

$xpc->registerNs("b", "http://dlib.nyu.edu/rstar");


for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $struct_file = "$wip_dir/$id/$id-struct.xml";
	$log->debug("Struct map file: $struct_file");

	my $struct = XML::LibXML->load_xml(location => $struct_file);

	my $slot_path =
	  "/b:book-srcs/b:book-src[\@label='$id']/b:book-slots/b:book-slot";

	for my $slot ($xpc->findnodes($slot_path, $struct))
	{
		my $tif_file =
		  getval("./b:files/b:file[\@derivative_src='true']", $slot);
		$log->debug("dmaker = $tif_file");

		my $basename = basename($tif_file);
		$basename =~ s/de?\.tif$//;

		my $jp2_file   = "$aux_dir/${basename}d.jp2";
		my $jpg_file   = "$aux_dir/${basename}s.jpg";
		my $hires_file = "$aux_dir/${basename}_hires.tif";
		my $lores_file = "$aux_dir/${basename}_lores.tif";

		sys("exiftool $tif_file");

		for my $img_file ($jp2_file, $jpg_file, $hires_file, $lores_file)
		{
			if (-f $img_file)
			{
				$log->warn("file $img_file already exists.");
				next;
			}
			convert($tif_file, $img_file);
		}
	}
}


sub convert
{
	my ($input_file, $output_file) = @_;
	my $tmp_file = "$tmpdir/" . basename($output_file);
	if ($output_file =~ /\.jp2$/) {
		sys("./compress.sh -i $input_file -o $tmp_file");
	} elsif ($output_file =~ /\.jpg$/) {
		sys("convert $input_file\[0] -resize 960x720 -quality 75 $tmp_file");
	} elsif ($output_file =~ /hires\.tif$/) {
		sys("convert $input_file\[0] -resample 200 $tmp_file");
	} else {
		sys("convert $input_file\[0] -resample 96 $tmp_file");
	}
	$log->info("Moving $host:$tmp_file to $host:$output_file");
	move($tmp_file, $output_file)
	  or $log->logdie("can't move $tmp_file to $output_file: $!");
}


