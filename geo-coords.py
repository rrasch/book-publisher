#!/usr/bin/env python3
#
# Lookup map coordinates from geographic tag in MODS xml file.
#
# Here's an example snippet:
#
#   <subject authority="lcsh">
#     <geographic>Egypt</geographic>
#     <topic>History</topic>
#     <temporal>To 640 A.D</temporal>
#     <genre>Chronology</genre>
#   </subject>
#
# The script would search the location "Egypt" using the selected
# map API and return latitude and longitude values. In this example:
#
# {"location": "Egypt", "latitude": 26.2540493, "longitude": 29.2675469}
#
# Author: Rasan

from geopy.geocoders import get_geocoder_for_service
from lxml import etree
import argparse
import importlib
import json
import logging
import os
import sys
import yaml


def lookup_coord(loc_name, geocoder):
    geocoder_class = get_geocoder_for_service(geocoder)
    logging.debug("geocoder class: %s", geocoder_class)
    ua_name = "dlts_geo_app/0.1"
    geolocator = geocoder_class(**geocoder_args)
    location = geolocator.geocode(loc_name)
    if not location:
        print(
            f"Couldn't find coordinates for {loc_name} "
            f"using {args.geocoder.capitalize()} Maps API",
            file=sys.stderr,
        )
        exit(1)
    return [location.latitude, location.longitude]


def main():
    parser = argparse.ArgumentParser(
        description="Get geographic coordinates from MODS subject"
    )
    parser.add_argument(
        "mods_file", metavar="MODS_FILE", help="Input MODS file"
    )
    parser.add_argument(
        "coord_file",
        metavar="COORD_FILE",
        nargs="?",
        help="Ouptput JSON coordinates file",
    )
    parser.add_argument(
        "-d", "--debug", help="Enable debugging messages", action="store_true"
    )
    parser.add_argument(
        "-g",
        "--geocoder",
        default="nominatim",
        help="Geocoder module for map requests",
    )
    args = parser.parse_args()

    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)

    # Script directory
    app_home = os.path.dirname(os.path.abspath(sys.argv[0]))

    #  File mapping location to an alternate name or
    #  pair of coordinates. Sometimes the geocoding service
    #  can't find ancient cities so we need to provide the
    #  present day name for that location.  If that isn't
    #  available, provide coordinates.
    locmap_file = os.path.join(app_home, "locmap.yaml")

    # User agent str for calls to web service
    geocoder_args = {"user_agent": "dlts_geo_app/0.1"}

    # Make sure api key is set if service requires it
    api_key = os.environ.get("MAPS_API_KEY")
    if args.geocoder in ["google"]:
        if api_key:
            geocoder_args["api_key"] = api_key
        else:
            print(
                "Must set envar MAPS_API_KEY for %s" % args.geocoder,
                file=sys.stderr,
            )
            exit(1)

    nsmap = {"m": "http://www.loc.gov/mods/v3"}
    xpath = "//m:subject[@authority='lcsh']/m:geographic"

    # Get geographic subject from MODS
    mods = etree.parse(args.mods_file)
    geo_subj = mods.xpath(xpath, namespaces=nsmap)
    if geo_subj:
        loc_name = geo_subj[0].text
    else:
        print("No geographic subject found in MODS.", file=sys.stderr)
        exit(1)

    logging.debug("Location: %s", loc_name)

    with open(locmap_file) as f:
        locmap = yaml.full_load(f) or {}

    # list of sources (location map or geocoder service)
    # use to lookup coordinates
    sources = []

    # Get coordinates from location map or by
    # querying geocoder service
    if loc_name in locmap:
        val = locmap[loc_name]
        logging.debug("locmap[%s]: %s", loc_name, val)
        sources.append(locmap_file)
        if isinstance(val, list):
            lat, lng = val
        else:
            lat, lng = lookup_coord(val, args.geocoder)
            sources.append(args.geocoder)
    else:
        lat, lng = lookup_coord(loc_name, args.geocoder)
        sources.append(args.geocoder)

    coord = {
        "location": loc_name,
        "latitude": lat,
        "longitude": lng,
        "sources": sources,
    }

    logging.debug("Coordinates %s", coord)

    # Print coordinates to stdout or a file
    if not args.coord_file or args.coord_file == "-":
        print(json.dumps(coord, indent=2, ensure_ascii=False))
    else:
        with open(args.coord_file, "w", encoding="utf-8") as outfile:
            json.dump(coord, outfile, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
