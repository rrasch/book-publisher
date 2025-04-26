#!/usr/bin/python3

from pprint import pformat
import argparse
import logging
import os


def validate_dirpath(dirpath: str) -> str:
    """Validates a dirpath and returns it if valid."""
    if not os.path.isdir(dirpath):
        raise argparse.ArgumentTypeError(f"Directory not found: '{dirpath}'")
    return os.path.realpath(dirpath)


def scandir(dirpath):
    """Return directory entries sorted by name."""
    return sorted(os.scandir(dirpath), key=lambda e: e.name)


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
        help="rstar directory",
    )
    parser.add_argument(
        "-e", "--exclude", help="exclude files matching extension"
    )
    parser.add_argument(
        "-d", "--debug", help="Enable debugging messages", action="store_true"
    )
    args = parser.parse_args()

    level = logging.DEBUG if args.debug else logging.WARNING
    logging.basicConfig(format="%(levelname)s: %(message)s", level=level)

    wip_dir = os.path.join(args.rstar_dir, "wip", "se")
    logging.debug("wip_dir=%s", wip_dir)

    if args.id:
        id_list = args.id
    else:
        id_list = [entry.name for entry in scandir(wip_dir)]
    logging.debug("ids=%s", pformat(id_list))

    for obj_id in id_list:
        aux_dir = os.path.join(wip_dir, obj_id, "aux")
        logging.debug("aux_dir=%s", aux_dir)

        for entry in scandir(aux_dir):
            if not (args.exclude and entry.name.endswith(args.exclude)):
                logging.debug("Deleting %s", entry.path)
                os.remove(entry.path)


if __name__ == "__main__":
    main()
