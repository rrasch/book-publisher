#!/usr/bin/env perl
#
# Create pdf from book images.
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
use File::Which;
use Getopt::Std;
use LangCode;
use Log::Log4perl::Level;
use MODS;
use MyConfig;
use MyLogger;
use SourceEntityMETS;
use Sys::Hostname;
use Util;
use version;

$SIG{HUP} = 'IGNORE';

my $convert_bin = which("magick") || "/usr/bin/convert";

my $log = MyLogger->get_logger();

our $opt_f;  # force removal of output files
our $opt_q;  # quiet logging
our $opt_i;  # generate pdf using ImageMagick
our $opt_o;  # generate pdf with ocr
our $opt_e;  # generate pdf with ExactImage adding previously created hocr
our $opt_s;  # use sip directory
our $opt_x;  # use xip directory
our $opt_n;  # don't use METS to get file structure; use filenames instead
our $opt_r;  # rstar directory
our $opt_t;  # tmp directory base
our $opt_c;  # compression levels
our $opt_b;  # background color to fill pdf pages
our $opt_m;  # tesseract ocr engine mode
our $opt_l;  # tesseract language

$Getopt::Std::STANDARD_HELP_VERSION = 1;
my @args = @ARGV;
my $success = getopts('fqioesxnr:t:c:b:m:l:');
if (!$success)
{
	$log->logdie("Problem parsing command line args '@args'.");
}


my $num_pdf_opts = 0;
for my $opt ($opt_i, $opt_o, $opt_e)
{
	$num_pdf_opts++ if $opt;
}

if ($num_pdf_opts > 1)
{
	$log->logdie("You can only specifiy one of -i, -o, or -e.");
}

if ($opt_m && !$opt_o)
{
	$log->logdie("You specified Tesseract OCR Engine (OEM) but "
		  . "aren't using Tesseract.");
}

