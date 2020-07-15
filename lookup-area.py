#!/usr/bin/env python3

import argparse
import countryinfo
import json
import os
import sys

# geojson data file for world cities
city_file = 'ne_50m_populated_places.geojson'

# number of sq kilometers per square mile
RATIO_KM2_TO_MILE2 = 1.609344 ** 2

def convert_km2_to_mile2(km2):
    return float(km2) / RATIO_KM2_TO_MILE2

parser = argparse.ArgumentParser(description="Get country info")
parser.add_argument("country")
args = parser.parse_args()

cinfo = countryinfo.CountryInfo(args.country)
try:
    print(convert_km2_to_mile2(cinfo.area()))
    exit(0)
except KeyError:
    pass

app_home = os.path.dirname(os.path.abspath(sys.argv[0]))
city_file = os.path.join(app_home, city_file)

area = {}
with open(city_file) as f:
    city_data = json.load(f)
for feature in city_data['features']:
    prop = feature['properties']
    area[prop['NAME']] = prop['MAX_AREAKM']
try:
    print(area[args.country])
except KeyError:
    exit(1)

