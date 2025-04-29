#!/usr/bin/python3

from glob import glob
from pprint import pformat
import argparse
import logging
import os
import shutil
import subprocess
import sys
import tempfile


PAPER_SIZE = (8.5, 11)

RESOLUTION = {"hi": 300, "lo": 150}


def find_imagemagick_binary():
    # Check for the new `magick` binary used in ImageMagick 7+
    magick_path = shutil.which("magick")
    if magick_path:
        return "magick"

    # Check for the older `convert` binary used in ImageMagick < 7
    convert_path = shutil.which("convert")
    if convert_path:
        return "convert"

    return None


def validate_dirpath(dirpath: str) -> str:
    """Validates a dirpath and returns it if valid."""
    if not os.path.isdir(dirpath):
        raise argparse.ArgumentTypeError(f"Directory not found: '{dirpath}'")
    return os.path.realpath(dirpath)


def validate_filepath(filepath):
    if not os.path.exists(filepath):
        raise argparse.ArgumentTypeError(f"File '{filepath}' does not exist.")
    return os.path.realpath(filepath)


def scandir(dirpath):
    """Return directory entries sorted by name."""
    return sorted(os.scandir(dirpath), key=lambda e: e.name)


def do_cmd(cmdlist, **kwargs):
    cmd = list(map(str, cmdlist))
    logging.debug("Running command: %s", " ".join(cmd))
    try:
        process = subprocess.run(cmd, check=True, **kwargs)
    except Exception as e:
        logging.exception(e)
        sys.exit(1)
    return process


def main():
    parser = argparse.ArgumentParser(description="OCR pdf file")
    parser.add_argument(
        "input_file", type=validate_filepath, help="input pdf file"
    )
    parser.add_argument("output_base", help="Basename for output pdf files")
    parser.add_argument(
        "-d", "--debug", help="Enable debugging messages", action="store_true"
    )
    args = parser.parse_args()

    level = logging.DEBUG if args.debug else logging.WARNING
    logging.basicConfig(format="%(levelname)s: %(message)s", level=level)

    tess_args = ["-c", "tessedit_do_invert=0"]
    if not args.debug:
        tess_args.append("quiet")

    convert = find_imagemagick_binary()
    if not convert:
        sys.exit("No ImageMagick binary found.")

    dimensions = {}
    for name, dpi in RESOLUTION.items():
        dimensions[name] = "x".join(
            tuple(str(int(dim_in_inches * dpi)) for dim_in_inches in PAPER_SIZE)
        )

    with tempfile.TemporaryDirectory() as tmpdir:
        output_base = os.path.join(tmpdir, "out")
        do_cmd(["pdfimages", "-j", args.input_file, output_base])
        page_entries = scandir(tmpdir)
        for name, dpi in RESOLUTION.items():
            for i, entry in enumerate(page_entries, start=1):
                do_cmd(["identify", entry.path])
                resized_img = os.path.join(tmpdir, f"{i:03d}_{name}.jpg")
                do_cmd([
                    convert,
                    entry.path,
                    "-resize",
                    dimensions[name],
                    "-background",
                    "white",
                    "-gravity",
                    "center",
                    "-extent",
                    dimensions[name],
                    "-units",
                    "PixelsPerInch",
                    "-density",
                    str(dpi),
                    resized_img,
                ])
                do_cmd(["identify", resized_img])

                pdf_base = os.path.join(tmpdir, f"{i:03d}_{name}")
                do_cmd([
                    "tesseract",
                    resized_img,
                    pdf_base,
                    *tess_args,
                    "pdf",
                ])

            pdf_files = sorted(glob(os.path.join(tmpdir, "*.pdf")))
            tmp_file = os.path.join(tmpdir, f"tmp_{name}.pdf")
            do_cmd(["pdftk", *pdf_files, "cat", "output", tmp_file])

            out_file = f"{args.output_base}_{name}.pdf"
            shutil.move(tmp_file, out_file)


if __name__ == "__main__":
    main()
