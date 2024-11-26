#!/usr/bin/env python3

import argparse
import countryinfo
import json
import os
import sys

# directory for natural earth map files
DATA_DIR = "/usr/share/natural-earth-map-data"

# geojson data file for world cities
CITY_FILE = "ne_50m_populated_places.geojson"

# number of sq kilometers per square mile
RATIO_KM2_TO_MILE2 = 1.609344**2


def convert_km2_to_mile2(km2):
    return float(km2) / RATIO_KM2_TO_MILE2


def country_area(location):
    cinfo = countryinfo.CountryInfo(location)
    try:
        return cinfo.area()
    except KeyError:
        return None


def city_area(location):
    app_home = os.path.dirname(os.path.abspath(sys.argv[0]))
    city_file = os.path.join(DATA_DIR, CITY_FILE)
    area = {}
    with open(city_file) as f:
        city_data = json.load(f)
    for feature in city_data["features"]:
        prop = feature["properties"]
        area[prop["NAME"]] = prop["MAX_AREAKM"]
    return area.get(location)


def main():
    parser = argparse.ArgumentParser(description="Lookup area")
    parser.add_argument("location")
    parser.add_argument("-m", "--miles2", action="store_true")
    args = parser.parse_args()

    area = country_area(args.location) or city_area(args.location)

    if area:
        if args.miles2:
            area = convert_km2_to_mile2(area)
        print(area)
    else:
        exit(1)


if __name__ == "__main__":
    main()
