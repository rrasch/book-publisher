#!/usr/bin/python3

import argparse
import logging
import sys
import os
from pathlib import Path
from typing import List

SCRIPT_DIR = Path(__file__).resolve().parent
ACO_SCRIPTS_DIR = (SCRIPT_DIR / ".." / "aco-scripts").resolve()
if str(ACO_SCRIPTS_DIR) not in sys.path:
    sys.path.insert(0, str(ACO_SCRIPTS_DIR))

from util import generate_pdfs


def get_dmaker_images(book_dir: Path) -> List[Path]:
    return sorted(book_dir.glob("*_d.tif"))


def get_hocr_files(aux_dir: Path) -> List[Path]:
    return sorted(aux_dir.glob("*.hocr"))


def main():
    parser = argparse.ArgumentParser(
        description="Generate PDFs from dmaker TIFF and HOCR files."
    )
    parser.add_argument(
        "-r",
        "--rstar-dir",
        required=True,
        type=Path,
        help="Root rstar content directory.",
    )
    parser.add_argument(
        "-t",
        "--tmpdir",
        type=Path,
        default="/content/prod/rstar/tmp",
        help="Temporary directory (default: %(default)s).",
    )
    parser.add_argument(
        "-q",
        "--quiet",
        action="store_true",
        help="Suppress informational output.",
    )
    parser.add_argument(
        "-f",
        "--force",
        "--overwrite",
        dest="overwrite",
        action="store_true",
        help="Force overwrite of existing output files.",
    )
    parser.add_argument(
        "book_ids",
        nargs="*",
        help="Optional book IDs. If omitted, discovers all IDs under wip/se.",
    )
    args = parser.parse_args()

    log_level = logging.WARNING if args.quiet else logging.INFO
    logging.basicConfig(level=log_level, format="%(message)s")

    tmpdir = args.tmpdir.resolve()
    if not tmpdir.exists():
        sys.exit(f"ERROR: tmpdir does not exist: {tmpdir}")
    os.environ["TMPDIR"] = str(tmpdir)
    logging.info(f"Using TMPDIR={tmpdir}")

    rstar_dir: Path = args.rstar_dir
    if not rstar_dir.exists():
        sys.exit(f"ERROR: rstar_dir does not exist: {rstar_dir}")

    if args.book_ids:
        book_ids = args.book_ids
    else:
        se_dir = rstar_dir / "wip" / "se"
        if not se_dir.exists():
            sys.exit(
                f"ERROR: {se_dir} does not exist; cannot "
                "auto-discover book IDs."
            )
        book_ids = sorted(p.name for p in se_dir.iterdir() if p.is_dir())
        if not book_ids:
            sys.exit(f"ERROR: No book IDs found in {se_dir}")
        logging.info(f"Discovered book IDs: {', '.join(book_ids)}")

    for book_id in book_ids:
        book_dir = rstar_dir / "wip" / "se" / book_id
        aux_dir = book_dir / "aux"

        if not book_dir.exists():
            logging.error(f"{book_id}: book_dir does not exist: {book_dir}")
            sys.exit(1)

        if not aux_dir.exists():
            logging.error(f"{book_id}: aux_dir does not exist: {aux_dir}")
            sys.exit(1)

        dmaker_imgs = get_dmaker_images(aux_dir)
        hocr_files = get_hocr_files(aux_dir)

        logging.info(f"\nBook ID: {book_id}")
        logging.info(f"Book directory: {book_dir}")

        logging.info(f"  Dmaker images ({len(dmaker_imgs)}):")
        for img in dmaker_imgs:
            logging.info(f"    {img.name}")

        logging.info(f"  HOCR files ({len(hocr_files)}):")
        for hocr in hocr_files:
            logging.info(f"    {hocr.name}")

        logging.info("-" * 60)

        if len(dmaker_imgs) != len(hocr_files):
            logging.error(
                f"{book_id}: Page mismatch — {len(dmaker_imgs)} TIFF(s) vs"
                f" {len(hocr_files)} HOCR file(s). Aborting."
            )
            sys.exit(1)

        generate_pdfs(
            book_id,
            dmaker_imgs,
            hocr_files,
            max_workers=1,
            overwrite=args.overwrite,
        )


if __name__ == "__main__":
    main()
