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


parser = argparse.ArgumentParser(
    description="Get geographic coordinates from MODS subject")
parser.add_argument("mods_file", metavar="MODS_FILE",
    help="Input MODS file")
parser.add_argument("coord_file", metavar="COORD_FILE",
    help="Ouptput JSON coordinates file")
parser.add_argument("-d", "--debug",
    help="Enable debugging messages", action="store_true")
parser.add_argument("-g", "--geocoder", default="nominatim",
    help="Geocoder module for map requests")
args = parser.parse_args()

if args.debug:
    logging.getLogger().setLevel(logging.DEBUG)


nsmap = {"m": "http://www.loc.gov/mods/v3"}
xpath = "//m:subject[@authority='lcsh']/m:geographic"

mods = etree.parse(args.mods_file)
geo_subj = mods.xpath(xpath, namespaces=nsmap)
if geo_subj:
    loc_name = geo_subj[0].text
else:
    print("No geographic subject found.", file=sys.stderr)
    exit()

logging.debug("Location: %s", loc_name)

geocoder_class = get_geocoder_for_service(args.geocoder)
logging.debug("geocoder class: %s", geocoder_class)

ua_name = "dlts_geo_app/0.1"
geolocator = geocoder_class(user_agent=ua_name)
location = geolocator.geocode(loc_name)

coord = {
    "location":  loc_name,
    "latitude":  location.latitude,
    "longitude": location.longitude
}

logging.debug("Coordinates %s", coord)

with open(args.coord_file, "w") as outfile:
    json.dump(coord, outfile, indent=None)

