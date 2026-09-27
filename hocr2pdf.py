#!/usr/bin/python3

import argparse
import logging
import os
import sys
from pathlib import Path
from typing import List

PACKAGE_DIRS = ["aco-scripts", "task-queue"]

SCRIPT_DIR = Path(__file__).resolve().parent

for package_dir in PACKAGE_DIRS:
    path = str((SCRIPT_DIR / ".." / package_dir).resolve())
    if path not in sys.path:
        sys.path.insert(0, path)

from pdf_utils import generate_pdfs
from tqcommon import get_tmpdir

logger = logging.getLogger(__name__)


def get_dmaker_images(img_dir: Path) -> List[Path]:
    return sorted(img_dir.glob("*_d.tif"))


def get_hocr_files(hocr_dir: Path) -> List[Path]:
    return sorted(hocr_dir.glob("*.hocr"))


def set_tmpdir(args):
    tmpdir = args.tmpdir or os.environ.get("TMPDIR") or get_tmpdir()
    tmpdir = Path(tmpdir).resolve()

    if not tmpdir.exists():
        logger.error(
            "Path '%s' is not a directory and "
            "can't be used as a temporary directory.",
            tmpdir,
        )

    logger.info("Setting environment variable TMPDIR=%s", tmpdir)
    os.environ["TMPDIR"] = str(tmpdir)


def main():
    parser = argparse.ArgumentParser(
        description="Generate PDFs from dmaker TIFF and HOCR files."
    )
    parser.add_argument(
        "book_ids",
        nargs="*",
        help="Optional book IDs. If omitted, discovers all IDs under wip/se.",
    )
    parser.add_argument(
        "-r",
        "--rstar-dir",
        required=True,
        type=Path,
        help=(
            "RStar content directory for collection, "
            "e.g. /content/prod/rstar/content/aub/aco"
        ),
    )
    parser.add_argument(
        "-m",
        "--max-workers",
        type=int,
        default=1,
        help=(
            "Maximum number of image processing workers. "
            "If 0, use num CPUs - 1: (default: %(default)s)"
        ),
    )
    parser.add_argument(
        "-t",
        "--tmpdir",
        type=Path,
        help="Temporary directory.",
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
    args = parser.parse_args()

    log_level = logging.WARNING if args.quiet else logging.INFO
    logging.basicConfig(level=log_level, format="%(message)s")

    set_tmpdir(args)

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
        logger.info(f"Discovered book IDs: {', '.join(book_ids)}")

    for book_id in book_ids:
        book_dir = rstar_dir / "wip" / "se" / book_id
        data_dir = book_dir / "data"
        aux_dir = book_dir / "aux"

        for path in (book_dir, data_dir, aux_dir):
            if not path.exists():
                logger.error(f"{book_id}: Directory {book_dir} does not exist")
                sys.exit(1)

            if not path.is_dir():
                logger.error(f"{book_id}: {book_dir} is not a directory")
                sys.exit(1)

        dmaker_imgs = get_dmaker_images(aux_dir)
        hocr_files = get_hocr_files(data_dir)

        if not hocr_files:
            logger.warning(
                f"{book_id}: No hOCR files found in {data_dir}, "
                f"looking in {aux_dir}."
            )
            hocr_files = get_hocr_files(aux_dir)

        logger.info(f"\nBook ID: {book_id}")
        logger.info(f"Book directory: {book_dir}")

        logger.info(f"  Dmaker images ({len(dmaker_imgs)}):")
        for img in dmaker_imgs:
            logger.info(f"    {img.name}")

        logger.info(f"  HOCR files ({len(hocr_files)}):")
        for hocr in hocr_files:
            logger.info(f"    {hocr.name}")

        logger.info("-" * 60)

        if len(dmaker_imgs) != len(hocr_files):
            logger.error(
                f"{book_id}: Page mismatch — {len(dmaker_imgs)} TIFF(s) vs"
                f" {len(hocr_files)} HOCR file(s). Aborting."
            )
            sys.exit(1)

        if not dmaker_imgs:
            logger.error(
                f"There are no images or hOCR files for {book_id}. Aborting."
            )
            sys.exit(1)

        output_base = aux_dir / book_id

        generate_pdfs(
            dmaker_imgs,
            hocr_files,
            output_base,
            max_workers=args.max_workers,
            overwrite=args.overwrite,
        )


if __name__ == "__main__":
    main()
