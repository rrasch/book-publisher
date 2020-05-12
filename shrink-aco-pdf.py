#!/usr/bin/env python3

import glob
import os
import shutil
import subprocess
import sys
import tempfile


def do_cmd(cmd, **kwargs):
    print("Running command:", " ".join(cmd))
    try:
        process = subprocess.run(cmd, check=True, **kwargs)
    except Exception as e:
        print(e)
        exit(1)

if len(sys.argv) != 3:
    print("Usage: {} INPUT_FILE OUTPUT_FILE".format(sys.argv[0]))
    exit(1)

input_file = sys.argv[1]
output_file = sys.argv[2]
print("Input file:", input_file)
print("Output file:", output_file)

if input_file == output_file:
    print("Input file can't be the same as output file.")
    exit(1)

tmp_rootdir = "/content/prod/rstar/tmp/aco"
if not os.path.isdir(tmp_rootdir):
    tmp_rootdir = "/tmp"

# tmpdir = tempfile.TemporaryDirectory(dir=tmp_rootdir)
# print(tmpdir.name)
tmpdir = tempfile.mkdtemp(dir=tmp_rootdir)
print(tmpdir)

do_cmd(['qpdf', '--split-pages', input_file, '{}/%d.pdf'.format(tmpdir)])

for pdf_file in sorted(glob.glob(f"{tmpdir}/*.pdf")):
    basename = os.path.splitext(pdf_file)[0]
    djvu_file = basename + ".djvu"
    hocr_file = basename + ".hocr"
    old_jpg_file = basename + "-000.jpg"
    new_jpg_file = basename + ".jpg"
    do_cmd(['pdfimages', '-all', pdf_file, basename])
    do_cmd(['convert', old_jpg_file, '-quality', '10', new_jpg_file])
    os.remove(old_jpg_file)
    do_cmd(['pdf2djvu', '-q', '-o', djvu_file, pdf_file])
    with open(hocr_file, 'w') as f:
        do_cmd(['djvu2hocr', djvu_file], stdout=f)

do_cmd(['hocr-pdf', '--savefile', output_file, tmpdir])

shutil.rmtree(tmpdir)

