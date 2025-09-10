#!/usr/bin/env python
import os
import sys
import pathlib
import shutil
import shlex
from multiprocessing import Process
import xml.etree.ElementTree as ET

def export(cmd, file, name, index, total):
    """Export the specified tab from the file"""
    print(f"Trying {index}/{total}: {name}")
    export_cmd = f"{cmd} --export"
    export_cmd += " --transparent"
    export_cmd += f" --page-index {index}"
    output_name = shlex.quote(f'{file.stem}-{name}.drawio.png')
    export_cmd += f" --output {output_name}"
    export_cmd += f" {file}"
    # FIXME: Switch with subprocess
    os.system(export_cmd)

def get_diagram_names(xmlfile):
    """Return a list of all of the diagram names"""
    diagrams = []

    tree = ET.parse(xmlfile)
    root = tree.getroot()

    for item in root.findall("./diagram"):
        diagrams.append(item.attrib["name"])

    return diagrams

def find_drawio_binary():
    """Tests which drawio binary is accessible"""

    binary_names = [ "draw.io", "drawio" ]
    for name in binary_names:
        if shutil.which(name):
            return name
    return None

def remove_alpha(file):
    """Replace the transparent background with white"""
    os.system("magick convert {file} -background white -alpha remove -alpha off {file}.white")
    # FIXME: Rename file to use the white version

def die(msg):
    """Print error and exit with error"""
    print(f"ERROR: {msg}")
    sys.exit(1)

# FIXME: Add proper cmd line handling and add option to force white background with remove_alpha
def main():

    # Avoid https://github.com/NixOS/nixpkgs/issues/250986
    os.environ.pop("WAYLAND_DISPLAY")

    if len(sys.argv) < 2:
        die("Please supply diagram argument")

    diagram_file = pathlib.Path(sys.argv[1])
    if not diagram_file.exists():
        die("Please supply of valid diagram argument.")

    drawio = find_drawio_binary()
    if not drawio:
        die("Can't find drawio binary. Make sure it's installed")

    print("Exporting drawio file as xml")
    os.system(
        f"{drawio} --export --format xml --uncompressed {diagram_file}"
    )
    xml = f"{diagram_file.stem}.xml"
    if not pathlib.Path(xml).exists():
        die(f"Failed to generate {xml}")
    diagrams = get_diagram_names(xml)
    # FIXME: Add option to keep files
    pathlib.Path(xml).unlink()
    if not len(diagrams):
        die("No diagrams found in file")
    print(f"Found {len(diagrams)} diagrams")

    processes = []
    index = 0
    for name in diagrams:
        processes.append(Process(target=export, args=(drawio, diagram_file, name, index, len(diagrams))))
        index = index + 1

    for process in processes:
        process.start()

    for process in processes:
        process.join()

if __name__ == "__main__":
    main()
