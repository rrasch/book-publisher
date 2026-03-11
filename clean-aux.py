#!/usr/bin/python3

import argparse
import logging
import os
import time
from pprint import pformat
from typing import Optional


def validate_dirpath(dirpath: str) -> str:
    """Validates a dirpath and returns it if valid."""
    if not os.path.isdir(dirpath):
        raise argparse.ArgumentTypeError(f"Directory not found: '{dirpath}'")
    return os.path.realpath(dirpath)


def scan_dir(dirpath):
    """Return directory entries sorted by name."""
    return sorted(os.scandir(dirpath), key=lambda e: e.name)


def positive_float(value):
    try:
        f = float(value)
    except ValueError:
        raise argparse.ArgumentTypeError(f"{value!r} is not a valid number")
    if f <= 0:
        raise argparse.ArgumentTypeError(
            "age must be a positive number of days"
        )
    return f


def purge(
    aux_dir: str, *, cutoff_time: float, exclude: Optional[str], dry_run: bool
) -> None:
    """
    Purge files from a directory using modification time and optional
    exclusions.

    This function iterates over entries in `aux_dir` (non-recursively) and
    deletes files whose modification time is newer than `cutoff_time`,
    unless excluded. Symlinks and non-directory paths are skipped. Deletion
    can be simulated with `dry_run`.

    Args:
        aux_dir (str): Path to the directory to purge.
        cutoff_time (float): Epoch timestamp; files with mtime >= cutoff_time
            will be considered for deletion.
        exclude (Optional[str]): If provided, files whose names end with this
            string are skipped.
        dry_run (bool): If True, only log files that would be deleted.

    Returns:
        None

    Logs:
        - Warnings if `aux_dir` is not a real directory (symlinks ignored)
        - Debug messages for excluded files, dry-run actions, and deletions.
    """
    if not os.path.isdir(aux_dir) or os.path.islink(aux_dir):
        logging.warning(
            "Skipping %s: not a real directory (symlinks are ignored)",
            aux_dir,
        )
        return

    for entry in scan_dir(aux_dir):
        if exclude and entry.name.endswith(exclude):
            logging.debug("Excluding %s", entry.path)
            continue

        mtime = entry.stat().st_mtime

        if mtime < cutoff_time:
            last_modified = time.strftime(
                "%Y-%m-%d %H:%M:%S", time.localtime(mtime)
            )
            logging.debug(
                "Excluding %s, last modified: %s", entry.path, last_modified
            )
            continue

        if dry_run:
            logging.debug("Would delete %s", entry.path)
        else:
            logging.debug("Deleting %s", entry.path)
            os.remove(entry.path)


def main():
    parser = argparse.ArgumentParser(
        description="Purge files from aux directory"
    )
    parser.add_argument("id", nargs="*", help="object id")
    parser.add_argument(
        "-r",
        "--rstar-dir",
        type=validate_dirpath,
        required=True,
        help="rstar collection directory",
    )
    parser.add_argument(
        "-a",
        "--age",
        type=positive_float,
        metavar="DAYS",
        default=1,
        help=(
            "Delete files newer than DAYS days "
            "(may be fractional; default: %(default)s)"
        ),
    )
    parser.add_argument(
        "-e", "--exclude", help="exclude files matching extension"
    )

    group = parser.add_mutually_exclusive_group()
    group.add_argument(
        "-q", "--quiet", action="store_true", help="Suppress debugging messages"
    )
    group.add_argument(
        "-n",
        "--dry-run",
        action="store_true",
        help="Show what would be deleted without removing any files",
    )

    # Compatibility option: other scripts in the pipeline use this flag.
    # It is accepted here to allow a common argument set in the task queue,
    # but this script does not use the value.
    parser.add_argument(
        "-f",
        "--force",
        "--overwrite",
        action="store_true",
        default=argparse.SUPPRESS,
        help=argparse.SUPPRESS,
    )

    args = parser.parse_args()

    script_name = os.path.basename(os.path.realpath(__file__))
    level = logging.WARNING if args.quiet else logging.DEBUG
    logging.basicConfig(
        level=level,
        format=f"[{script_name}] %(levelname)s: %(message)s",
    )

    se_dir = os.path.join(args.rstar_dir, "wip", "se")
    logging.debug("se_dir=%s", se_dir)

    if args.id:
        id_list = args.id
    else:
        id_list = [entry.name for entry in scan_dir(se_dir)]
    logging.debug("ids=%s", pformat(id_list))

    now = time.time()
    # Define the age threshold (in seconds)
    one_day_in_secs = 24 * 60 * 60
    cutoff_time = now - args.age * one_day_in_secs

    for obj_id in id_list:
        aux_dir = os.path.join(se_dir, obj_id, "aux")
        logging.debug("aux_dir=%s", aux_dir)
        purge(
            aux_dir,
            cutoff_time=cutoff_time,
            exclude=args.exclude,
            dry_run=args.dry_run,
        )


if __name__ == "__main__":
    main()
