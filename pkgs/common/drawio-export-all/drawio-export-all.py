#!/usr/bin/env python

import os
import subprocess
import sys
import pathlib
import xml.etree.ElementTree as ET


def get_diagram_names(xmlfile):
    """Return a list of all of the diagram names"""
    # create element tree object
    tree = ET.parse(xmlfile)

    # get root element
    root = tree.getroot()

    # create empty list for diagrams
    diagrams = []

    # iterate diagrams items
    for item in root.findall("./diagram"):
        diagrams.append(item.attrib["name"])
    return diagrams


def usage():
    print("Usage: drawio-export-all.py <diagram> [output_folder]")
    sys.exit(1)


def main():
    if len(sys.argv) < 2:
        print("ERROR: Please supply diagram argument.")
        usage()

    try:
        subprocess.run(["which", "drawio"], stdout=subprocess.DEVNULL, check=True)
    except subprocess.CalledProcessError:
        print("ERROR: drawio is not installed.")
        sys.exit(1)

    diagram_file = pathlib.Path(sys.argv[1])
    if not diagram_file.exists():
        print("ERROR: Please supply of valid diagram file.")
        usage()
    subprocess.Popen(
        [
            f"drawio --export --format xml --uncompressed {diagram_file}  2>&1 | grep -v ERROR:g"
        ],
        shell=True,
        # stdout=subprocess.DEVNULL,
        # stderr=subprocess.DEVNULL,
    )
    if not os.path.exists(f"{diagram_file.stem}.xml"):
        print("ERROR: Failed to export diagram to xml.")
        sys.exit(1)
    diagrams = get_diagram_names(f"{diagram_file.stem}.xml")

    output_folder = "." if len(sys.argv) < 3 else sys.argv[2]
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    index = 0
    print(f"Exporting {len(diagrams)} diagrams...")
    for name in diagrams:
        output_name = f"{output_folder}/{diagram_file.stem}-{name}.drawio.png"
        export_cmd = "drawio --export"
        export_cmd += " --transparent"
        export_cmd += f" --page-index {index}"
        export_cmd += f" --output {output_name}"
        export_cmd += f" {diagram_file}"
        # NOTE: below is because of some gl bug in chromium on linux that spams
        export_cmd += " 2>&1 | grep -v ERROR:g"
        subprocess.Popen(
            [export_cmd],
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # os.system(export_cmd)
        print(f"{index+1}/{len(diagrams)}: {output_name}")

        index = index + 1


if __name__ == "__main__":
    main()
