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


parser = argparse.ArgumentParser(
    description="Get geographic coordinates from MODS subject")
parser.add_argument("mods_file", metavar="MODS_FILE",
    help="Input MODS file")
parser.add_argument("coord_file", metavar="COORD_FILE", nargs="?",
    help="Ouptput JSON coordinates file")
parser.add_argument("-d", "--debug",
    help="Enable debugging messages", action="store_true")
parser.add_argument("-g", "--geocoder", default="nominatim",
    help="Geocoder module for map requests")
args = parser.parse_args()

if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)

geocoder_args = { "user_agent": "dlts_geo_app/0.1" }

api_key = os.environ.get('MAPS_API_KEY')

if args.geocoder == "google":
    if api_key:
        geocoder_args['api_key'] = api_key
    else:
        print("Must set envar MAPS_API_KEY for %s" % args.geocoder,
            file=sys.stderr)
        exit(1)

nsmap = {"m": "http://www.loc.gov/mods/v3"}
xpath = "//m:subject[@authority='lcsh']/m:geographic"

mods = etree.parse(args.mods_file)
geo_subj = mods.xpath(xpath, namespaces=nsmap)
if geo_subj:
    loc_name = geo_subj[0].text
else:
    print("No geographic subject found in MODS.",
        file=sys.stderr)
    exit(1)

logging.debug("Location: %s", loc_name)

geocoder_class = get_geocoder_for_service(args.geocoder)
logging.debug("geocoder class: %s", geocoder_class)

ua_name = "dlts_geo_app/0.1"
geolocator = geocoder_class(**geocoder_args)
location = geolocator.geocode(loc_name)

if not location:
    print((f"Couldn't find coordinates for {loc_name} "
           f"using {args.geocoder.capitalize()} Maps API"),
        file=sys.stderr)
    exit(1)

coord = {
    "location":  loc_name,
    "latitude":  location.latitude,
    "longitude": location.longitude
}

logging.debug("Coordinates %s", coord)

if not args.coord_file or args.coord_file == "-":
    print(json.dumps(coord, indent=2))
else:
    with open(args.coord_file, "w") as outfile:
        json.dump(coord, outfile, indent=2)

