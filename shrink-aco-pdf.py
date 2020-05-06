#!/usr/bin/python3

import glob
import os
import subprocess
import sys
import tempfile
import time

input_file = sys.argv[1]
print(input_file)

# tmpdir = tempfile.TemporaryDirectory()
tmpdir = tempfile.mkdtemp()
#print(tmpdir.name)
print(tmpdir)

# time.sleep(30)


process = subprocess.run(['qpdf',
    '--split-pages', input_file, '{}/%d.pdf'.format(tmpdir)])

print(process)

for pdf_file in sorted(glob.glob(f"{tmpdir}/*.pdf")):
    basename = os.path.splitext(pdf_file)[0]
    djvu_file = basename + ".djvu"
    hocr_file = basename + ".hocr"
    old_jpg_file = basename + "-000.jpg"
    new_jpg_file = basename + ".jpg"
    process = subprocess.run(['pdfimages', '-all', pdf_file, basename])
    process = subprocess.run(['convert', old_jpg_file,
        '-quality', '10', new_jpg_file])
    os.remove(old_jpg_file)
    process = subprocess.run(['pdf2djvu', '-o', djvu_file, pdf_file])
    with open(hocr_file, 'w') as f:
        process = subprocess.run(['djvu2hocr', djvu_file],
            stdout=f)

#tmpdir.cleanup()


