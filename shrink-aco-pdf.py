#!/usr/bin/env python3
#
# Shrink ACO PDF files generated by QNL.
#
# Requires the following tools:
# ImageMagick, poppler, pdf2djvu, ocrodjvu, and hocr-tools


import argparse
import glob
import logging
import os
import re
import shutil
import subprocess
import sys
import tempfile


def do_cmd(cmdlist, **kwargs):
    cmd = list(map(str, cmdlist))
    logging.debug("Running command: %s", " ".join(cmd))
    try:
        process = subprocess.run(cmd, check=True, **kwargs)
    except Exception as e:
        logging.exception(e)
        exit(1)


logging.basicConfig(
    format='%(asctime)s - shrink-aco-pdf - %(levelname)s - %(message)s',
    datefmt='%m/%d/%Y %I:%M:%S %p')

parser = argparse.ArgumentParser(
    description="Shrink ACO PDFs generated by QNL.")
parser.add_argument("input_file", metavar="INPUT_FILE",
    help="Input PDF file")
parser.add_argument("output_file", metavar="OUTPUT_FILE",
    help="Output PDF file")
parser.add_argument("-d", "---debug",
    help="Enable debugging messages", action="store_true")
parser.add_argument("-m", "--max-pages", type=int,
    help="Maximum number of pages to process")
parser.add_argument("--dpi",  type=int,
    default=72, choices=[72, 96, 200],
    help="Resolution for PDF pages")
args = parser.parse_args()

if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

logging.debug("Input file: %s", args.input_file)
logging.debug("Output file: %s", args.output_file)

if args.input_file == args.output_file:
    print("Input file can't be the same as output file.",
        file=sys.stderr)
    exit(1)

rstar_dir = "/content/prod/rstar"

objid = os.path.splitext(os.path.basename(args.input_file))[0]
match = re.search(r'^([a-z]+)_aco\d{6}$', objid)
if match:
    partner_id = match.group(1)
    aux_dir = f"{rstar_dir}/content/{partner_id}/aco/wip/se/{objid}/aux"
    logging.debug("aux_dir: %s", aux_dir)
    aux_exists = os.path.isdir(aux_dir)

tmp_rootdir = f"{rstar_dir}/tmp/aco"
if not os.path.isdir(tmp_rootdir):
    tmp_rootdir = "/tmp"

# tmpdir = tempfile.TemporaryDirectory(dir=tmp_rootdir)
# logging.debug("temp directory: %s", tmpdir.name)
tmpdir = tempfile.mkdtemp(dir=tmp_rootdir)
logging.debug("temp directory: %s", tmpdir)

# split pdf into individual pdfs for each page
do_cmd(['qpdf', '--split-pages',
    args.input_file, '{}/%d.pdf'.format(tmpdir)])

# Loop over each page until we have an hocr file
# and reduced jpg for each page
for i, pdf_file in enumerate(sorted(glob.glob(f"{tmpdir}/*.pdf"))):

    if args.max_pages > 0 and i == args.max_pages:
        break

    # set up file paths
    basename     = os.path.splitext(pdf_file)[0]
    djvu_file    = basename + ".djvu"
    hocr_file    = basename + ".hocr"
    old_jpg_file = basename + "-000.jpg"
    new_jpg_file = basename + ".jpg"

    # extract jpg image from pdf page
    do_cmd(['pdfimages', '-all', pdf_file, basename])

    # shrink image size by reducing quality
    do_cmd(['convert', '-density', '300', old_jpg_file,
        '-resample', args.dpi, '-density', args.dpi,
        '-units', 'PixelsPerInch', new_jpg_file])

    # delete the larger original image
    os.remove(old_jpg_file)

    # convert pdf page to djvu file
    do_cmd(['pdf2djvu', '-q', '-o', djvu_file, pdf_file])

    # extract hidden text from djvu file as hocr
    with open(hocr_file, 'w') as f:
        do_cmd(['djvu2hocr', djvu_file], stdout=f)

    # generating hocr is time consuming so we copy file
    # to aux directory for later use
    dest_file = aux_dir + "/" + os.path.basename(hocr_file)
    if aux_exists and not os.path.isfile(dest_file):
        shutil.copyfile(hocr_file, dest_file)

# reassemble pdf by combining reduced images
# and extracted hocr files
do_cmd(['hocr-pdf', '--scale-hocr', args.dpi / 300,
    '--savefile', args.output_file, tmpdir])

shutil.rmtree(tmpdir)