if (defined($opt_m) && $opt_m !~ /^[0-3]$/)
{
	$log->logdie("Invalid Tesseract OCR Engine (OEM) value, "
		  . "please enter a number between 0-3.");
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

mk_lept_tmpdir();

my $host = hostname();

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

if ($ENV{TQ_SERVER_PID})
{
	$ENV{MAGICK_THREAD_LIMIT} = 1;
	$ENV{OMP_THREAD_LIMIT} = 1;
}

my $tess_vers;
my $tess_args = "";
if ($opt_o)
{
	my ($tess_vers) =
	  sys("tesseract -v") =~ /^tesseract (\d+\.\d+.\d+)/;
	$log->debug("Tesseract version: $tess_vers");
	$tess_args .= " -c tessedit_do_invert=0"
	  if version->parse($tess_vers) >= version->parse("4.1.1");
	$tess_args .= " --oem $opt_m" if $opt_m;
	$tess_args .= " quiet" if $opt_q;
	$tess_args =~ s/^\s+//;
}

# get jpeg compression values
my ($lo_level, $hi_level);
if (defined $opt_c) {
	($lo_level, $hi_level) = sort {$a <=> $b} split(/:/, $opt_c);
}

# Set default vals for compression. Quality is on higher side
# since these are book pages.  For normal images we could use
# values of 70 or below.
$lo_level ||= 85;
$hi_level ||= 85;
$log->debug("Compression levels for pdfs are $lo_level and $hi_level.");

my $max_page_check = 20;

my $paper_width_inches = 8.5;
my $paper_height_inches = 11;

my $img_cfg = {
	hi => {
		resolution   => 200,
		jpeg_quality => $hi_level,
	},
	lo => {
		resolution   => 72,
		jpeg_quality => $lo_level,
	},
};

my @img_profiles = sort keys %$img_cfg;

for my $prof (@img_profiles)
{
	$img_cfg->{$prof}{width} =
	  int($paper_width_inches * $img_cfg->{$prof}{resolution});
	$img_cfg->{$prof}{height} =
	  int($paper_height_inches * $img_cfg->{$prof}{resolution});
}

for my $id (@ids)
{
	$log->info("Processing $id");

	my $data_dir = "$wip_dir/$id/data";
	my $aux_dir  = "$wip_dir/$id/aux";

	my $mets;
	my @file_ids = ();
	if ($opt_n)
	{
		my @deriv_mkrs = sort(glob("$aux_dir/*d.tif"));
		for my $deriv_mkr (@deriv_mkrs)
		{
			my $file_id = basename($deriv_mkr);
			$file_id =~ s/_d\.tif$//;
			push(@file_ids, $file_id);
		}
	}
	else
	{
		my $mets_file = "$data_dir/${id}_mets.xml";
		$log->debug("Source entity METS file: $mets_file");
		if (!-f $mets_file)
		{
			$log->warn("Source entity METS file $mets_file doesn't exist.");
			next;
		}
		$mets = SourceEntityMETS->new($mets_file);
		@file_ids = $mets->get_file_ids();
	}

	my $tess_lang;
	if ($opt_o)
	{
		if ($opt_l)
		{
			$tess_lang = $opt_l;
		}
		else
		{
			my $mods_file;
			if ($opt_n) {
				$mods_file = (glob("$data_dir/*_mods.xml"))[0];
			} else {
				$mods_file = $mets->get_mods_file;
			}
			$log->debug("MODS file: $mods_file");
			my $mods = MODS->new($mods_file);
			my $lang = $mods->lang_code();
			$log->debug("Language = $lang");
			if (!$lang)
			{
				$log->logdie("Can't find language in MODS file.");
			}
			$tess_lang = LangCode::term_code($lang) || $lang;
		}
	}

	if ($opt_e)
	{
		my @files = ();
		for my $file_id (@file_ids)
		{
			my $input_file  = "$aux_dir/${file_id}_d.tif";
			my $output_file = "$aux_dir/${file_id}_hocr.pdf";
			my $hocr_file   = "$data_dir/${file_id}_hocr.html";
			img2pdf($input_file, $output_file, {hocr_file => $hocr_file});
			push(@files, $output_file);
		}
		$log->debug("Merging pdfs");
		merge_pdfs(\@files, "$aux_dir/${id}_hocr.pdf");
		next;
	}

	my $bg_color = $opt_b;

	my $files;
	for my $profile (@img_profiles)
	{
		$files->{$profile}{input} = [];
		$files->{$profile}{output} = "$aux_dir/${id}_$profile.pdf";
		
		if (!$opt_f && -f $files->{$profile}{output})
		{
			$log->warn("pdf $files->{$profile}{output} already exists.");
			next;
		}

		if ($opt_i && !$bg_color)
		{
			my $limit =
			  @file_ids < $max_page_check ? @file_ids : $max_page_check;
			my $num_white = 0;
			for (my $i = 0 ; $i < $limit ; $i++)
			{
				my $input_file = "$aux_dir/$file_ids[$i]_s.jpg";
				$num_white++ if is_page_white($input_file);
			}
			$log->debug("Found $num_white out of $limit white pages.");
			$bg_color = $num_white > $limit / 2 ? 'white' : 'black';
			$log->debug("Setting background color to $bg_color.");
		}

		for my $file_id (@file_ids)
		{
			my $input_file = "$aux_dir/${file_id}_${profile}res.tif";
			my $output_file = "$aux_dir/${file_id}_${profile}.pdf";
			if (-f $output_file)
			{
				$log->warn("pdf $output_file already exists.");
			}
			my $img2pdf_cfg = { lang => $tess_lang };
			$img2pdf_cfg->{image} = $img_cfg->{$profile};
			$img2pdf_cfg->{image}{bg_color} = $bg_color;
			img2pdf($input_file, $output_file, $img2pdf_cfg);
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
		my @libs = qw(pdfbox pdfbox-tools commons-logging);
		sys("java -Xms512m -Xmx512m -cp "
			. join(':', map("/usr/share/java/${_}.jar", @libs))
			. " org.apache.pdfbox.tools.PDFMerger "
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


# Detect if page is white by drawing one pixel border around
# image and calling ImageMagick's auto-crop operator.  Returns
# true if bounding box of cropped image is smaller than geometry
# of original image.
sub is_page_white
{
	my $input_file = shift;
	my $orig_dim = sys("$convert_bin $input_file -format '%g' info:");
	my $crop_dim = sys("$convert_bin $input_file -bordercolor white "
		  . "-border 1x1 -format '%\@' info:");
	$log->debug("Original dimensions: $orig_dim");
	$log->debug("Crop dimensions: $crop_dim");
	$orig_dim =~ s/\+.*//;
	$crop_dim =~ s/\+.*//;
	$orig_dim ne $crop_dim;
}


sub img2pdf
{
	my ($input_file, $output_file, $cfg) = @_;

	my $tmp_pdf_file = "$tmpdir/" . basename($output_file);

	if ($opt_i)
	{
		my $img_dimensions =
		    $cfg->{image}{width} . 'x'
		  . $cfg->{image}{height};

		my $density =
		    $cfg->{image}{resolution} . 'x'
		  . $cfg->{image}{resolution};

		# Now convert downsampled to pdf
		sys(    "$convert_bin $input_file "
			  . "-resize $img_dimensions "
			  . "-background $cfg->{image}{bg_color} "
			  . "-gravity center "
			  . "-extent $img_dimensions "
			  . "-units PixelsPerInch "
			  . "-density $density "
			  . "-compress JPEG "
			  . "-quality $cfg->{image}{jpeg_quality} "
			  . $tmp_pdf_file);
	}
	elsif ($opt_o)
	{
		(my $output_base = $tmp_pdf_file) =~ s/\.pdf$//;
		my $opts = "-l $cfg->{lang} $tess_args";
		sys("tesseract $input_file $output_base $opts pdf");
	}
	elsif ($opt_e)
	{
		sys("hocr2pdf -i $input_file -o $tmp_pdf_file "
			. "< $cfg->{hocr_file}");
	}
	else
	{
		sys(    "tiff2pdf -o $tmp_pdf_file -j -q "
			  . "$cfg->{image}{jpeg_quality} $input_file");
		sys("sed -i 's/ColorTransform 0/ColorTransform 1/' $tmp_pdf_file");
	}
	sys("pdfinfo $tmp_pdf_file");

	$log->info("Moving $tmp_pdf_file to $host:$output_file");
	move($tmp_pdf_file, $output_file)
	  or $log->logdie("can't move $tmp_pdf_file to $output_file: $!");
}


# leptonica ignores TMPDIR environment var so we
# have to make sure /tmp/lept is writable by everyone
sub mk_lept_tmpdir
{
	my $lept_tmpdir = "/tmp/lept";
	if (-d $lept_tmpdir)
	{
		if (-o _)
		{
			$log->debug("Changing permissions of leptonica "
				  . "tmp directory $lept_tmpdir to 0777.");
			chmod(0777, $lept_tmpdir)
			  or $log->logdie("Can't chmod $lept_tmpdir: $!");
		}
		elsif (! -W _)
		{
			$log->logdie(
				"Leptonica tmp directory $lept_tmpdir not writable.");
		}
	}
	else
	{
		my $umask = umask(0000);
		$log->debug("Creating leptonica tmp directory $lept_tmpdir.");
		mkdir($lept_tmpdir, 0777)
		  or $log->logdie("Can't mkdir $lept_tmpdir: $!");
		umask($umask);
	}
}
