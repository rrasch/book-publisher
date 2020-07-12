#!/usr/bin/env python3
#
# Merge KML files
#
# Modifed version of this stackoverflow answer:
# https://stackoverflow.com/a/11315257/13631441

from xml.etree import ElementTree as ET
import sys

if len(sys.argv) < 3:
    print(f"Usage: {sys.argv[0]} KML_FILE KML_FILE [KML_FILE]...",
        file=sys.stderr)
    exit(1)

nsmap = {"k": "http://www.opengis.net/kml/2.2"}

ET.register_namespace('', nsmap["k"])

first = {}

for filename in sys.argv[1:]:
    kml = ET.parse(filename).getroot()
    if not first:
        first['root'] = kml
        first['doc_node'] = kml.find("./k:Document", nsmap)
    else:
        placemarks = kml.findall("./k:Document/k:Placemark", nsmap)
        first['doc_node'].extend(placemarks)

print(ET.tostring(first['root'], encoding="unicode"))

