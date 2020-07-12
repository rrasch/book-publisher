#!/usr/bin/env python3

import argparse
import countryinfo

# number of sq kilometers per square miles
conv_ratio = 1.609344 ** 2

def convert_sqmiles(sq_km):
    return float(sq_km) / conv_ratio

parser = argparse.ArgumentParser(description="Get country info")
parser.add_argument("country")
args = parser.parse_args()

cinfo = countryinfo.CountryInfo(args.country)
try:
    print(round(convert_sqmiles(cinfo.area())))
except KeyError:
    exit(1)

